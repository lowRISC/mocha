// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Reach one register in every xbar_peri device from the AXI driver that replaces CVA6
//
// Each access goes through the chip register model, so it takes the CVA6 path through the AXI
// crossbar, the AXI to TL-UL bridge and xbar_peri. Together the accesses confirm that the addresses
// of each device reach that device's instance in top_chip_system.
//
// For a register with a plain RW field, read the reset value, write its complement, read the
// register through its backdoor, which is rooted at the device's instance, and read it back. Then
// write the reset value back and read it once more, so the read back is checked with two values
// that differ in every writable bit, and the device is left as the reset left it. Every read is
// compared against the register model. The backdoor read fails a write that landed in another
// device even when that device has a register of the same shape at the same offset, which the
// frontdoor reads alone would not notice. A register whose fields are all read only is read
// through both paths instead, and the two reads must agree on a non-zero value.
//
// There is no CPU, so the test ends when body() does. Needs the axi_driver_to_cva6_bridge build
// mode.
class top_chip_dv_tl_xbar_smoke_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_tl_xbar_smoke_vseq)

  // The register accessed in each xbar_peri device, keyed by the device's register block. Both are
  // handles, so naming a register that does not exist fails at compile time.
  local uvm_reg targets[uvm_reg_block];

  // Target registers that the test writes although csr_excl excludes them, with the reason
  local string excl_waivers[uvm_reg];

  // Tallies for the end of test report, counting only the devices whose checks all passed
  local int unsigned num_read_written;
  local int unsigned num_read_only;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Wait for rom_ctrl's boot-time check to fill DIGEST, which the read-only check of rom_ctrl
  // needs. The AXI driver's reset is released before the check ends.
  extern local task wait_rom_check_done();

  // Fill in targets, one register per xbar_peri device
  //
  // The register is intr_enable wherever a device has interrupts, being plain RW with a zero reset.
  // Elsewhere it is a plain RW register that csr_excl rules out neither for writes nor for the
  // reset value check, and that the hardware leaves alone while the test runs. clkmgr's is
  // JITTER_ENABLE, whose write exclusion guards against random values. The test only writes the
  // MuBi True and False encodings, so the exclusion is waived in excl_waivers. rom_ctrl has no
  // such register, so its DIGEST_0 is read instead, which is non-zero once the boot-time check has
  // finished.
  //
  // prio and digest are register arrays, so their handles are indexed even though the registers
  // are named PRIO_0 and DIGEST_0.
  extern local function void build_targets();

  // Check that targets, the chip register model and xbar_peri name the same set of devices
  //
  // Report a uvm_error for each block of the model that has no target, for each target that is not
  // a block of the model, and when the model has a different number of blocks from the number of
  // devices that tl_peri_pkg gives xbar_peri. Any of these fails the test, in whichever direction
  // the table, the model or the crossbar has drifted.
  //
  //    blks: The direct children of the chip register model
  extern local function void check_targets_match_ral(const ref uvm_reg_block blks[$]);

  // Access csr and check that the access reached the instance that owns blk
  //
  // Report a uvm_error and count nothing if csr does not belong to blk, if it has writable fields
  // but none of them plain RW, or if csr_excl rules it out and excl_waivers does not waive that.
  //
  //    blk: The register block of one xbar_peri device
  //    csr: The register of blk that targets names
  extern local task check_block(uvm_reg_block blk, uvm_reg csr);

  // Return whether csr_excl rules out writing csr or checking its reset value
  //
  // A field-level exclusion counts too: csr_excl_item::is_excl() on a register does not look at
  // its fields.
  extern local function bit is_excluded(uvm_reg csr);

  // Read csr through the bus or its backdoor and compare it with the register model's mirror
  //
  //    csr:      The register to read
  //    backdoor: Read the device's instance through the backdoor instead of the bus
  //    step:     Which read this is, for the error message
  //    ok:       Set when the value matches the mirror
  extern local task read_and_compare(uvm_reg csr, bit backdoor, string step, output bit ok);

  // Log the tallies and fail a run in which fewer devices passed than targets names
  extern local function void report_targets();
endclass : top_chip_dv_tl_xbar_smoke_vseq


function top_chip_dv_tl_xbar_smoke_vseq::new(string name = "");
  super.new(name);
  do_wait_for_sw_test_done = 1'b0;
endfunction : new

