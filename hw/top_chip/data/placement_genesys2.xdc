## Copyright lowRISC contributors (COSMIC project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

## Ethernet MAC Placement Constraints
## Helps to pass timing reliably for a path with 2ns setup requirement
set_property LOC SLICE_X152Y75 [get_cells u_eth_wrapper/u_framing_top/rgmii_soc1/core_inst/eth_mac_inst/eth_mac_1g_rgmii_inst/rgmii_phy_if_inst/rgmii_tx_clk_2_reg]

## SPI Device Clock Buffer Placement Constraints
## Reduces clock skew to help pass timing
set_property LOC BUFR_X0Y6 [get_cells u_top_chip_system/u_spi_device/u_clk_spi_in_buf/gen_fpga_buf.gen_bufr.bufr_i]
set_property LOC BUFR_X0Y7 [get_cells u_top_chip_system/u_spi_device/u_clk_spi_out_buf/gen_fpga_buf.gen_bufr.bufr_i]
