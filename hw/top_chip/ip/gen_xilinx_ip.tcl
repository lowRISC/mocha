# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

create_ip -name mig_7series -vendor xilinx.com -library ip -version 4.2 -module_name u_xlnx_mig_7_ddr3

exec cp ./src/lowrisc_mocha_chip_mocha_genesys2_0/ip/mig_genesys2_mocha.prj ./lowrisc_mocha_chip_mocha_genesys2_0.srcs/sources_1/ip/u_xlnx_mig_7_ddr3/mig_genesys2_mocha.prj

set_property -dict [list \
  CONFIG.XML_INPUT_FILE {mig_genesys2_mocha.prj} \
  CONFIG.RESET_BOARD_INTERFACE {Custom} \
  CONFIG.MIG_DONT_TOUCH_PARAM {Custom} \
  CONFIG.BOARD_MIG_PARAM {Custom}] [get_ips u_xlnx_mig_7_ddr3]
