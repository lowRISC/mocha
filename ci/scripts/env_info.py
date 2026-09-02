#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Print the environment the flow will run in.

The repository, the job count, and the version and path of every tool the steps
call. CI runs this first so the store downloads that realise the shell land
here, instead of burying the output of the first real step -- and so a failure
further down can be read against the versions it happened with.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import lib

# Tools the steps call, and how each one is asked for its version. Most take
# --version; expect wants -v, which is why this is a table and not a list.
#
# gdb and expect are here for the debug tests: on a machine with EDA tools
# configured, their paths go ahead of the devshell's, and `gdb` can turn out to
# be a vendor build that cannot run. That is worth seeing here rather than
# halfway through a debug test.
TOOLS = {
    "cmake": ["--version"],
    "ctest": ["--version"],
    "fusesoc": ["--version"],
    "verilator": ["--version"],
    "openocd": ["--version"],
    "gdb": ["--version"],
    "expect": ["-v"],
    "ruff": ["--version"],
    "reuse": ["--version"],
}

# Tools a step takes from an environment variable rather than $PATH, so that
# this reports the one the step will use. gdb is named by the devshell because
# EDA tool paths come first in $PATH and can shadow it.
FROM_ENV = {
    "gdb": "GDB",
}

MISSING = "<missing>"
UNKNOWN = "<unknown>"
TIMEOUT = 30


def version(tool: str, args: list) -> str:
    """What `tool --version` says, in one line.

    Reported as the tool prints it, rather than a version dug out of it: the
    formats differ ('cmake version 4.1.0', 'Verilator 5.040 2025-01-01') and a
    log is better off with what the tool actually claims. stderr counts, since
    openocd reports its version there.
    """
    try:
        result = subprocess.run(
            [tool, *args],
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
            cwd=lib.REPO_TOP,
        )
    except (OSError, subprocess.SubprocessError):
        return UNKNOWN

    for line in (result.stdout + result.stderr).splitlines():
        if line.strip():
            return " ".join(line.split())
    return UNKNOWN


def main() -> None:
    parser = lib.parser(__doc__)
    args = parser.parse_args()

    if args.dry_run:
        for tool, version_args in TOOLS.items():
            print(lib.quote([tool, *version_args]))
        return

    print(f"repository: {lib.REPO_TOP}")
    print(f"python:     {sys.version.split()[0]} ({sys.executable})")
    print(f"jobs:       {lib.jobs()}")
    print()

    rows = []
    for tool, version_args in TOOLS.items():
        named = os.environ.get(FROM_ENV.get(tool, ""), "").strip()
        path = named or shutil.which(tool)
        rows.append(
            (
                tool,
                path or MISSING,
                "" if not path else version(path, version_args),
            )
        )

    # What a tool reports is last on the line, because it is the one field with
    # no bound: a tool that cannot run reports its whole loader error, and that
    # should not push every path off to the right.
    name_width = max(len(row[0]) for row in rows)
    path_width = max(len(row[1]) for row in rows)
    for name, path, reported in rows:
        print(f"{name:<{name_width}}  {path:<{path_width}}  {reported}".rstrip())


if __name__ == "__main__":
    main()
