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
#   User switches
set_property -dict { PACKAGE_PIN G19   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[0] }]; # SW0 (VADJ)
set_property -dict { PACKAGE_PIN G25   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[1] }]; # SW1 (VADJ)
set_property -dict { PACKAGE_PIN H24   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[2] }]; # SW2 (VADJ)
set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[3] }]; # SW3 (VADJ)
set_property -dict { PACKAGE_PIN N19   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[4] }]; # SW4 (VADJ)
set_property -dict { PACKAGE_PIN P19   IOSTANDARD LVCMOS18 } [get_ports { gpio_i[5] }]; # SW5 (VADJ)
set_property -dict { PACKAGE_PIN P26   IOSTANDARD LVCMOS33 } [get_ports { gpio_i[6] }]; # SW6 (VCC3V3)
set_property -dict { PACKAGE_PIN P27   IOSTANDARD LVCMOS33 } [get_ports { gpio_i[7] }]; # SW7 (VCC3V3)
#   Bootstrap pin, should be pulled down during boot to enter bootstrap mode.
set_property -dict { PACKAGE_PIN AB29  IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { gpio_i[8] }]; # PROG_RXFN
#   Micro SD card presence detect line
#   TODO(elliotb): is this active-low or active-high?
set_property -dict { PACKAGE_PIN P28   IOSTANDARD LVCMOS33 } [get_ports { gpio_i[9] }]; # SD_CD

# Outputs
#   User LEDs
set_property -dict { PACKAGE_PIN T28   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[0] }]; # LED0
set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[1] }]; # LED1
set_property -dict { PACKAGE_PIN U30   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[2] }]; # LED2
set_property -dict { PACKAGE_PIN U29   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[3] }]; # LED3
set_property -dict { PACKAGE_PIN V20   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[4] }]; # LED4
set_property -dict { PACKAGE_PIN V26   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[5] }]; # LED5
set_property -dict { PACKAGE_PIN W24   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[6] }]; # LED6
set_property -dict { PACKAGE_PIN W23   IOSTANDARD LVCMOS33 } [get_ports { gpio_o[7] }]; # LED7
#   Micro SD card power (VDD) control (active-low, ext. pull-up)
set_property -dict { PACKAGE_PIN AE24  IOSTANDARD LVCMOS33 } [get_ports { gpio_o[8] }]; # SD_RESET

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

## SPI Device (PMOD Header JD)
set_property -dict { PACKAGE_PIN W28   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sd_o  }];
set_property -dict { PACKAGE_PIN W27   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sd_i  }];
set_property -dict { PACKAGE_PIN W29   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { spi_device_csb_i }];
set_property -dict { PACKAGE_PIN AD27  IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sck_i }];
set_property -dict { PACKAGE_PIN AD29  IOSTANDARD LVCMOS33 } [get_ports { spien }];

## SPI Host (MicroSD card slot)
set_property -dict { PACKAGE_PIN R28   IOSTANDARD LVCMOS33 } [get_ports { spi_host_sck_o }]; # SD_SCLK
set_property -dict { PACKAGE_PIN R26   IOSTANDARD LVCMOS33 } [get_ports { spi_host_sd_i  }]; # SD_DAT0
# set_property -dict { PACKAGE_PIN R30   IOSTANDARD LVCMOS33 } [get_ports { microsd_dat1 }]; # SD_DAT1 unused in SPI bus mode
# set_property -dict { PACKAGE_PIN P29   IOSTANDARD LVCMOS33 } [get_ports { microsd_dat2 }]; # SD_DAT2 unused in SPI bus mode
set_property -dict { PACKAGE_PIN T30   IOSTANDARD LVCMOS33 } [get_ports { spi_host_csb_o }]; # SD_DAT3
set_property -dict { PACKAGE_PIN R29   IOSTANDARD LVCMOS33 } [get_ports { spi_host_sd_o  }]; # SD_CMD
