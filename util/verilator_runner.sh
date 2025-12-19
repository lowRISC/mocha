#!/usr/bin/env bash
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

ROOT_DIR=$(dirname "$0")/..
LOG_FILE="uart0.log"

timeout 5m $ROOT_DIR/build/lowrisc_mocha_top_chip_system_0/sim-verilator/Vtop_chip_verilator \
  -t -E $1 > /dev/null 2>&1 

if grep -q "TEST RESULT: FAIL" "$LOG_FILE"; then
  echo "Test failed"
  exit 1
elif grep -q "TEST RESULT: PASSED" "$LOG_FILE"; then
  echo "Test passed" 
  exit 0
fi

echo "Simulation crashed"
exit 2

