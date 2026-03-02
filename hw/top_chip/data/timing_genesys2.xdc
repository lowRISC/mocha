## Copyright lowRISC contributors (COSMIC project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

## System Clock Signal
create_clock -period 5.000 -waveform {0 2.5} -name sys_clk_pin -add [get_ports sysclk_200m_pi];

## Free-running Oscillator Clock from Configuration Logic
create_clock -period 10.000 -waveform {0 5} -name cfg_clk_pin -add [get_pins clk_gen/STARTUPE2_inst/CFGMCLK];

## Tag Controller to MIG AXI CDC Constraints
## min(T_src, T_dst) = min(20ns, 5ns) = 5ns
set_max_delay 5 \
    -through [get_pins -hierarchical -filter async] \
    -through [get_pins -hierarchical -filter async]
set_false_path -hold \
    -through [get_pins -hierarchical -filter async] \
    -through [get_pins -hierarchical -filter async]
