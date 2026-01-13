#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Wrapper around clang-tidy which provides the default build directory and
# enumerates the C/C++ files to be linted. Passes through any additional
# arguments.

import os
import sys
from pathlib import Path

DEFAULT_BUILD_DIR = "build/sw"


def main():
    c_files = []
    tidy_extensions = [".c", ".cc"]
    for directory, _, files in os.walk("sw"):
        c_files.extend(
            Path(directory) / Path(file) for file in files if (Path(file).suffix in tidy_extensions)
        )

    cmd = "clang-tidy"
    cmd_args = [cmd, "-p", DEFAULT_BUILD_DIR, *sys.argv[1:], *c_files]
    os.execvp(cmd, cmd_args)


if __name__ == "__main__":
    main()
