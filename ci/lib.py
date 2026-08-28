#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Shared helpers for the CI steps and the job runner (ci/run.py).

Standard library only, like the rest of util/: the CI flow has to work in a
fresh devshell without anything installed on top of it.

Commands run from the repository root, so a step can use the paths the
buildsystem does (build/sw, sw, util/...) wherever it was invoked from.
"""

import argparse
import contextlib
import os
import shlex
import signal
import subprocess
import sys
import threading
from pathlib import Path

REPO_TOP = Path(__file__).resolve().parents[1]

# How a run is asked to stop: SIGINT from Ctrl-C at the terminal or from a
# cancelled Actions job, SIGTERM from the runner when SIGINT was not enough.
STOP_SIGNALS = (signal.SIGINT, signal.SIGTERM)

# How long a command gets to stop of its own accord before it is killed.
GRACE_SECONDS = 10


def jobs() -> int:
    """How many jobs to build with: $MOCHA_JOBS, or every core."""
    value = os.environ.get("MOCHA_JOBS", "").strip()
    if not value:
        return os.cpu_count() or 1
    try:
        return max(1, int(value))
    except ValueError:
        raise SystemExit(f"$MOCHA_JOBS is not a number: {value!r}") from None


def quote(argv: list) -> str:
    """A command line, as you would type it."""
    return shlex.join(str(arg) for arg in argv)


def parser(description: str) -> argparse.ArgumentParser:
    """An argument parser for a step, with the options every step takes."""
    step_parser = argparse.ArgumentParser(description=description)
    step_parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="print the commands this step runs, run nothing",
    )
    return step_parser


def signal_group(group: int, signum: int) -> None:
    """Signal a process group, which may already have gone."""
    with contextlib.suppress(ProcessLookupError):
        os.killpg(group, signum)


def stop(group: int, signum: int) -> "threading.Timer":
    """Pass a stop signal on to a command and everything it started, and start
    the clock on killing the group outright if it does not go.

    An orphaned ctest or nix build holds the FPGA board and keeps a cancelled
    job alive until the runner gives up on it, so nothing is left to outlive
    the grace period.

    Nothing here waits on the command: this runs in a signal handler, on the
    thread already waiting for it, and a second wait would deadlock against
    the first. The grace period is a timer instead, and the interrupted wait
    picks the exit up as it would any other.
    """
    signal_group(group, signum)

    def out_of_time() -> None:
        print(
            f"Command did not stop within {GRACE_SECONDS}s; killing it.",
            file=sys.stderr,
            flush=True,
        )
        signal_group(group, signal.SIGKILL)

    timer = threading.Timer(GRACE_SECONDS, out_of_time)
    timer.daemon = True
    timer.start()
    return timer


def run(
    *argv, env: "dict | None" = None, dry_run: bool = False, check: bool = True
) -> int:
    """Run one command from the repository root and return its exit status.

    With dry_run, print the command instead of running it. With check, a
    non-zero status raises SystemExit, which is what a step wants: it stops
    there and ci/run.py reports the step as failed.

    A stop signal is not a failed step: the command and everything it started
    are taken down and SystemExit is raised whatever `check` says, so the run
    ends here rather than carrying on into steps that would run against a job
    already being torn down.

    $MOCHA_VERBOSE (set by `ci/run.py --verbose`) echoes each command as it
    runs, so a real run says what it did, not just what it was asked to do.
    """
    command = [str(arg) for arg in argv]
    # Show any environment the command is run with the way you would set it.
    prefix = "".join(f"{name}={quote([value])} " for name, value in (env or {}).items())

    if dry_run:
        print(f"{prefix}{quote(command)}")
        return 0

    if os.environ.get("MOCHA_VERBOSE"):
        print(f"+ {prefix}{quote(command)}", flush=True)

    process = subprocess.Popen(
        command,
        cwd=REPO_TOP,
        env={**os.environ, **(env or {})},
        # Its own process group, so a stop signal can be delivered to the
        # command and everything it spawned together rather than to the
        # leader alone.
        start_new_session=True,
    )

    # start_new_session makes the command the leader of its own group, so its
    # pid is the group to signal.
    group = process.pid
    stopped = None
    timer = None
    previous = {}

    def on_signal(signum, _frame):
        nonlocal stopped, timer
        stopped = signum
        timer = stop(group, signum)

    try:
        for one in STOP_SIGNALS:
            previous[one] = signal.signal(one, on_signal)
        status = process.wait()
    finally:
        for one, handler in previous.items():
            signal.signal(one, handler)
        if timer is not None:
            timer.cancel()

    if stopped is not None:
        # The command has gone, but something it spawned can still be holding
        # the board, so take the group with it.
        signal_group(group, signal.SIGKILL)
        raise SystemExit(128 + stopped)

    # A command killed by a signal comes back as -N. Report it the way a shell
    # does, so what this returns is always a real exit status.
    if status < 0:
        status = 128 + -status

    if status and check:
        raise SystemExit(status)
    return status
