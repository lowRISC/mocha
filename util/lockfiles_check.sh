#!/usr/bin/env -S bash -eux
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Regenerate the lockfiles.
uv lock
nix flake lock

# Check if the generated lockfiles are the same as committed.
if [ -z "$(git status --porcelain)" ]; then
  echo "Committed lockfiles match generated lockfiles"
  exit 0
else
  echo "Committed lockfiles do not match generated"
  git status --porcelain
  exit 1
fi
