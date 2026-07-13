## Copyright lowRISC and contributors (COSMIC project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

## SPI Device Clock Buffer Placement Constraints
## Reduces clock skew to help pass timing
set_property LOC BUFR_X0Y6 [get_cells u_top_chip_system/u_spi_device/u_clk_spi_in_buf/gen_fpga_buf.gen_bufr.bufr_i]
set_property LOC BUFR_X0Y7 [get_cells u_top_chip_system/u_spi_device/u_clk_spi_out_buf/gen_fpga_buf.gen_bufr.bufr_i]
