#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Build the software in build/sw.

With no arguments the whole tree; anything else is passed to cmake --build, to
narrow it:

    ci/scripts/sw_build.py --target bootrom --target infinite_loop

Parallelism comes from $MOCHA_JOBS (default: every core).
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import lib


def main() -> None:
    parser = lib.parser(__doc__)
    # Unrecognised arguments (--target ...) are passed straight to cmake, so
    # they need no separator on the command line.
    args, cmake_args = parser.parse_known_args()

    lib.run(
        "cmake",
        "--build",
        "build/sw",
        "-j",
        lib.jobs(),
        *cmake_args,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