task top_chip_dv_tl_xbar_smoke_vseq::body();
  uvm_reg_block blks[$];

  super.body();
  `DV_CHECK_NE_FATAL(p_sequencer.cva6_axi_sqr, null,
                     "Needs the axi_driver_to_cva6_bridge build mode")
  // The driver's reset (the chip's main reset) deasserts well after the top-level reset
  `DV_WAIT(p_sequencer.cva6_axi_sqr.m_vif.u_clk_rst_if.rst_n === 1'b1,
           "CVA6 AXI driver reset never deasserted")
  wait_rom_check_done();

  build_targets();
  // Direct children only: these are the per-device register blocks, and UVM_HIER would also return
  // any sub-block inside a device
  cfg.ral.get_blocks(blks, UVM_NO_HIER);
  `uvm_info(`gfn, $sformatf("Reaching %0d xbar_peri devices", blks.size()), UVM_LOW)
  check_targets_match_ral(blks);

  foreach (blks[i]) begin
    // A block with no target has already been reported by check_targets_match_ral
    if (targets.exists(blks[i])) begin
      check_block(blks[i], targets[blks[i]]);
    end
  end

  report_targets();
endtask : body

task top_chip_dv_tl_xbar_smoke_vseq::wait_rom_check_done();
  `uvm_info(`gfn, "Waiting for the rom_ctrl check to finish", UVM_MEDIUM)
  csr_spinwait(.ptr(cfg.ral.rom_ctrl_regs.digest[0]), .exp_data(0), .compare_op(CompareOpNe),
               .backdoor(1'b1), .spinwait_delay_ns(1000));
endtask : wait_rom_check_done

function void top_chip_dv_tl_xbar_smoke_vseq::build_targets();
  targets[cfg.ral.clkmgr]        = cfg.ral.clkmgr.jitter_enable;
  targets[cfg.ral.entropy_src]   = cfg.ral.entropy_src.intr_enable;
  targets[cfg.ral.gpio]          = cfg.ral.gpio.intr_enable;
  targets[cfg.ral.i2c]           = cfg.ral.i2c.intr_enable;
  targets[cfg.ral.pwrmgr]        = cfg.ral.pwrmgr.intr_enable;
  targets[cfg.ral.rom_ctrl_regs] = cfg.ral.rom_ctrl_regs.digest[0];
  targets[cfg.ral.rstmgr]        = cfg.ral.rstmgr.alert_info_ctrl;
  targets[cfg.ral.rv_plic]       = cfg.ral.rv_plic.prio[0];
  targets[cfg.ral.rv_timer]      = cfg.ral.rv_timer.cfg0;
  targets[cfg.ral.spi_device]    = cfg.ral.spi_device.intr_enable;
  targets[cfg.ral.spi_host]      = cfg.ral.spi_host.intr_enable;
  targets[cfg.ral.uart]          = cfg.ral.uart.intr_enable;

  excl_waivers[cfg.ral.clkmgr.jitter_enable] =
      "the test only writes MuBi True then False, the exclusion guards against random values";
endfunction : build_targets

function void
  top_chip_dv_tl_xbar_smoke_vseq::check_targets_match_ral(const ref uvm_reg_block blks[$]);
  // The blocks in blks. This associative array is used as a set: only the keys matter.
  bit in_ral[uvm_reg_block];

  foreach (blks[i]) begin
    in_ral[blks[i]] = 1'b1;
    if (!targets.exists(blks[i])) begin
      `uvm_error(`gfn, $sformatf("%0s is in the chip register model but has no target register",
                                 blks[i].get_name()))
    end
  end

  foreach (targets[blk]) begin
    if (!in_ral.exists(blk)) begin
      `uvm_error(`gfn, $sformatf("%0s has a target register but is not a block of the chip model",
                                 blk.get_name()))
    end
  end

  if (blks.size() != tl_peri_pkg::N_DEVICE) begin
    `uvm_error(`gfn,
               $sformatf("The chip register model has %0d blocks but xbar_peri has %0d devices",
                         blks.size(), tl_peri_pkg::N_DEVICE))
  end
endfunction : check_targets_match_ral

