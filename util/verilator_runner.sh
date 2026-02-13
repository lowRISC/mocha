#!/usr/bin/env -S bash -eux
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

ROOT_DIR=$(dirname "$0")/..

timeout 5m $ROOT_DIR/build/lowrisc_mocha_top_chip_verilator_0/sim-verilator/Vtop_chip_verilator \
  -E $1 > /dev/null 2>&1
