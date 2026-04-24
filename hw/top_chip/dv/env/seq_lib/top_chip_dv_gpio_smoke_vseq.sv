// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_gpio_smoke_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_gpio_smoke_vseq)

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();

  // Class specific methods
  //
  // Wait for the pattern to appear on the GPIO's pads
  extern virtual task wait_for_pattern(logic [NUM_GPIOS-1:0] exp_val);
endclass : top_chip_dv_gpio_smoke_vseq

function top_chip_dv_gpio_smoke_vseq::new (string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_gpio_smoke_vseq::body();
  super.body();
  `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest);

  `uvm_info(`gfn, "Starting GPIOs outputs test", UVM_LOW)

  // Disable pin pull-ups enabled to support SW booting process
  cfg.gpio_vif.set_pullup_en('0);

  // SW first drives walking 1's on each pin. Wait till those patterns are visible
  for (int i = 0; i < NUM_GPIOS; i++) begin
    wait_for_pattern(1 << i);
  end

  // Wait for Z so that the pads can safely be driven in inputs
  wait_for_pattern('Z);

  // The outputs on the pads are seen on the edge of sys_clk_if.clk so wait at least a negedge
  // before driving the pads in inputs.
  cfg.sys_clk_vif.wait_n_clks(1);

  `uvm_info(`gfn, "Starting GPIOs inputs test", UVM_LOW)

  // Drive the pads as inputs
  cfg.gpio_vif.drive('h5555_5555);
endtask : body

task top_chip_dv_gpio_smoke_vseq::wait_for_pattern(logic [NUM_GPIOS-1:0] exp_val);
  `DV_SPINWAIT(wait(cfg.gpio_vif.pins === exp_val);,
               $sformatf("Timed out waiting for GPIOs == %0h", exp_val))
endtask : wait_for_pattern
