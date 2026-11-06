// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check word delivery and order with serial batches, including one full FIFO, then concurrent
// writes and drains on both ports. Check STATUS after each write batch, before each MBOXR read and
// after each drain. Avoid writes to full FIFOs and reads from empty FIFOs; V2 covers those errors.
class mailbox_smoke_vseq extends mailbox_base_vseq;
  `uvm_object_utils(mailbox_smoke_vseq)

  // Writer and word count for each serial batch
  rand mailbox_port_e serial_writer[];
  rand int unsigned   serial_len[];

  // Per-port word counts for concurrent writes
  rand int unsigned concurrent_len[NumPorts];

  constraint serial_c {
    serial_len.size() inside {[2:6]};
    serial_writer.size() == serial_len.size();
    foreach (serial_len[i]) {
      serial_len[i] inside {[1:MailboxDepth]};
    }
    MailboxDepth inside {serial_len};
  }

  constraint concurrent_c {
    foreach (concurrent_len[i]) {
      concurrent_len[i] inside {[1:MailboxDepth]};
    }
  }

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods
  // Write num_words random MBOXW words, then read STATUS
  extern task send_batch(mailbox_port_e port, int unsigned num_words);

  // Read num_words MBOXR words, checking STATUS before each and after the last
  extern task drain_batch(mailbox_port_e port, int unsigned num_words);
endclass : mailbox_smoke_vseq


function mailbox_smoke_vseq::new(string name = "");
  super.new(name);
endfunction : new

task mailbox_smoke_vseq::body();
  cfg.min_checked_words = serial_len.sum() + concurrent_len.sum();

  foreach (serial_len[i]) begin
    send_batch(serial_writer[i], serial_len[i]);
    drain_batch(mailbox_port_e'(1 - serial_writer[i]), serial_len[i]);
  end

  fork
    begin : main_writes
      send_batch(PortMain, concurrent_len[PortMain]);
    end : main_writes
    begin : ext_writes
      send_batch(PortExt, concurrent_len[PortExt]);
    end : ext_writes
  join
  fork
    begin : main_reads
      drain_batch(PortMain, concurrent_len[PortExt]);
    end : main_reads
    begin : ext_reads
      drain_batch(PortExt, concurrent_len[PortMain]);
    end : ext_reads
  join
endtask : body

task mailbox_smoke_vseq::send_batch(mailbox_port_e port, int unsigned num_words);
  repeat (num_words) begin
    uvm_reg_data_t data;

    `DV_CHECK_STD_RANDOMIZE_FATAL(data)
    write_mboxw(port, data);
  end
  read_status(port);
endtask : send_batch

task mailbox_smoke_vseq::drain_batch(mailbox_port_e port, int unsigned num_words);
  repeat (num_words) begin
    read_status(port);
    read_mboxr(port);
  end
  read_status(port);
endtask : drain_batch
