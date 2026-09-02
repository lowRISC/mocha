#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""CI job runner: what each CI job does, so a job and a local run of it are the
same command in the same shell.

    nix run .#ci -- <job>...             run these jobs, in order
    nix run .#ci -- all                  every job that needs no FPGA board
    nix run .#ci -- --step <cmd> [args]  run a single step
    nix run .#ci -- --list               list the jobs and their steps
    nix run .#ci -- --dry-run <job>...   print the steps, run nothing
    nix run .#ci -- --verbose ...        with --dry-run, ask each of our steps
                                         what it would run; otherwise echo the
                                         commands as they run

From inside `nix develop` the same thing spelled ci/run.py <job>.

The jobs themselves are described in ci/jobs.toml, which is the only place
that says what a job does; this runs what it describes.

A step is a command: a tool the devshell provides, one of the repository's
util/ scripts, or -- where a step needs arguments worked out, or is more than
one command -- a script in ci/scripts, named there as `run = "sw-build"`.
Steps run from the repository root and each is runnable on its own.

A step the rest of its job depends on, a configure or a build, is written
`required = true`: if it fails the run stops there. Any other step records its
failure and the job carries on, so one run reports every problem it can find.

A job can also name another job, `{ job = "name" }`, to run its steps at that
point: the sequences are written once and composed rather than restated. A
step reached twice over runs once, the first time it is reached.

Parallelism comes from $MOCHA_JOBS (default: every core), so
`MOCHA_JOBS=8 nix run .#ci -- verilator-test` leaves a machine usable.
"""

import argparse
import os
import shlex
import shutil
import subprocess
import sys
import tomllib
from typing import NamedTuple, Union

import lib


class Step(NamedTuple):
    """A command to run, and whether the rest of its job depends on it."""

    argv: tuple
    required: bool = False


class Job(NamedTuple):
    """Another job's steps, run at this point in the list."""

    name: str


# ---------------------------------------------------------------------------
# The jobs. One per CI job, named after it; the workflows call these by name.
# They are described in ci/jobs.toml, which is the only place that says what a
# job does.
# ---------------------------------------------------------------------------

# Named relative to the repository root, which is where the steps run and how
# every message about the file reads.
JOBS_FILE_NAME = "ci/jobs.toml"
JOBS_FILE = lib.REPO_TOP / JOBS_FILE_NAME


def resolve(token: str) -> str:
    """The command a step name refers to: a bare name is a script in
    ci/scripts, so `sw-build` in ci/jobs.toml, and `--step sw-build` on the
    command line, both mean ci/scripts/sw_build.py.
    """
    candidate = lib.REPO_TOP / f"ci/scripts/{token.replace('-', '_')}.py"
    return str(candidate.relative_to(lib.REPO_TOP)) if candidate.is_file() else token


def read_step(job: str, index: int, entry) -> "Union[Step, Job]":
    """One entry of a job's `steps`, as it is written in ci/jobs.toml.

    Complaining here rather than at the point of use means a typo in the file
    is reported as a typo, before any of the run has happened.
    """
    where = f"{JOBS_FILE_NAME}: jobs.{job}.steps[{index}]"
    if not isinstance(entry, dict):
        raise SystemExit(f"{where}: expected a table, not {type(entry).__name__}.")

    unknown = set(entry) - {"run", "job", "required"}
    if unknown:
        raise SystemExit(f"{where}: unknown key(s): {', '.join(sorted(unknown))}.")
    if ("run" in entry) == ("job" in entry):
        raise SystemExit(f"{where}: needs exactly one of 'run' or 'job'.")

    if "job" in entry:
        if "required" in entry:
            # A job reference has no status of its own; its steps carry theirs.
            raise SystemExit(f"{where}: 'required' belongs on a 'run', not a 'job'.")
        return Job(entry["job"])

    argv = shlex.split(entry["run"])
    if not argv:
        raise SystemExit(f"{where}: 'run' is empty.")
    return Step((resolve(argv[0]), *argv[1:]), required=bool(entry.get("required")))


def read_jobs() -> "dict[str, list[Union[Step, Job]]]":
    """The jobs, in the order ci/jobs.toml gives them."""
    try:
        with JOBS_FILE.open("rb") as source:
            described = tomllib.load(source)
    except OSError as error:
        raise SystemExit(f"Could not read {JOBS_FILE_NAME}: {error}") from None
    except tomllib.TOMLDecodeError as error:
        raise SystemExit(f"{JOBS_FILE_NAME}: {error}") from None

    jobs = described.get("jobs")
    if not isinstance(jobs, dict) or not jobs:
        raise SystemExit(f"{JOBS_FILE_NAME}: no [jobs.<name>] tables.")

    read = {}
    for job, described_job in jobs.items():
        steps = described_job.get("steps") if isinstance(described_job, dict) else None
        if not isinstance(steps, list) or not steps:
            raise SystemExit(f"{JOBS_FILE_NAME}: jobs.{job} needs a non-empty 'steps'.")
        read[job] = [read_step(job, index, entry) for index, entry in enumerate(steps)]
    return read


JOBS: "dict[str, list[Union[Step, Job]]]" = read_jobs()


MAX_DEPTH = 8


