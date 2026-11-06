// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`uvm_analysis_imp_decl(_mon)

// Predict OKAY responses and the WIRQT/RIRQT clamp, which a 2-bit field cannot express. Use
// uvm_sequence_item because the predictor creates bus items through the factory; abstract
// axi_mon_item connects through mon_imp.
class mailbox_reg_predictor extends uvm_reg_predictor #(uvm_sequence_item);
  `uvm_component_utils(mailbox_reg_predictor)

  uvm_analysis_imp_mon #(axi_mon_item, mailbox_reg_predictor) mon_imp;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);

  // Class specific methods
  // Filter error responses because uvm_reg_predictor updates the mirror regardless of status
  extern function void write_mon(axi_mon_item tr);

  // Apply the WIRQT/RIRQT clamp before updating the mirror
  extern virtual function void pre_predict(uvm_reg_item rw);
endclass : mailbox_reg_predictor


function mailbox_reg_predictor::new(string name, uvm_component parent);
  super.new(name, parent);
  mon_imp = new("mon_imp", this);
endfunction : new

function void mailbox_reg_predictor::write_mon(axi_mon_item tr);
  uvm_reg_bus_op rw;

  rw.byte_en = '1;
  adapter.bus2reg(tr, rw);
  if (rw.status == UVM_IS_OK) begin
    write(tr);
  end
endfunction : write_mon

function void mailbox_reg_predictor::pre_predict(uvm_reg_item rw);
  mailbox_reg_block ral;
  uvm_reg           rg;

  `downcast(ral, map.get_parent())
  `downcast(rg, rw.element)
  if (rw.kind == UVM_WRITE && (rg == ral.wirqt || rg == ral.rirqt)) begin
    rw.value[0] = mailbox_clamp_threshold(rw.value[0]);
  end
endfunction : pre_predict
