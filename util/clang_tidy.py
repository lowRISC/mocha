#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Wrapper around clang-tidy which provides the default build directory and
# enumerates the C files to be linted. Passes through any additional arguments.

import os
import sys

DEFAULT_BUILD_DIR = "build/sw"


def main():
    c_files = []
    for directory, _, files in os.walk("sw"):
        c_files.extend(
            os.path.join(directory, file)
            for file in files
            if file.endswith(".c")
        )

    cmd = "clang-tidy"
    cmd_args = [cmd, "-p", DEFAULT_BUILD_DIR, *sys.argv[1:], *c_files]
    os.execvp(cmd, cmd_args)


if __name__ == "__main__":
    main()
