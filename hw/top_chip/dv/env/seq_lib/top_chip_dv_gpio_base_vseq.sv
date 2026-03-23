// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_gpio_base_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_gpio_base_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : top_chip_dv_gpio_base_vseq

function top_chip_dv_gpio_base_vseq::new (string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_gpio_base_vseq::body();
  super.body();
  `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest);
  cfg.gpio_vif.set_pulldown_en({32{1'b1}});

  // TODO
endtask : body
