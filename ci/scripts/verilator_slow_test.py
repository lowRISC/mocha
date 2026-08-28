#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Run the slow Verilator tests (the nightly flow).

These take hours, so the list is printed before the run: the log should say
what it is waiting on. Needs a traced model and the software built.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import lib

SELECT = ["--test-dir", "build/sw", "-R", "sim_verilator", "-L", "slow"]


def main() -> None:
    args = lib.parser(__doc__).parse_args()

    lib.run("ctest", *SELECT, "--show-only", dry_run=args.dry_run)
    lib.run("ctest", *SELECT, "--output-on-failure", dry_run=args.dry_run)


if __name__ == "__main__":
    main()
