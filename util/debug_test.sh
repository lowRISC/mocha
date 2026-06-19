#!/usr/bin/env -S bash -eux
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

build/lowrisc_mocha_top_chip_verilator_0/sim-verilator/Vtop_chip_verilator -r build/sw/device/bootrom/bootrom_scrambled.vmem -E build/sw/device/examples/infinite_loop &
sleep 5
openocd -f util/verilator-openocd-cfg.tcl &
sleep 5
ls build/sw/device/examples
gdb --batch -ex "quit" build/sw/device/examples/infinite_loop
echo "exit: $?"
#expect util/gdb_response.exp

# The pkill command is not available in GitHub actions.
#pkill openocd
#pkill -P $$
kill -SIGTERM $(jobs -p)
