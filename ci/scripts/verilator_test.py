#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Run the quick Verilator tests.

Everything labelled 'sim_verilator' except the tests marked 'slow', which the
nightly flow covers. Needs the model and the software built.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import lib


def main() -> None:
    args = lib.parser(__doc__).parse_args()

    lib.run(
        "ctest",
        "--test-dir",
        "build/sw",
        "-R",
        "sim_verilator",
        "-LE",
        "slow",
        "--output-on-failure",
        "-j",
        lib.jobs(),
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
