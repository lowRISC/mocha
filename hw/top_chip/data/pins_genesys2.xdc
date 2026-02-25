## Copyright lowRISC contributors (COSMIC project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

## Clock Signal
set_property -dict { PACKAGE_PIN AD11  IOSTANDARD LVDS     } [get_ports { sysclk_200m_ni }];
set_property -dict { PACKAGE_PIN AD12  IOSTANDARD LVDS     } [get_ports { sysclk_200m_pi }];

## External Reset
set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports { ext_rst_ni }];

## GPIO
# Inputs
set_property -dict { PACKAGE_PIN G19   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[0] }]; # SW0 (VADJ)
set_property -dict { PACKAGE_PIN G25   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[1] }]; # SW1 (VADJ)
set_property -dict { PACKAGE_PIN H24   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[2] }]; # SW2 (VADJ)
set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[3] }]; # SW3 (VADJ)
set_property -dict { PACKAGE_PIN N19   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[4] }]; # SW4 (VADJ)
set_property -dict { PACKAGE_PIN P19   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[5] }]; # SW5 (VADJ)
set_property -dict { PACKAGE_PIN P26   IOSTANDARD LVCMOS33 } [get_ports { gpio_i[6] }]; # SW6 (VCC3V3)
set_property -dict { PACKAGE_PIN P27   IOSTANDARD LVCMOS33 } [get_ports { gpio_i[7] }]; # SW7 (VCC3V3)
# Outputs
set_property -dict { PACKAGE_PIN T28   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[0] }]; # LED0
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[1] }]; # LED1
set_property -dict { PACKAGE_PIN U30   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[2] }]; # LED2
set_property -dict { PACKAGE_PIN U29   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[3] }]; # LED3
set_property -dict { PACKAGE_PIN V20   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[4] }]; # LED4
set_property -dict { PACKAGE_PIN V26   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[5] }]; # LED5
set_property -dict { PACKAGE_PIN W24   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[6] }]; # LED6
set_property -dict { PACKAGE_PIN W23   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[7] }]; # LED7

## UART
set_property -dict { PACKAGE_PIN Y20   IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }];
set_property -dict { PACKAGE_PIN Y23   IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }];

## SPI (PMOD Header JD)
set_property -dict { PACKAGE_PIN W28   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sd_o  }];
set_property -dict { PACKAGE_PIN W27   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sd_i  }];
set_property -dict { PACKAGE_PIN W29   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { spi_device_csb_i }];
set_property -dict { PACKAGE_PIN AD27  IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sck_i }];
set_property -dict { PACKAGE_PIN AD29  IOSTANDARD LVCMOS33 } [get_ports { spien }];
