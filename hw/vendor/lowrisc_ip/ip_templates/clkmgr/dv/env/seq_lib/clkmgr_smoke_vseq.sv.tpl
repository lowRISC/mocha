// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// smoke test vseq
class clkmgr_smoke_vseq extends clkmgr_base_vseq;
  `uvm_object_utils(clkmgr_smoke_vseq)

  `uvm_object_new

% for src in sorted(src_clks.values(), key=lambda s: s['name']):
  % if not src['aon']:
  constraint ${src['name']}_ip_clk_en_on_c {${src['name']}_ip_clk_en == 1'b1;}
  % endif
% endfor
  constraint all_busy_c {idle == IdleAllBusy;}

  task body();
    cfg.clk_rst_vif.wait_clks(10);
    test_jitter();
    test_peri_clocks();
  endtask : body

  // Simply flip the jitter enable CSR. The side-effects are checked in the scoreboard.
  // This needs to be done outside the various CSR tests, since they update the jitter_enable
  // CSR, but the scoreboard is disabled for those tests.
  task test_jitter();
    prim_mubi_pkg::mubi4_t jitter_value;
    for (int i = 0; i < (1 << $bits(prim_mubi_pkg::mubi4_t)); ++i) begin
      jitter_value = prim_mubi_pkg::mubi4_t'(i);
      csr_wr(.ptr(ral.jitter_enable), .value(jitter_value));
      csr_rd_check(.ptr(ral.jitter_enable), .compare_value(jitter_value));
      // And set it back.
      cfg.clk_rst_vif.wait_clks(6);
      csr_wr(.ptr(ral.jitter_enable), .value('0));
      csr_rd_check(.ptr(ral.jitter_enable), .compare_value('0));
    end
  endtask

  // Flips all clk_enables bits from the reset value with all enabled. All is checked
  // via assertions in clkmgr_if.sv and behavioral code in the scoreboard.
  task test_peri_clocks();
    // Flip all bits of clk_enables.
    peri_enables_t value = ral.clk_enables.get();
    peri_enables_t flipped_value;
    csr_rd(.ptr(ral.clk_enables), .value(value));
    flipped_value = value ^ ((1 << ral.clk_enables.get_n_bits()) - 1);
    csr_wr(.ptr(ral.clk_enables), .value(flipped_value));

    // And set it back to the reset value for stress tests.
    cfg.clk_rst_vif.wait_clks(1);
    csr_wr(.ptr(ral.clk_enables), .value(ral.clk_enables.get_reset()));
  endtask : test_peri_clocks

endclass : clkmgr_smoke_vseq
