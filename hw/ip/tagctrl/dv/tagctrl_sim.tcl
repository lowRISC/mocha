# Copyright lowRISC and contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# The DUT's immediate assertions see X at time 0, before its reset has propagated, so they are off
# for that instant. Then run as the common script does.
assertion -off -depth all tb.dut
run 1ps
assertion -on -depth all tb.dut
source "$::env(dv_root)/tools/sim.tcl"
