#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Wrapper around clang-format which enumerates the C/C++ source and header
# files to be formatted in-place. Passes through any additional arguments.

import os
import sys
from pathlib import Path

# root of the project directory
PROJECT_ROOT = Path.resolve(Path(__file__)).parent.parent


def main():
    c_files = []
    format_extensions = [".c", ".h", ".cc", ".hh"]
    for directory, _, files in os.walk(PROJECT_ROOT / Path("sw")):
        c_files.extend(
            Path(directory) / Path(file)
            for file in files
            if (Path(file).suffix in format_extensions)
        )

    cmd = "clang-format"
    cmd_args = [cmd, "-i", *sys.argv[1:], *c_files]
    os.execvp(cmd, cmd_args)


if __name__ == "__main__":
    main()
