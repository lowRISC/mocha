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

A step is a command: a tool the devshell provides, one of the repository's
util/ scripts, or -- where a step needs arguments worked out, or is more than
one command -- a script in ci/scripts. Steps run from the repository root and
each is runnable on its own.

A step the rest of its job depends on, a configure or a build, is Required():
if it fails the run stops there. Any other step records its failure and the job
carries on, so one run reports every problem it can find.

A job can also name another job, Job("name"), to run its steps at that point:
the sequences are written once and composed rather than restated. A step
reached twice over runs once, the first time it is reached.

Parallelism comes from $MOCHA_JOBS (default: every core), so
`MOCHA_JOBS=8 nix run .#ci -- verilator-test` leaves a machine usable.
"""

import argparse
import os
import shutil
import subprocess
import sys
from typing import NamedTuple, Union

import lib


class Step(NamedTuple):
    """A command to run, and whether the rest of its job depends on it."""

    argv: tuple
    required: bool = False


class Job(NamedTuple):
    """Another job's steps, run at this point in the list."""

    name: str


# Reads as a kind of step rather than a function, hence the capital.
def Required(*argv) -> Step:
    return Step(tuple(argv), required=True)


def step(*argv) -> Step:
    return Step(tuple(argv))


def ci_script(name: str, *args) -> tuple:
    """One of our own steps, by its job-style name."""
    return (f"ci/scripts/{name.replace('-', '_')}.py", *args)


# ---------------------------------------------------------------------------
# The jobs. One per CI job, named after it; the workflows call these by name.
# ---------------------------------------------------------------------------

JOBS: "dict[str, list[Union[Step, Job]]]" = {
    "sw-configure": [
        Required("cmake", "-B", "build/sw", "-S", "sw"),
    ],
    # clang-format and clang-tidy read the compilation database, so the
    # buildsystem has to exist before them.
    "lint": [
        step("reuse", "lint"),
        step("util/artefacts.py", "--check"),
        step("ruff", "check"),
        Job("sw-configure"),
        step("util/clang_format.py", "-i", "--dry-run", "-Werror"),
        step("util/clang_tidy.py"),
        step("util/tool_schema_validate.py"),
    ],
    # The FPGA jobs build the software here, then the workflow flashes the
    # board between this job and fpga-test.
    "sw-build": [
        Job("sw-configure"),
        Required(*ci_script("sw-build")),
    ],
    "verilator-test": [
        Job("sw-build"),
        Required(*ci_script("verilator-build")),
        step(*ci_script("verilator-test")),
    ],
    # The debug test only needs a bootrom to run and something to step through,
    # so it builds those targets rather than the whole tree.
    "verilator-debug-test": [
        Job("sw-configure"),
        Required(*ci_script("sw-build"), "--target", "bootrom", "--target", "infinite_loop"),
        Required(*ci_script("verilator-build")),
        step("util/debug_test_verilator.sh"),
    ],
    "verilator-slow-test": [
        Job("sw-build"),
        Required(*ci_script("verilator-build"), "--traced"),
        step(*ci_script("verilator-slow-test")),
    ],
    # Needs the software built and the bitstream loaded, which the workflow
    # does with `nix run .#bitstream-load` outside the devshell.
    "fpga-test": [
        step("ctest", "--test-dir", "build/sw", "-R", "fpga", "-LE", "slow", "--output-on-failure"),
    ],
    "fpga-debug-test": [
        step("util/debug_test_fpga.sh"),
    ],
    # Releases get a faster model build than CI: nothing shares the machine.
    "verilator-release": [
        Required(*ci_script("verilator-build"), "--jobs-divisor", "2"),
    ],
    "software-release": [
        Job("sw-build"),
        Required(*ci_script("sw-release")),
    ],
    "warmup": [
        step(*ci_script("env-info")),
    ],
    # Every job that does not need an FPGA board attached. The local pre-push
    # run.
    "all": [
        Job("warmup"),
        Job("lint"),
        Job("verilator-test"),
        Job("verilator-debug-test"),
    ],
}

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


def resolve(token: str) -> str:
    """The command a step name refers to: a bare name is a script in
    ci/scripts, so `--step sw-build` works as well as the path the jobs use.
    """
    candidate = lib.REPO_TOP / f"ci/scripts/{token.replace('-', '_')}.py"
    return str(candidate.relative_to(lib.REPO_TOP)) if candidate.is_file() else token


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
