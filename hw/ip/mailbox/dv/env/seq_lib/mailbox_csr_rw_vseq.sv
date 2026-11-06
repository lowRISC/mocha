// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check R/W registers on both ports with immediate readback and WIRQT/RIRQT clamp prediction.
// Shuffle directed boundary and reserved-bit values before random writes, weighted equally between
// 0 through MailboxDepth and larger values. Compare only reserved IRQS bits because V1 does not
// predict its volatile fields.
class mailbox_csr_rw_vseq extends mailbox_csr_base_vseq;
  `uvm_object_utils(mailbox_csr_rw_vseq)

  typedef struct {
    uvm_reg        rg;
    uvm_reg_data_t value;
  } reg_write_t;

  rand int unsigned num_writes;

  constraint num_writes_c {
    num_writes inside {[20:50]};
  }

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods
  // Return directed values for rg, omitting registers with volatile fields
  extern function void get_directed_values(uvm_reg rg, output uvm_reg_data_t values[$]);

  // Write rg and compare its readback with the prediction
  extern task write_and_check(uvm_reg rg, uvm_reg_data_t value);
endclass : mailbox_csr_rw_vseq


function mailbox_csr_rw_vseq::new(string name = "");
  super.new(name);
endfunction : new

task mailbox_csr_rw_vseq::body();
  uvm_reg     regs[$];
  reg_write_t directed[$];

  foreach (cfg.ral[i]) begin
    uvm_reg port_regs[$];

    get_rw_regs(mailbox_port_e'(i), CsrRwTest, port_regs);
    regs = {regs, port_regs};
  end

  foreach (regs[i]) begin
    uvm_reg_data_t values[$];

    get_directed_values(regs[i], values);
    foreach (values[j]) begin
      directed.push_back('{rg: regs[i], value: values[j]});
    end
  end
  directed.shuffle();
  foreach (directed[i]) begin
    write_and_check(directed[i].rg, directed[i].value);
  end

  repeat (num_writes) begin
    int unsigned   idx;
    uvm_reg_data_t value;

    `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(idx, idx < regs.size();)
    `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(value,
                                       value dist {[0:MailboxDepth] :/ 1,
                                                   [MailboxDepth + 1:~uvm_reg_data_t'(0)] :/ 1};)
    write_and_check(regs[idx], value);
  end
endtask : body

function void mailbox_csr_rw_vseq::get_directed_values(uvm_reg rg, output uvm_reg_data_t values[$]);
  mailbox_reg_block ral;
  uvm_reg_data_t    mask = get_field_mask(rg);
  uvm_reg_data_t    above;

  `downcast(ral, rg.get_parent())
  `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(above, (above & ~mask) != 0;)
  if (rg == ral.wirqt || rg == ral.rirqt) begin
    values = '{0, MailboxDepth - 1, MailboxDepth, above};
  end else if (rg == ral.irqen) begin
    values = '{0, mask, above};
  end else begin
    values.delete();
  end
endfunction : get_directed_values

task mailbox_csr_rw_vseq::write_and_check(uvm_reg rg, uvm_reg_data_t value);
  uvm_status_e status;

  rg.write(status, value, .parent(this));
  check_status(status, rg, "Write to");
  rg.mirror(status, UVM_CHECK, .parent(this));
  check_status(status, rg, "Read of");
endtask : write_and_check
