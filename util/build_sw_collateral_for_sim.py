#!/usr/bin/env python
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import subprocess
from pathlib import Path


def generate(args) -> None:
    """Build with cmake"""

    out_dir = Path(args.run_dir)
    build_system_cmd = ["cmake", "-B", "build/sw", "-S", "sw"]
    subprocess.run(build_system_cmd, capture_output=False, check=True)

    build_cmd = ["cmake", "--build", "build/sw", "--target"]
    install_cmd = ["cmake", "--install", "build/sw", "--prefix", out_dir, "--component"]
    for img in args.sw_images:
        target = img.split(":")[0]
        cmd = build_cmd + target.split(":")[0:]
        subprocess.run(cmd, capture_output=False, check=True)

        cmd = [*install_cmd, target]
        subprocess.run(cmd, capture_output=False, check=True)

    print("Finished")


def main():
    parser = argparse.ArgumentParser(description="Generate software artefact for simulation")
    parser.add_argument("--sw-images", nargs="+", help="List of software images")
    parser.add_argument("--sw-build-opts", nargs="+", help="List of build options")
    parser.add_argument("--sw-build-device", help="devices")
    parser.add_argument("--seed", help="seed")
    parser.add_argument("--build-seed", help="build-seed")
    parser.add_argument(
        "--run-dir",
        nargs="?",
        help="Where the artefacts should be copied to.",
    )
    parser.set_defaults(func=generate)

    # Parse and execute
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
