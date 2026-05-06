#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Wrapper around clang-format which enumerates the C/C++ source and header
# files to be formatted in-place. Passes through any additional arguments.

import argparse
import os
from pathlib import Path

# root of the project directory
PROJECT_ROOT = Path.resolve(Path(__file__)).parent.parent

DEFAULT_ROOT = PROJECT_ROOT / "sw"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help=f"Root folder to search for C/C++ files (default: {DEFAULT_ROOT})",
    )
    args, clang_args = parser.parse_known_args()

    format_extensions = {".c", ".h", ".cc", ".hh"}
    c_files = [
        Path(directory) / file
        for directory, _, files in os.walk(args.root)
        for file in files
        if Path(file).suffix in format_extensions
    ]

    cmd = "clang-format"
    cmd_args = [cmd, "-i", *clang_args, *c_files]
    os.execvp(cmd, cmd_args)


if __name__ == "__main__":
    main()
