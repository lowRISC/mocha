#!/usr/bin/env python
# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import subprocess
import sys
from pathlib import Path

# Path to the OpenTitan-derived script that generates the .logs.txt and
# .rodata.txt database files consumed by the DV sw_logger_if monitor.
_EXTRACT_SW_LOGS = (
    Path(__file__).parent.parent /
    "hw" / "vendor" / "lowrisc_ip" / "util" / "device_sw_utils" /
    "extract_sw_logs.py"
)


def _extract_logs(elf_file: Path, out_dir: Path) -> None:
    """Run extract_sw_logs.py to generate the DV logger database files.

    Generates <target>.logs.txt and <target>.rodata.txt in out_dir.
    The sw_logger_if monitor reads these at simulation start to decode
    printf-style log messages written by firmware to SW_DV_LOG_ADDR.

    A missing .logs.fields ELF section is non-fatal: it means the SW image
    was built without logging support, so we emit a warning and continue.
    """
    if not _EXTRACT_SW_LOGS.exists():
        print(f"Warning: extract_sw_logs.py not found at {_EXTRACT_SW_LOGS}, "
              "skipping DV log database generation.")
        return

    name = elf_file.stem if elf_file.suffix else elf_file.name
    cmd = [
        sys.executable, str(_EXTRACT_SW_LOGS),
        "--elf-file", str(elf_file),
        "--name", name,
        "--outdir", str(out_dir),
    ]
    result = subprocess.run(cmd, capture_output=True)
    if result.returncode != 0:
        stderr = result.stderr.decode(errors="replace").strip()
        print(f"Warning: DV log extraction skipped for '{name}' "
              f"(no .logs.fields section or parse error): {stderr}")


def generate(args) -> None:
    """Build with cmake"""

    out_dir = Path(args.run_dir)
    build_dir = out_dir / "sw_build"
    build_system_cmd = ["cmake", "-B", build_dir, "-S", "sw"]
    subprocess.run(build_system_cmd, capture_output=False, check=True)

    build_cmd = ["cmake", "--build", build_dir, "-v", "--target"]
    install_cmd = ["cmake", "--install", build_dir, "--prefix", out_dir, "--component"]
    for img in args.sw_images.split():
        target = img.split(":")[0]
        cmd = build_cmd + target.split(":")[0:]
        subprocess.run(cmd, capture_output=False, check=True)

        cmd = [*install_cmd, target]
        subprocess.run(cmd, capture_output=False, check=True)

        # Generate .logs.txt / .rodata.txt for the sw_logger_if DV monitor.
        # The ELF is installed without an extension (CMake default).
        elf_file = out_dir / target
        if elf_file.exists():
            _extract_logs(elf_file, out_dir)

    print("Finished")


def main():
    parser = argparse.ArgumentParser(description="Generate software artefact for simulation")
    parser.add_argument("--sw-images", help="List of software images")
    parser.add_argument("--sw-build-opts", help="List of build options")
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
