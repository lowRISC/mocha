// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package axi_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // The possible encodings of the AxBURST signal
  typedef enum bit [1:0] {
    BurstFixed = 0,
    BurstIncr  = 1,
    BurstWrap  = 2
  } burst_e;

  `include "axi_agent_cfg.svh"

  `include "axi_txn_request_item.svh"
  `include "axi_read_data_item.svh"

  `include "axi_write_data_item.svh"
  `include "axi_write_response_item.svh"

  `include "axi_response_accept_item.svh"

  `include "axi_status_item.svh"

  `include "axi_mgr_write_request_driver.svh"
  `include "axi_mgr_write_data_driver.svh"
  `include "axi_mgr_write_response_driver.svh"

  `include "axi_mgr_read_request_driver.svh"
  `include "axi_mgr_read_data_driver.svh"
endpackage
