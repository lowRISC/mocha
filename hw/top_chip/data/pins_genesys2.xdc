## Copyright lowRISC contributors (COSMIC project).
## Licensed under the Apache License, Version 2.0, see LICENSE for details.
## SPDX-License-Identifier: Apache-2.0

## Clock Signal
set_property -dict { PACKAGE_PIN AD11  IOSTANDARD LVDS     } [get_ports { sysclk_200m_ni }];
set_property -dict { PACKAGE_PIN AD12  IOSTANDARD LVDS     } [get_ports { sysclk_200m_pi }];

## External Reset
set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports { ext_rst_ni }];
set_property -dict { PACKAGE_PIN AB25  IOSTANDARD LVCMOS33 } [get_ports { ftdi_rst_ni }];

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

# Bootstrap pin, should be pulled down during boot to enter bootstrap mode.
set_property -dict { PACKAGE_PIN AB29  IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { gpio_i[8] }];

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

## I^2C (PMOD Header "JA")
# Enable pull-ups on SCL and SDA.
# The PMOD I^2C specification states that the SCL and SDA pull-ups are provided
# on the modules, so using the FPGA pull-ups is not required for their benefit.
# However, the PCB tracks between the PMOD header and FPGA are not short,
# and the FPGA pull-ups are not too strong (~20k based on Xilinx doc DS182),
# so it seems best to enable the in-built pull-ups.
set_property -dict { PACKAGE_PIN T26   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { i2c_scl_io }];
set_property -dict { PACKAGE_PIN T27   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { i2c_sda_io }];

## SPI (PMOD Header JD)
set_property -dict { PACKAGE_PIN W28   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sd_o  }];
set_property -dict { PACKAGE_PIN W27   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sd_i  }];
set_property -dict { PACKAGE_PIN W29   IOSTANDARD LVCMOS33 PULLTYPE PULLUP   } [get_ports { spi_device_csb_i }];
set_property -dict { PACKAGE_PIN AD27  IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sck_i }];
set_property -dict { PACKAGE_PIN AD29  IOSTANDARD LVCMOS33                   } [get_ports { spien            }];

## Ethernet RGMII
set_property -dict { PACKAGE_PIN AH24  IOSTANDARD LVCMOS33 } [get_ports { eth_rgmii_rst_no   }];
set_property -dict { PACKAGE_PIN AG10  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_rxck_i   }];
set_property -dict { PACKAGE_PIN AH11  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_rxctl_i  }];
set_property -dict { PACKAGE_PIN AJ14  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_rxd_i[0] }];
set_property -dict { PACKAGE_PIN AH14  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_rxd_i[1] }];
set_property -dict { PACKAGE_PIN AK13  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_rxd_i[2] }];
set_property -dict { PACKAGE_PIN AJ13  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_rxd_i[3] }];
set_property -dict { PACKAGE_PIN AE10  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_txck_o   }];
set_property -dict { PACKAGE_PIN AK14  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_txctl_o  }];
set_property -dict { PACKAGE_PIN AJ12  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_txd_o[0] }];
set_property -dict { PACKAGE_PIN AK11  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_txd_o[1] }];
set_property -dict { PACKAGE_PIN AJ11  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_txd_o[2] }];
set_property -dict { PACKAGE_PIN AK10  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_txd_o[3] }];
set_property -dict { PACKAGE_PIN AF12  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_mdc_o    }];
set_property -dict { PACKAGE_PIN AG12  IOSTANDARD LVCMOS15 } [get_ports { eth_rgmii_mdio_io  }];
