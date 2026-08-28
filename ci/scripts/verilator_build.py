#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Build the Verilator simulation model.

Verilating and then compiling the model takes roughly a GB per job, so it gets
a fraction of $MOCHA_JOBS (default: every core) rather than all of it.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import lib

CORE = "lowrisc:mocha:top_chip_verilator"


def main() -> None:
    parser = lib.parser(__doc__)
    parser.add_argument(
        "--jobs-divisor",
        type=int,
        default=4,
        metavar="N",
        help="divide $MOCHA_JOBS by N (default: %(default)s; releases use 2)",
    )
    parser.add_argument(
        "--traced",
        action="store_true",
        help="build with tracing enabled, for the nightly slow tests",
    )
    # Anything this parser does not recognise is passed straight to fusesoc.
    args, fusesoc_args = parser.parse_known_args()

    jobs = max(1, lib.jobs() // max(1, args.jobs_divisor))

    traced = []
    if args.traced:
        traced = [
            f"--verilator_options=-j {jobs} --threads 2 --trace-threads 2",
            f"--make_options=-j {jobs}",
        ]

    if not args.dry_run:
        print(f"Building the Verilator model with {jobs} job(s).")

    lib.run(
        "fusesoc",
        "--cores-root=.",
        "run",
        "--target=sim",
        "--tool=verilator",
        "--setup",
        "--build",
        CORE,
        *traced,
        *fusesoc_args,
        env={"MAKEFLAGS": f"-j{jobs}"},
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
