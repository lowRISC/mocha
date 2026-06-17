# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Used to connect OpenOCD to Mocha running on the Genesys2 board.
# To use this configuration you must first disconnect the SPI device and connect up the JTAG pins so this does not work out of the box in Mocha.
# An example diff below:
#################################################
#diff --git a/hw/top_chip/data/pins_genesys2.xdc b/hw/top_chip/data/pins_genesys2.xdc
#index ca742777..aa405125 100644
#--- a/hw/top_chip/data/pins_genesys2.xdc
#+++ b/hw/top_chip/data/pins_genesys2.xdc
#@@ -49,11 +49,11 @@ set_property -dict { PACKAGE_PIN T26   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [ge
# set_property -dict { PACKAGE_PIN T27   IOSTANDARD LVCMOS33 PULLTYPE PULLUP } [get_ports { i2c_sda_io }];
# 
# ## SPI Device (PMOD Header JD)
#-set_property -dict { PACKAGE_PIN W28   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sd_o  }];
#-set_property -dict { PACKAGE_PIN W27   IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sd_i  }];
#-set_property -dict { PACKAGE_PIN W29   IOSTANDARD LVCMOS33 PULLTYPE PULLUP   } [get_ports { spi_device_csb_i }];
#-set_property -dict { PACKAGE_PIN AD27  IOSTANDARD LVCMOS33 PULLTYPE PULLDOWN } [get_ports { spi_device_sck_i }];
#-set_property -dict { PACKAGE_PIN AD29  IOSTANDARD LVCMOS33                   } [get_ports { spien            }];
#+set_property -dict { PACKAGE_PIN W28   IOSTANDARD LVCMOS33 } [get_ports { jtag_tdo }];
#+set_property -dict { PACKAGE_PIN W27   IOSTANDARD LVCMOS33 } [get_ports { jtag_tdi }];
#+set_property -dict { PACKAGE_PIN W29   IOSTANDARD LVCMOS33 } [get_ports { jtag_tms }];
#+set_property -dict { PACKAGE_PIN AD27  IOSTANDARD LVCMOS33 } [get_ports { jtag_tck }];
#+#set_property -dict { PACKAGE_PIN AD29  IOSTANDARD LVCMOS33                   } [get_ports { spien }];
# 
# ## Ethernet RGMII
# set_property -dict { PACKAGE_PIN AH24  IOSTANDARD LVCMOS33 } [get_ports { eth_phyrst_n }];
#diff --git a/hw/top_chip/rtl/chip_mocha_genesys2.sv b/hw/top_chip/rtl/chip_mocha_genesys2.sv
#index 4341266f..101c0b15 100644
#--- a/hw/top_chip/rtl/chip_mocha_genesys2.sv
#+++ b/hw/top_chip/rtl/chip_mocha_genesys2.sv
#@@ -27,11 +27,11 @@ module chip_mocha_genesys2 #(
#   inout  logic i2c_sda_io,
# 
#   // SPI Device
#-  input  logic spi_device_sck_i,
#-  input  logic spi_device_csb_i,
#-  input  logic spi_device_sd_i,
#-  output logic spi_device_sd_o,
#-  output logic spien,
#+  //input  logic spi_device_sck_i,
#+  //input  logic spi_device_csb_i,
#+  //input  logic spi_device_sd_i,
#+  //output logic spi_device_sd_o,
#+  //output logic spien,
# 
#   // SPI Host
#   output logic spi_host_sck_o,
#@@ -72,7 +72,13 @@ module chip_mocha_genesys2 #(
#   output logic       eth_tx_en,
#   output logic [3:0] eth_tx_d,
#   output logic       eth_mdc,
#-  inout  logic       eth_mdio
#+  inout  logic       eth_mdio,
#+
#+  input  logic jtag_tck,
#+  input  logic jtag_tms,
#+  input  logic jtag_tdi,
#+  output logic jtag_tdo,
#+  input  logic jtag_trst
# );
#   // Local parameters
#   localparam int unsigned InitialResetCycles = 4;
#@@ -259,11 +265,11 @@ module chip_mocha_genesys2 #(
#     .mailbox_ext_irq_o   ( ),
# 
#     // SPI device
#-    .spi_device_sck_i     (spi_device_sck_i),
#-    .spi_device_csb_i     (spi_device_csb_i),
#-    .spi_device_sd_o      (qspi_device_sdo),
#-    .spi_device_sd_en_o   (qspi_device_sdo_en),
#-    .spi_device_sd_i      ({3'h0, spi_device_sd_i}), // SPI COPI = QSPI DQ0
#+    .spi_device_sck_i     ('0),
#+    .spi_device_csb_i     ('0),
#+    .spi_device_sd_o      ( ),
#+    .spi_device_sd_en_o   ( ),
#+    .spi_device_sd_i      ('0), // SPI COPI = QSPI DQ0
#     .spi_device_tpm_csb_i ('0),
# 
#     // SPI host
#@@ -291,12 +297,12 @@ module chip_mocha_genesys2 #(
#     // Ethernet IRQ
#     .ethernet_irq_i (ethernet_irq),
# 
#-    // Debug module JTAG tie-off
#-    .dm_jtag_tck    (1'b0),
#-    .dm_jtag_tms    (1'b0),
#-    .dm_jtag_tdi    (1'b0),
#-    .dm_jtag_tdo    ( ),
#-    .dm_jtag_trst_n (1'b0)
#+    // Debug module JTAG
#+    .dm_jtag_tck    (jtag_tck),
#+    .dm_jtag_tms    (jtag_tms),
#+    .dm_jtag_tdi    (jtag_tdi),
#+    .dm_jtag_tdo    (jtag_tdo),
#+    .dm_jtag_trst_n (rst_n_sync_50m)
#   );
# 
#   // GPIO tri-state output drivers
#################################################

adapter driver ftdi
transport select jtag

ftdi vid_pid 0x0403 0x6010
ftdi channel 0
ftdi layout_init 0x0018 0x001b

reset_config none

# Configure JTAG chain and the target processor
set _CHIPNAME riscv-cheri

# Mocha JTAG IDCODE
set _EXPECTED_ID 0x12001CDF

jtag newtap $_CHIPNAME cpu -irlen 5 -expected-id $_EXPECTED_ID -ignore-version
set _TARGETNAME $_CHIPNAME.cpu
target create $_TARGETNAME riscv -chain-position $_TARGETNAME

adapter speed 15000

riscv set_mem_access sysbus progbuf
gdb_report_data_abort enable
gdb_report_register_access_error enable
gdb_breakpoint_override disable

init
halt
