#!/usr/bin/env -S bash -eux
# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

util/fpga_runner.py run -e build/sw/device/examples/infinite_loop
sleep 5
openocd -f util/genesys2-openocd-cfg.tcl &
sleep 5
expect util/gdb_response.exp

kill -SIGTERM $(jobs -p)
