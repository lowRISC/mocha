#!/usr/bin/bash -eux
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Apply vendoring.
util/vendor.py hw/vendor/cva6_cheri.vendor.hjson
util/vendor.py hw/vendor/lowrisc_ip.vendor.hjson
util/vendor.py hw/vendor/pulp_axi.vendor.hjson

# Check if vendoring applied correctly without any diff.
if [ -z "$(git status --porcelain)" ]; then
  echo "Vendoring applied correctly"
  exit 0
else
  echo "There are some modifications to apply"
  git status --porcelain
  exit 1
fi