def job_steps(job: str, depth: int = 0) -> "list[Step]":
    """The steps a job runs: Job() references expanded in place, and any step
    reached more than once kept only where it is first reached.

    This is what runs, what --list shows and what --dry-run prints.
    """
    if depth > MAX_DEPTH:
        raise SystemExit(f"Job references nested too deeply at '{job}'.")
    if job not in JOBS:
        raise SystemExit(f"No such job: {job}")

    steps: "list[Step]" = []
    seen = set()
    for entry in JOBS[job]:
        expanded = job_steps(entry.name, depth + 1) if isinstance(entry, Job) else [entry]
        for one in expanded:
            if one.argv in seen:
                continue
            seen.add(one.argv)
            steps.append(one)
    return steps


# ---------------------------------------------------------------------------
# Running them
# ---------------------------------------------------------------------------


def section(title: str) -> None:
    """A header, collapsible under GitHub Actions."""
    if os.environ.get("GITHUB_ACTIONS"):
        print(f"::group::{title}", flush=True)
    else:
        print(f"\n\033[1m### {title}\033[0m", flush=True)


def endsection() -> None:
    if os.environ.get("GITHUB_ACTIONS"):
        print("::endgroup::", flush=True)


def is_ours(argv: tuple) -> bool:
    """Whether a step is one of ours, and so takes --dry-run."""
    return str(argv[0]).startswith("ci/scripts/")


def runnable(cmd: str) -> bool:
    """Whether a step's command exists, as a file here or a tool on $PATH."""
    return (lib.REPO_TOP / cmd).is_file() or shutil.which(cmd) is not None


def print_step(one: Step, verbose: bool) -> None:
    """Print a step, and with verbose the commands one of our own steps runs.

    The expansion comes from the step itself, run with --dry-run, so this
    cannot drift from what a real run would do.
    """
    line = lib.quote(list(one.argv))
    print(f"{line:<46} # required" if one.required else line)

    if not (verbose and is_ours(one.argv)):
        return

    expanded = subprocess.run(
        [sys.executable, *one.argv, "--dry-run"],
        cwd=lib.REPO_TOP,
        capture_output=True,
        text=True,
    )
    for expansion in expanded.stdout.splitlines():
        print(f"    | {expansion}")

    # A step that cannot say what it would run is a bug in the step, not
    # something to pass over quietly.
    if expanded.returncode:
        print(f"    | (could not expand: {expanded.stderr.strip()})")

    print()


def run_step(one: Step) -> int:
    section(lib.quote(list(one.argv)))
    try:
        status = lib.run(*one.argv, check=False)
    except OSError as error:
        print(f"Could not run step: {error}", file=sys.stderr)
        status = 127
    finally:
        # A stop signal leaves through here as SystemExit, and an unclosed
        # group swallows everything the log has left to say about why.
        endsection()
    return status


def run_job(job: str, failures: list, dry_run: bool, verbose: bool) -> None:
    """Run (or print) one job's steps, in order."""
    if dry_run:
        print(f"# job: {job}")

    for one in job_steps(job):
        if dry_run:
            print_step(one, verbose)
            continue

        if run_step(one) == 0:
            continue

        print(f"::error::CI step failed: {one.argv[0]}", file=sys.stderr)
        failures.append(f"{job} / {one.argv[0]}")

        if one.required:
            print(f"Stopping: the rest of '{job}' depends on it.", file=sys.stderr)
            report(failures)
            raise SystemExit(1)


def report(failures: list) -> int:
    if not failures:
        print("\nAll steps passed.")
        return 0
    print(f"\n{len(failures)} step(s) failed:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    return 1


def show_list() -> None:
    print("Jobs:")
    for job in JOBS:
        print(f"  {job}")
        for one in job_steps(job):
            mark = "!" if one.required else " "
            print(f"      {mark}{lib.quote(list(one.argv))}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("jobs", nargs="*", metavar="job", help="jobs to run, in order")
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="print the steps, run nothing",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="expand our own steps under --dry-run; otherwise echo commands as they run",
    )
    parser.add_argument(
        "-l", "--list", action="store_true", help="list the jobs and their steps"
    )
    parser.add_argument(
        "--step",
        nargs=argparse.REMAINDER,
        metavar="cmd",
        help="run a single step: a name from ci/scripts, or any command",
    )
    args = parser.parse_args()

    if args.list:
        show_list()
        return 0

    if args.verbose and not args.dry_run:
        # Picked up by lib.run in every step, so a real run echoes what it does.
        os.environ["MOCHA_VERBOSE"] = "1"

    if args.step:
        token = args.step[0]
        one = Step((resolve(token), *args.step[1:]))
        # A job whose steps are all plain commands has no script of its own, so
        # say what to run rather than reporting its name as a missing file.
        if token in JOBS and not runnable(one.argv[0]):
            print(f"'{token}' is a job, not a step. Run: ci/run.py {token}", file=sys.stderr)
            return 1
        if args.dry_run:
            print_step(one, args.verbose)
            return 0
        return run_step(one)

    if not args.jobs:
        parser.print_help()
        return 1

    unknown = [job for job in args.jobs if job not in JOBS]
    if unknown:
        print(f"Unknown job: {', '.join(unknown)}\n", file=sys.stderr)
        show_list()
        return 1

    failures: list = []
    for job in args.jobs:
        run_job(job, failures, args.dry_run, args.verbose)

    # Nothing ran, so there is nothing to report on.
    return 0 if args.dry_run else report(failures)


if __name__ == "__main__":
    sys.exit(main())
