## Copyright lowRISC contributors (COSMIC project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

## System Clock Signal
## Removed since the generated MIG already provides this clock constraint
## create_clock -period 5.000 -waveform {0 2.5} -name sys_clk_pin -add [get_ports sysclk_200m_pi];

## Free-running Oscillator Clock from Configuration Logic
create_clock -period 10.000 -waveform {0 5} -name cfg_clk_pin -add [get_pins u_clk_gen/STARTUPE2_inst/CFGMCLK];

## Ethernet PHY Rx Clock
## Up to 125 MHz at 1 Gbps
create_clock -period 8.000 -waveform {0 4} -name eth_rxck_pin [get_ports eth_rx_clk];

## Ethernet PHY Rx Clock Asynchronous with All Other Clocks
set_clock_groups -asynchronous -group [get_clocks eth_rxck_pin -include_generated_clocks];

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

## Debug JTAG Clock (Max 30 MHz)
create_clock -period 33.333 -waveform {0 16.667} -name jtag_tck_pin [get_ports jtag_tck];

## Debug JTAG Clock Asynchronous with All Other Clocks
set_clock_groups -asynchronous -group [get_clocks jtag_tck_pin];

## JTAG to Mocha CDC Bus Skew Constraints
## min(33.333ns, 20ns) = 20ns
set_max_delay -datapath_only 20 \
    -from [get_pins -hierarchical -regexp .*/i_dmi_cdc/.*/data_wr_q_reg.*/C] \
    -to [get_pins -hierarchical -regexp .*/i_dmi_cdc/.*/data_rd_q_reg.*/D]

## SPI Device Clock (Max 30 MHz)
create_clock -period 33.333 -waveform {0 16.667} -name spi_dev_sck_pin [get_ports spi_device_sck_i];

## SPI input and output clocks are driven by different BUFRs and should be treated as different clocks
create_generated_clock -name clk_spi_in  -divide_by 1 -add \
    -source [get_ports spi_device_sck_i] \
    -master_clock [get_clocks spi_dev_sck_pin] \
    [get_pins u_top_chip_system/u_spi_device/u_clk_spi_in_buf/gen_fpga_buf.gen_bufr.bufr_i/O]
create_generated_clock -name clk_spi_out -divide_by 1 -invert -add \
    -source [get_ports spi_device_sck_i] \
    -master_clock [get_clocks spi_dev_sck_pin] \
    [get_pins u_top_chip_system/u_spi_device/u_clk_spi_out_buf/gen_fpga_buf.gen_bufr.bufr_i/O]

## SPI Device Clock asynchronous with all other clocks
set_clock_groups -asynchronous -group [get_clocks spi_dev_sck_pin -include_generated_clocks];

## SPI Device CSB pins is used for clocking (Max 15 MHz)
create_clock -period 66.667 -waveform {0 33.333} -name spi_dev_csb_pin [get_ports spi_device_csb_i];

## SPI Device CSB asynchronous with all other clocks
set_clock_groups -asynchronous -group [get_clocks spi_dev_csb_pin -include_generated_clocks];
