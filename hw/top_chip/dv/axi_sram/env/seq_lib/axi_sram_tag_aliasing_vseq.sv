// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // tag_aliasing -- every 16-byte region must own its tag bit. The tag address is
  // derived from the 64-bit word address, so a stride that only differs in the
  // bits above the tag address width must not share a tag bit. Both directions
  // are checked: a store must not forge a tag at the aliased slot, and a store at
  // the aliased slot must not destroy a genuine tag. Several slot pairs spread
  // over the 128 KiB are tried, each with the capability on either side.
  class axi_sram_tag_aliasing_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_tag_aliasing_vseq)

    function new(string name = "axi_sram_tag_aliasing_vseq");
      super.new(name);
    endfunction

    // 1024 tag bits x 16 bytes per region = the stride a truncated tag address
    // would alias over.
    localparam bit [63:0] Stride = 64'h0000_4000;

    // Hold a capability at cap_addr and plain data at plain_addr, a stride apart, and read
    // both slots' tags back.
    protected task automatic check_pair(bit [31:0] id, bit [63:0] cap_addr,
                                        bit [63:0] plain_addr);
      // Plain data first, then a genuine capability at the aliased slot. The plain slot must not
      // acquire a tag.
      write_cap(id, plain_addr, 64'hBAD0_BAD0_BAD0_BAD0, 64'hBAD1_BAD1_BAD1_BAD1, 1'b0);
      write_cap(id, cap_addr,   64'hC0DE_C0DE_C0DE_C0DE, 64'hC0DE_C0DE_C0DE_C0DE, 1'b1);
      read_cap(id, plain_addr);

      // The capability must survive a plain data write to the aliased slot.
      write_word(id, plain_addr, 64'hDEAD_DEAD_DEAD_DEAD);
      read_cap(id, cap_addr);
    endtask

    task body();
      // Spread over the address space; every base and base+Stride stays inside the 128 KiB.
      bit [63:0] bases[] = '{64'h0000_0000, 64'h0000_6000, 64'h0000_C000, 64'h0001_2000};
      await_reset();
      foreach (bases[i]) begin
        check_pair(32'd21, bases[i], bases[i] + Stride);   // capability at the lower slot
        check_pair(32'd21, bases[i] + Stride, bases[i]);   // and with the slots swapped
      end
    endtask
  endclass
