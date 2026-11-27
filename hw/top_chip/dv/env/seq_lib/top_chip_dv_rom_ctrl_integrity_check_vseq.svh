// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check that a ROM whose contents do not match its digest never lets CVA6 fetch from it
//
// Before the reset is released, flip one data bit of one word of the ROM through the backdoor and
// give the word the ECC of its new data, so that only the digest can tell. rom_ctrl must then
// report its check done but not good, and pwrmgr must keep fetch_en Off. While fetch_en is Off,
// u_rom_isolate stalls CVA6's first fetch from the ROM, so no AXI transaction completes in the
// whole test, which the AXI scoreboard checks at the end.
//
// There is no software image, so the test ends when body() does.
class top_chip_dv_rom_ctrl_integrity_check_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_rom_ctrl_integrity_check_vseq)

  // System clock cycles for which fetch_en must stay Off once rom_ctrl reports the check done
  //
  // With a good ROM, pwrmgr sets fetch_en On 6 cycles after done. The window is far longer, so that
  // a CPU let through to the ROM in spite of fetch_en has time to complete the transactions that
  // the AXI scoreboard then reports.
  localparam int unsigned FetchEnOffCycles = 1_000;

  // Logical word of the ROM to corrupt. A word holding part of the expected digest is as good as a
  // word the digest covers, since either makes the two digests differ.
  rand int unsigned rom_word_idx;
  // Data bit of that word to flip
  rand int unsigned rom_bit_idx;

  constraint rom_word_idx_c {
    rom_word_idx < top_pkg::RomCtrlMemLength / 4;
  }
  constraint rom_bit_idx_c {
    rom_bit_idx < 32;
  }

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Methods extending base methods from top_chip_dv_base_vseq

  // Corrupt the ROM before the reset, so that the check rom_ctrl starts on reset release reads the
  // corrupted contents
  extern task dut_init(string reset_kind = "HARD");

  // Class specific methods

  // Flip data bit rom_bit_idx of ROM word rom_word_idx and write the word back with the ECC of its
  // new data
  extern local function void corrupt_rom();
endclass : top_chip_dv_rom_ctrl_integrity_check_vseq


function top_chip_dv_rom_ctrl_integrity_check_vseq::new(string name = "");
  super.new(name);
  do_wait_for_sw_test_done = 1'b0;
endfunction : new

task top_chip_dv_rom_ctrl_integrity_check_vseq::body();
  super.body();
  cfg.exp_axi_traffic = 1'b0;

  `DV_WAIT(prim_mubi_pkg::mubi4_test_true_strict(cfg.rom_check_vif.pwrmgr_data_i.done),
           "rom_ctrl never reported the ROM check done")
  // When the last digest word is the one that differs, good falls on the clock edge on which done
  // rises, so a read in the same time step can still see the old value
  cfg.sys_clk_vif.wait_clks(1);
  `DV_CHECK(prim_mubi_pkg::mubi4_test_false_strict(cfg.rom_check_vif.pwrmgr_data_i.good),
            $sformatf("rom_ctrl reported the corrupted ROM as good (good = 0x%0h)",
                      cfg.rom_check_vif.pwrmgr_data_i.good))
  `DV_CHECK_EQ(cfg.rom_check_vif.fetch_en_i, lc_ctrl_pkg::Off,
               "pwrmgr enabled CVA6 fetches although the ROM check failed")

  `DV_SPINWAIT_EXIT(
      cfg.sys_clk_vif.wait_clks(FetchEnOffCycles);,
      @(cfg.rom_check_vif.fetch_en_i);
      `uvm_error(`gfn, $sformatf("pwrmgr set fetch_en to 0x%0h after a failed ROM check",
                                 cfg.rom_check_vif.fetch_en_i)))
endtask : body

task top_chip_dv_rom_ctrl_integrity_check_vseq::dut_init(string reset_kind = "HARD");
  corrupt_rom();
  super.dut_init(reset_kind);
endtask : dut_init

function void top_chip_dv_rom_ctrl_integrity_check_vseq::corrupt_rom();
  rom_ctrl_bkdr_util                 rom;
  bit [bus_params_pkg::BUS_AW-1:0]   addr = rom_word_idx * 4;
  bit [38:0]                         word;

  `downcast(rom, p_sequencer.mem_bkdr_util_h[ChipMemROM])
  word = rom.rom_encrypt_read32(addr, rom.m_key, rom.m_nonce, 1'b1);
  `uvm_info(`gfn,
            $sformatf("Flipping data bit %0d of ROM word %0d (offset 0x%0h), which holds 0x%08h",
                      rom_bit_idx, rom_word_idx, addr, word[31:0]),
            UVM_LOW)
  word[rom_bit_idx] = !word[rom_bit_idx];
  rom.rom_encrypt_write32_integ(addr, word, rom.m_key, rom.m_nonce, 1'b1);
endfunction : corrupt_rom
