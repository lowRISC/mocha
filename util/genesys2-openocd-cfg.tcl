# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Used to connect OpenOCD to Mocha running on the Genesys2 board.
# This configuration assumes the Olimex ARM-USB-TINY-H adapter is used.

adapter driver ftdi
transport select jtag

ftdi vid_pid 0x15ba 0x002a
ftdi channel 0
ftdi layout_init 0x0018 0x001b
ftdi tdo_sample_edge falling

reset_config none

# Configure JTAG chain and the target processor
set _CHIPNAME riscv-cheri

# Mocha JTAG IDCODE
set _EXPECTED_ID 0x12001CDF

jtag newtap $_CHIPNAME cpu -irlen 5 -expected-id $_EXPECTED_ID -ignore-version
set _TARGETNAME $_CHIPNAME.cpu
target create $_TARGETNAME riscv -chain-position $_TARGETNAME

adapter speed 15000

riscv set_mem_access sysbus progbuf
gdb_report_data_abort enable
gdb_report_register_access_error enable
gdb_breakpoint_override disable

init
halt