task top_chip_dv_tl_xbar_smoke_vseq::check_block(uvm_reg_block blk, uvm_reg csr);
  uvm_reg_field  flds[$];
  uvm_reg_data_t complement_val;
  bit            has_rw = 1'b0;
  bit            all_ro = 1'b1;
  bit            ok;

  if (csr.get_parent() != blk) begin
    `uvm_error(`gfn, $sformatf("The target register of %0s is %0s, which belongs to another block",
                               blk.get_name(), csr.get_full_name()))
    return;
  end

  // Writability comes from the register model. A register with a plain RW field is written. A
  // register whose fields are all read only can only be read. Anything else, such as a register
  // whose only writable fields are W1C or RW0C, cannot be checked either way.
  csr.get_fields(flds);
  foreach (flds[i]) begin
    if (flds[i].get_access() == "RW") begin
      has_rw = 1'b1;
    end
    if (flds[i].get_access() != "RO") begin
      all_ro = 1'b0;
    end
  end

  `uvm_info(`gfn, $sformatf("Reaching %0s through %0s at 0x%0h", blk.get_name(), csr.get_name(),
                            csr.get_address()), UVM_MEDIUM)

  if (all_ro) begin
    uvm_reg_data_t frontdoor_val;
    uvm_reg_data_t backdoor_val;

    csr_rd(.ptr(csr), .value(frontdoor_val));
    csr_rd(.ptr(csr), .value(backdoor_val), .backdoor(1'b1));
    if (backdoor_val == '0) begin
      `uvm_error(`gfn, $sformatf({"%0s holds zero, so reading it cannot tell this device from ",
                                  "another whose register at the same offset is zero"},
                                 csr.get_full_name()))
      return;
    end
    if (frontdoor_val != backdoor_val) begin
      `uvm_error(`gfn, $sformatf("%0s read 0x%0h through the bus but its instance holds 0x%0h",
                                 csr.get_full_name(), frontdoor_val, backdoor_val))
      return;
    end
    num_read_only++;
    `uvm_info(`gfn, $sformatf("%0s reached through %0s at 0x%0h, read 0x%0h, nothing writable",
                              blk.get_name(), csr.get_name(), csr.get_address(), frontdoor_val),
              UVM_LOW)
    return;
  end

  if (!has_rw) begin
    `uvm_error(`gfn, $sformatf("%0s has writable fields but none plain RW, name another register",
                               csr.get_full_name()))
    return;
  end
  if (is_excluded(csr)) begin
    if (!excl_waivers.exists(csr)) begin
      `uvm_error(`gfn, $sformatf("%0s is excluded by csr_excl, name another register",
                                 csr.get_full_name()))
      return;
    end
    `uvm_info(`gfn, $sformatf("%0s is excluded by csr_excl but written anyway: %0s",
                              csr.get_full_name(), excl_waivers[csr]), UVM_MEDIUM)
  end

  // The mirror still holds the reset values
  read_and_compare(csr, 1'b0, "initial read, before any write", ok);
  if (!ok) begin
    return;
  end

  // Write the complement of the reset value, so a matching read proves that the write landed. This
  // is safe for MuBi fields too, whose True and False encodings are bitwise complements. Predicting
  // through the register model applies each field's access policy, so read-only fields in the
  // register do not break the comparisons.
  csr_wr(.ptr(csr), .value(~csr.get_reset()), .predict(1'b1));
  read_and_compare(csr, 1'b1, "backdoor read of the instance after the write", ok);
  if (!ok) begin
    return;
  end
  read_and_compare(csr, 1'b0, "read back after the write", ok);
  if (!ok) begin
    return;
  end
  complement_val = csr.get_mirrored_value();

  csr_wr(.ptr(csr), .value(csr.get_reset()), .predict(1'b1));
  read_and_compare(csr, 1'b0, "read back after writing the reset value back", ok);
  if (!ok) begin
    return;
  end

  num_read_written++;
  `uvm_info(`gfn,
            $sformatf("%0s reached through %0s at 0x%0h, wrote and read back 0x%0h, then 0x%0h",
                      blk.get_name(), csr.get_name(), csr.get_address(), complement_val,
                      csr.get_mirrored_value()),
            UVM_LOW)
endtask : check_block

function bit top_chip_dv_tl_xbar_smoke_vseq::is_excluded(uvm_reg csr);
  csr_excl_item excl = get_excl_item(csr);

  if (excl == null) begin
    return 1'b0;
  end
  return excl.is_excl(csr, CsrExclWrite, CsrRwTest) ||
         excl.is_excl(csr, CsrExclInitCheck, CsrHwResetTest) ||
         get_mask_excl_fields(csr, CsrExclWrite, CsrRwTest, excl) != '1 ||
         get_mask_excl_fields(csr, CsrExclInitCheck, CsrHwResetTest, excl) != '1;
endfunction : is_excluded

task top_chip_dv_tl_xbar_smoke_vseq::read_and_compare(uvm_reg     csr,
                                                      bit         backdoor,
                                                      string      step,
                                                      output bit  ok);
  uvm_reg_data_t obs;
  uvm_reg_data_t exp = csr.get_mirrored_value();

  csr_rd(.ptr(csr), .value(obs), .backdoor(backdoor));
  ok = (obs == exp);
  if (!ok) begin
    `uvm_error(`gfn, $sformatf("%0s: %0s read 0x%0h, expected 0x%0h", csr.get_full_name(), step,
                               obs, exp))
  end
endtask : read_and_compare

function void top_chip_dv_tl_xbar_smoke_vseq::report_targets();
  `uvm_info(`gfn,
            $sformatf("%0d of %0d xbar_peri devices passed: %0d read and written, %0d read only",
                      num_read_written + num_read_only, targets.size(), num_read_written,
                      num_read_only),
            UVM_LOW)

  if (num_read_written + num_read_only != targets.size()) begin
    `uvm_error(`gfn, $sformatf("%0d of the %0d devices that have a target register passed",
                               num_read_written + num_read_only, targets.size()))
  end
endfunction : report_targets
