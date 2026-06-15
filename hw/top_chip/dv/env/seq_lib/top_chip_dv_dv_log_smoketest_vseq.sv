// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_dv_log_smoketest_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_dv_log_smoketest_vseq)

  string exp_messages[] = '{
    "SW-DV log smoketest starting...",
    "a = 10, b = 20, c = 12",
    "a + b + c = 42",
    "Smoke test for the SW-DV log interface, completed successfully!"
  };

  typedef bit [1024*8-1:0] arg_t;

  extern function new(string name = "");
  extern task body();
  // Per SV LRM 6.16, a string shorter than the packed type is left-padded with zeros: the last
  // character sits at byte[0] (LSB) and the first at byte[N-1], with zeros above. Scan upward
  // from byte[0] and prepend each character to reconstruct left-to-right order.
  extern function string arg_t_to_string(arg_t val);
endclass : top_chip_dv_dv_log_smoketest_vseq


function top_chip_dv_dv_log_smoketest_vseq::new(string name = "");
  super.new(name);
endfunction : new

function string top_chip_dv_dv_log_smoketest_vseq::arg_t_to_string(arg_t val);
  string result = "";
  for (int i = 0; i < ($bits(val) / 8); i++) begin
    logic [7:0] c = val[i*8 +: 8];
    if (c == 8'h00) break;
    result = {$sformatf("%c", c), result};
  end
  return result;
endfunction : arg_t_to_string

task top_chip_dv_dv_log_smoketest_vseq::body();
  string actual;

  if (cfg == null) begin
    set_handles();
  end

  // Check each expected message inline as the event fires. This ensures we sample printed_log
  // in the same delta as the event.
  for (int i = 0; i < exp_messages.size(); i++) begin
    @(cfg.sw_logger_vif.printed_log_event);
    actual = arg_t_to_string(arg_t'(cfg.sw_logger_vif.printed_log));
    `DV_CHECK_STREQ(actual, exp_messages[i], $sformatf("Log message [%0d] mismatch", i))
  end
endtask : body
