## Copyright lowRISC contributors (COSMIC project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

## Clock Signal
set_property -dict { PACKAGE_PIN AD11  IOSTANDARD LVDS     } [get_ports { sysclk_200m_ni }];
set_property -dict { PACKAGE_PIN AD12  IOSTANDARD LVDS     } [get_ports { sysclk_200m_pi }];

## External Reset
set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports { ext_rst_ni }];

## UART
set_property -dict { PACKAGE_PIN Y20   IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }];
set_property -dict { PACKAGE_PIN Y23   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }];

## SPI (PMOD Header JD)
set_property -dict { PACKAGE_PIN U24   IOSTANDARD LVCMOS33   PULLTYPE PULLDOWN } [get_ports { spi_device_sd_o  }];
set_property -dict { PACKAGE_PIN Y26   IOSTANDARD LVCMOS33   PULLTYPE PULLDOWN } [get_ports { spi_device_sd_i  }];
set_property -dict { PACKAGE_PIN V22   IOSTANDARD LVCMOS33   PULLTYPE PULLUP   } [get_ports { spi_device_csb_i }];
set_property -dict { PACKAGE_PIN W21   IOSTANDARD LVCMOS33   PULLTYPE PULLDOWN } [get_ports { spi_device_sck_i }];
