## Copyright lowRISC contributors (COSMIC project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

## System Clock Signal
create_clock -period 5.000 -waveform {0 2.5} -name sys_clk_pin -add [get_ports sysclk_200m_pi];

## Free-running Oscillator Clock from Configuration Logic
create_clock -period 10.000 -waveform {0 5} -name cfg_clk_pin -add [get_pins u_clk_gen/STARTUPE2_inst/CFGMCLK];

## 125 MHz Ethernet PHY RX Clock
create_clock -period 8.000 -name eth_rxck_pin [get_ports eth_rxck];

## Ethernet Clocks Asynchronous with All Other Clocks
set_clock_groups -asynchronous -group [get_clocks eth_rxck_pin -include_generated_clocks];
# set_clock_groups -asynchronous -group [get_clocks clk_out2_xlnx_clk_gen];
# set_clock_groups -asynchronous -group [get_clocks clk_125m_unbuf];
# set_clock_groups -asynchronous -group [get_pins u_clk_gen/pll/CLKOUT2];

## Tag Controller to MIG AXI CDC Constraints
## Removed since the custom attribute async cannot be used to select pins,
## and the CDC paths can be timed without difficulty
## min(T_src, T_dst) = min(20ns, 5ns) = 5ns
## set_max_delay 5 \
##     -through [get_pins -hierarchical -filter async] \
##     -through [get_pins -hierarchical -filter async]
## set_false_path -hold \
##     -through [get_pins -hierarchical -filter async] \
##     -through [get_pins -hierarchical -filter async]
