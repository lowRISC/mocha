#!/usr/bin/env python
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

"""Package the software release artefact.

Installs the release components out of build/sw and tars them up. The archive
name comes from the argument, or $MOCHA_RELEASE_ARTEFACT, and must match what
the release workflow uploads. Needs the software built.
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import lib

DEFAULT_ARTEFACT = "release_software.tar.gz"

# component -> prefix to install it under
COMPONENTS = {
    "examples": "release/examples",
    "bootrom": "release",
    "boot": "release",
}


def main() -> None:
    parser = lib.parser(__doc__)
    parser.add_argument(
        "artefact",
        nargs="?",
        default=os.environ.get("MOCHA_RELEASE_ARTEFACT") or DEFAULT_ARTEFACT,
        help="archive to write (default: $MOCHA_RELEASE_ARTEFACT, or "
        f"{DEFAULT_ARTEFACT})",
    )
    args = parser.parse_args()

    for component, prefix in COMPONENTS.items():
        lib.run(
            "cmake",
            "--install",
            "build/sw",
            "--prefix",
            prefix,
            "--component",
            component,
            dry_run=args.dry_run,
        )

    lib.run("tar", "-czvf", args.artefact, "release", dry_run=args.dry_run)


if __name__ == "__main__":
    main()
