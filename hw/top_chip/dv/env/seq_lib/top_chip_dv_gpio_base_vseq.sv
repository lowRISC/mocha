// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_gpio_base_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_gpio_base_vseq)

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();

  // Class specific methods
  //
  // Waits for the pattern to appear on the GPIOs
  extern virtual task wait_for_pattern(logic [NUM_GPIOS-1:0] exp_val);

  // Drives a pattern on the quarter GPIOs pins in input mode
  extern virtual task drive_pattern(int unsigned wait_num_clks,
                                    int unsigned pins_starting_quarter,
                                    int unsigned pins_next_quarter,
                                    bit          state);
endclass : top_chip_dv_gpio_base_vseq

function top_chip_dv_gpio_base_vseq::new (string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_gpio_base_vseq::body();
  super.body();
  `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest);

  // Checks the GPIOs in both input and output mode. SW writes walking 0's and walking 1's pattern
  // on the first and third quarter of direct_out register and body() waits (for a reasonable
  // amount of timeout) for that pattern to appear on the pads. Then it drives all 1's and all 0's
  // on the other even quaters.
  //
  // Enable the pulldowns so that the pads are driving 0's rather than Z's when no external driver
  // is connected
  cfg.gpio_vif.set_pulldown_en('1);

  // Current Current GPIOs pads state : 'h0

  `uvm_info(`gfn, "Starting GPIOs outputs test", UVM_LOW)

  // Check for walking 1's pattern on the first quarter of pins.
  for (int i = 0; i < NUM_GPIOS/4; i++) begin
    wait_for_pattern({24'h0, 1 << i});
  end

  // Current GPIOs pads state : 'h00000080
  //
  // Drive all 1's on the second quarter of pins.
  drive_pattern(2, 1, 2, 1);

  // Current GPIOs pads state : 'h0000FF80
  //
  // Check for walking 1's pattern on the third quarter of pins.
  for (int i = 0; i < NUM_GPIOS/4; i++) begin
    wait_for_pattern({8'h0, 1 << i, 16'hFF80});
  end

  // Current GPIOs pads state : 'h0080FF80
  //
  // Drive all 1's on the fourth quarter of pins.
  drive_pattern(2, 3, 4, 1);

  // Current GPIOs pads state : 'hFF80FF80
  //
  // The SW first sets the first and third quarter of GPIOs to 1's in order to walk 0's on them.
  // The second and fourth quarter of pads should contain all 1's by now.
  //
  // Wait and check for all 1s.
  wait_for_pattern({NUM_GPIOS{1'b1}});

  // Current GPIOs pads state : 'hFFFFFFFF
  //
  // Check for walking 0's pattern on the first quarter of pins.
  for (int i = 0; i < NUM_GPIOS/4; i++) begin
    wait_for_pattern({24'hFF_FFFF, ~(1 << i)});
  end

  // Current GPIOs pads state : 'hFFFFFF7F
  //
  // Drive all 0's on the second quarter of pins.
  drive_pattern(2, 1, 2, 0);

  // Current GPIOs pads state : 'hFFFF007F
  //
  // Check for walking 0's pattern on on the third quarter of pins.
  for (int i = 0; i < NUM_GPIOS/4; i++) begin
    wait_for_pattern({8'hFF, ~(1 << i), 16'h007F});
  end

  // Current GPIOs pads state : 'hFF7F007F
  //
  // Drive all 0's on the fourth quarter of pins.
  drive_pattern(2, 3, 4, 0);

  // Current GPIOs pads state : 'h007F007F
endtask : body

task top_chip_dv_gpio_base_vseq::wait_for_pattern(logic [NUM_GPIOS-1:0] exp_val);
  `DV_SPINWAIT(wait(cfg.gpio_vif.pins === exp_val);,
               $sformatf("Timed out waiting for GPIOs == %0h", exp_val),
               /*use default_spinwait_timeout_ns*/,
              `gfn)
endtask : wait_for_pattern

task top_chip_dv_gpio_base_vseq::drive_pattern(int unsigned wait_num_clks,
                                               int unsigned pins_starting_quarter,
                                               int unsigned pins_next_quarter,
                                               bit          state);

  int unsigned quarter_start = (NUM_GPIOS/4) * pins_starting_quarter;
  int unsigned quarter_end   = (NUM_GPIOS/4) * pins_next_quarter;

  // Wait for some cycles so that the pads can transition from the current pin state to the next pin
  // state
  cfg.sys_clk_vif.wait_clks(wait_num_clks);

  // Drive state on the quarter of pins
  for (int i = quarter_start; i < quarter_end; i++) begin
    cfg.gpio_vif.drive_pin(i, state);
  end
endtask : drive_pattern
