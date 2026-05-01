#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# This script is used auto-generated and vendor files to the repository.
# If the check flag is provided it will verify that all auto-generated and vendored files committed
# to the repository are not stale and match the generated output of the programs used to create
# them.
# This consists of lockfiles, generated hardware components (e.g. crossbars), and hardware
# components vendored and patched with `vendor.py`.

import argparse
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
    # gpio generator
    [
        "hw/vendor/lowrisc_ip/util/ipgen.py",
        "generate",
        "-C",
        "hw/vendor/lowrisc_ip/ip_templates/gpio",
        "-c",
        "hw/top_chip/data/gpio_cfg.hjson",
        "-o",
        "hw/top_chip/ip_autogen/gpio",
        "-f",
    ],
    # alert handler generator
    [
        "hw/vendor/lowrisc_ip/util/ipgen.py",
        "generate",
        "-C",
        "hw/vendor/lowrisc_ip/ip_templates/alert_handler",
        "-c",
        "hw/top_chip/data/alert_handler_cfg.hjson",
        "-o",
        "hw/top_chip/ip_autogen/alert_handler",
        "-f",
    ],
    # clock manager (clkmgr) generator
    [
        "hw/vendor/lowrisc_ip/util/ipgen.py",
        "generate",
        "-C",
        "hw/vendor/lowrisc_ip/ip_templates/clkmgr",
        "-c",
        "hw/top_chip/data/clkmgr_cfg.hjson",
        "-o",
        "hw/top_chip/ip_autogen/clkmgr",
        "-f",
    ],
    # power manager (pwrmgr) generator
    [
        "hw/vendor/lowrisc_ip/util/ipgen.py",
        "generate",
        "-C",
        "hw/vendor/lowrisc_ip/ip_templates/pwrmgr",
        "-c",
        "hw/top_chip/data/pwrmgr_cfg.hjson",
        "-o",
        "hw/top_chip/ip_autogen/pwrmgr",
        "-f",
    ],
    # reset manager (rstmgr) generator
    [
        "hw/vendor/lowrisc_ip/util/ipgen.py",
        "generate",
        "-C",
        "hw/vendor/lowrisc_ip/ip_templates/rstmgr",
        "-c",
        "hw/top_chip/data/rstmgr_cfg.hjson",
        "-o",
        "hw/top_chip/ip_autogen/rstmgr",
        "-f",
    ],
    # plic generator
    [
        "hw/vendor/lowrisc_ip/util/ipgen.py",
        "generate",
        "-C",
        "hw/vendor/lowrisc_ip/ip_templates/rv_plic",
        "-c",
        "hw/top_chip/data/rv_plic_cfg.hjson",
        "-o",
        "hw/top_chip/ip_autogen/rv_plic",
        "-f",
    ],
    # vendored hardware dependencies
    ["util/vendor.py", "hw/vendor/axi_riscv_atomics.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/cva6_cheri.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/hpdcache.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/lowrisc_ip.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/pulp_axi.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/pulp_axi_llc.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/pulp_register_interface.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/sonata_system.vendor.hjson"],
    ["util/vendor.py", "hw/vendor/tagctrl.vendor.hjson"],
    # rdl code gen
    ["mkdir", "-p", "build/rdl"],
    ["rdl2ot", "export-rtl", "--soc", "rdl/mocha.rdl", "build/rdl"],
    # rdl: generate device register headers
    [
        "util/rdlgenerator.py",
        "gen-device-headers",
        "build/rdl/rdl.json",
        "sw/device/lib/hal/autogen",
    ],
    # rdl: generate linkerscript
    [
        "util/rdlgenerator.py",
        "gen-linker-script",
        "build/rdl/rdl.json",
        "sw/device/lib/boot/memory.ld",
    ],
    # rdl: generate memory map image
    [
        "util/rdlgenerator.py",
        "gen-memory-map",
        "build/rdl/rdl.json",
        "doc/img/memmap.svg",
    ],
    # generate devicetree
    [
        "dtc",
        "-I",
        "dts",
        "sw/device/devicetree/mocha.dts",
        "-O",
        "asm",
        "-o",
        "sw/device/devicetree/mocha.S",
        "--align",
        "64",
    ],
    # documentation
    ["d2", "doc/img/mocha.d2"],
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
    parser = argparse.ArgumentParser(description="Artefacts generator utility")
    parser.add_argument("--check", action="store_true", help="Perform a validation check.")
    args = parser.parse_args()

    fail = False
    for cmdline in COMMANDS:
        # run each generator command. these should all succeed
        joined_cmdline = " ".join(cmdline)
        print(f"running '{joined_cmdline}'...")
        run_subprocess(cmdline)

        if not args.check:
            continue

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

    if args.check and fail:
        print("committed auto-generated files do not match!")
        sys.exit(1)


if __name__ == "__main__":
    main()
