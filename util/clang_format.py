#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Wrapper around clang-format which enumerates the C files to be formatted
# in-place. Passes through any additional arguments.

import os
import sys


def main():
    c_files = []
    for directory, _, files in os.walk("sw"):
        c_files.extend(
            os.path.join(directory, file)
            for file in files
            if file.endswith(".c")
        )

    cmd = "clang-format"
    cmd_args = [cmd, "-i", *sys.argv[1:], *c_files]
    os.execvp(cmd, cmd_args)


if __name__ == "__main__":
    main()
