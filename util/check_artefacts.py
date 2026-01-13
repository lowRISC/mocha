#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# This script is used to verify that any auto-generated or vendored
# files committed to the repository are not stale and match the generated
# output of the programs used to create them.
# This consists of lockfiles, generated hardware components (e.g. crossbars),
# and hardware components vendored and patched with `vendor.py`.
# This script runs each generator or vendoring program and checks whether the
# file tree changes by using `git status`.

import subprocess
import sys

# the commands which generated committed files to be ran
COMMANDS: list[list[str]] = [
    # lockfiles
    ["uv", "lock"],
    ["nix", "flake", "lock"],
    # crossbar generator
    [
        "hw/vendor/lowrisc_ip/util/tlgen.py",
        "-t",
        "hw/top_chip/ip/xbar_peri/data/xbar_peri.hjson",
        "-o",
        "hw/top_chip/ip/xbar_peri",
    ],
    # generate PLIC
    ["util/generate_plic.sh"],
    # vendored hardware dependencies
    ["util/vendor.py", "hw/vendor/cva6_cheri.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/lowrisc_ip.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/pulp_axi.vendor.hjson"],
]


def run_subprocess(cmdline: list[str]):
    try:
        proc = subprocess.run(cmdline, capture_output=True, check=False)
        if proc.returncode != 0:
            joined_cmdline = " ".join(cmdline)
            print(f"command {joined_cmdline} exited with non-zero exit code {proc.returncode}")
        if proc.stdout:
            print(proc.stdout.decode(), end="")
        if proc.stderr:
            print(proc.stderr.decode(), end="")
        if proc.returncode != 0:
            sys.exit(1)
    except OSError as e:
        print(f"failed to run process '{cmdline[0]}': {e.strerror}")
        sys.exit(1)


def main():
    fail = False
    for cmdline in COMMANDS:
        # run each generator command. these should all succeed
        joined_cmdline = " ".join(cmdline)
        print(f"running '{joined_cmdline}'...")
        run_subprocess(cmdline)

        # check if anything is different by running `git status` and
        # checking if there is any output. we let all the steps run before
        # returning with failure or success, so that the non-matching files
        # after all steps are shown
        try:
            git_status = subprocess.run(
                ["git", "status", "--porcelain"],
                capture_output=True,
                check=False,
            )
            if git_status.stdout:
                fail = True
                print("git tree is dirty!")
                print(git_status.stdout.decode(), end="")
        except OSError as e:
            print(f"failed to run 'git status': {e.strerror}")
            sys.exit(1)

    if fail:
        print("committed auto-generated files do not match!")
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
