#!/usr/bin/bash -eux
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Regenerate the crossbar.
hw/vendor/lowrisc_ip/util/tlgen.py \
    -t hw/top_chip/ip/xbar_peri/data/xbar_peri.hjson \
    -o hw/top_chip/ip/xbar_peri

# Check if the generated crossbar is the same as committed.
if [ -z "$(git status --porcelain)" ]; then
  echo "Committed crossbar is the same as generated"
  exit 0
else
  echo "Committed crossbar does not match generated"
  git status --porcelain
  exit 1
fi
