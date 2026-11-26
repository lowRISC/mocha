// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  `uvm_analysis_imp_decl(_cfg)
  `uvm_analysis_imp_decl(_tag)

  // Takes every completed access on the configuration and tagged subordinates, in the order the
  // accesses complete, asks tagctrl_predictor what it expects, compares, then hands the access to
  // the predictor. It holds no rule of the specification: those are in the predictor and the
  // expectations it returns. The stimulus runs one access at a time, so the order of completion
  // is the order the DUT served them in.
  class tagctrl_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(tagctrl_scoreboard)

    // Set by the env before build_phase
    tagctrl_env_cfg cfg;

    uvm_analysis_imp_cfg #(axi_mon_item, tagctrl_scoreboard) cfg_imp;
    uvm_analysis_imp_tag #(axi_mon_item, tagctrl_scoreboard) tag_imp;

    // Reset of the DUT, from the tagged subordinate's reset monitor
    uvm_analysis_imp #(axi_reset_item, tagctrl_scoreboard) reset_imp;

    tagctrl_predictor m_predictor;

    // Read bytes compared, chunks whose tag was required clear, and chunks whose tag was required
    // set
    int unsigned n_bytes_checked;
    int unsigned n_tags_checked;
    int unsigned n_set_tags_checked;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (cfg == null) `uvm_fatal(get_full_name(), "cfg is null")
      cfg_imp     = new("cfg_imp", this);
      tag_imp     = new("tag_imp", this);
      reset_imp   = new("reset_imp", this);
      m_predictor = tagctrl_predictor::type_id::create("m_predictor");
    endfunction

    function void write(axi_reset_item item);
      if (item.m_in_reset) m_predictor.reset();
    endfunction

    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (cfg.check_zeroing_seen && m_predictor.started_without_zeroing()) begin
        mismatch("cfg", "Status never showed Zeroing after start");
      end
      // A test that requires set tags must not pass without having checked one
      if (n_set_tags_checked < cfg.min_set_tags_checked) begin
        mismatch("tag", $sformatf("%0d set tags checked, the test requires %0d",
                                  n_set_tags_checked, cfg.min_set_tags_checked));
      end
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info(get_full_name(), $sformatf("Checked %0d read bytes, %0d clear tags, %0d set tags",
                                           n_bytes_checked, n_tags_checked, n_set_tags_checked),
                UVM_LOW)
    endfunction

    local function void mismatch(string id, string msg);
      if (cfg.en_scb) `uvm_error(id, msg)
    endfunction

    local function void compare(string id, tagctrl_exp exp, axi_mon_item item);
      string errors[$];
      exp.compare(item, errors);
      foreach (errors[i]) mismatch(id, errors[i]);
      n_bytes_checked    += exp.n_bytes_checked;
      n_tags_checked     += exp.n_clear_tags_checked;
      n_set_tags_checked += exp.n_set_tags_checked;
    endfunction

    function void write_cfg(axi_mon_item item);
      compare("cfg", m_predictor.expect_cfg(item), item);
      m_predictor.observe_cfg(item);
    endfunction

    function void write_tag(axi_mon_item item);
      axi_mon_write_item wr;
      axi_mon_read_item  rd;
      string             users = "";

      if ($cast(wr, item)) begin
        foreach (wr.m_wuser[n]) users = {users, $sformatf("%0b", wr.m_wuser[n][0])};
        `uvm_info("tag", $sformatf("write 0x%0h, WUSER per beat %s", wr.m_awaddr, users), UVM_HIGH)
      end else begin
        void'($cast(rd, item));
        foreach (rd.m_ruser[n]) users = {users, $sformatf("%0b", rd.m_ruser[n][0])};
        `uvm_info("tag", $sformatf("read 0x%0h, RUSER per beat %s", rd.m_araddr, users), UVM_HIGH)
      end

      compare("tag", m_predictor.expect_tag(item), item);
      m_predictor.observe_tag(item);
    endfunction
  endclass
