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
endpackage
