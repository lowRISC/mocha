// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package mailbox_env_pkg;
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import axi_agent_pkg::*;
  import mailbox_ral_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  // Mocha FIFO depth from doc/proj/mailbox.md, shared with the testbench
  parameter int unsigned MailboxDepth = 3;

  parameter int unsigned NumPorts = 2;

  // Port 0 connects to the main crossbar; port 1 is external
  typedef enum int unsigned {
    PortMain = 0,
    PortExt  = 1
  } mailbox_port_e;

  // Per-port name suffixes, also used by the testbench for agent config_db scopes
  parameter string PortName [NumPorts] = '{"main", "ext"};

  // Clamp WIRQT/RIRQT using the whole written word, including reserved bits
  function automatic uvm_reg_data_t mailbox_clamp_threshold(uvm_reg_data_t value);
    return (value >= MailboxDepth) ? MailboxDepth - 1 : value;
  endfunction : mailbox_clamp_threshold

  // Accesses modelled by the scoreboard
  typedef enum int unsigned {
    AccessMboxw,
    AccessMboxr,
    AccessStatus,
    AccessWirqt,
    AccessRirqt,
    AccessOther
  } mailbox_access_kind_e;

  // Modelled response with STATUS flags or the stored threshold
  typedef struct packed {
    logic [1:0]    resp;
    uvm_reg_data_t data;
  } mailbox_result_t;

  `include "mailbox_env_cfg.sv"
  `include "mailbox_reg_predictor.sv"
  `include "mailbox_access.sv"
  `include "mailbox_state.sv"
  `include "mailbox_scoreboard.sv"
  `include "mailbox_virtual_sequencer.sv"
  `include "mailbox_env.sv"
  `include "mailbox_vseq_list.sv"
endpackage : mailbox_env_pkg
