// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module axi_sram #(
  parameter int              AddrWidth   = 14,
  parameter longint unsigned SramMask    = 64'h0001_FFFF,
  parameter                  MemInitFile = ""
) (
  // Clock and reset.
  input  logic clk_i,
  input  logic rst_ni,

  // Capability AXI interface
  input  top_pkg::axi_dev_req_t  axi_req_i,
  output top_pkg::axi_dev_resp_t axi_resp_o
);

  // Every tag entry can store AxiDataWidth capability tags
  localparam int unsigned TagBitAddrWidth = AddrWidth -
                                            $clog2(top_pkg::CapSizeBits / top_pkg::AxiDataWidth);
  localparam int unsigned TagAddrWidth    = TagBitAddrWidth - $clog2(top_pkg::AxiDataWidth);
  localparam int unsigned TagBitWidth     = $clog2(top_pkg::AxiDataWidth);

  // 64-bit memory format signals
  logic                                 sram_req;
  logic                                 sram_we_d, sram_we_q;
  logic [(top_pkg::AxiDataWidth/8)-1:0] sram_be;
  logic [    top_pkg::AxiAddrWidth-1:0] sram_addr;
  logic [    top_pkg::AxiDataWidth-1:0] sram_wdata;
  logic                                 sram_rvalid;
  logic [    top_pkg::AxiDataWidth-1:0] sram_rdata;
  logic [                AddrWidth-1:0] sram_word_addr;
  logic [    top_pkg::AxiDataWidth-1:0] sram_wmask;
  logic [          TagBitAddrWidth-1:0] sram_tag_bit_addr;
  logic [             TagAddrWidth-1:0] sram_tag_word_addr;
  logic [              TagBitWidth-1:0] sram_tag_bit_select_d, sram_tag_bit_select_q;
  logic [    top_pkg::AxiDataWidth-1:0] sram_tag_wmask;
  logic [    top_pkg::AxiDataWidth-1:0] sram_tag_wdata;
  logic [    top_pkg::AxiDataWidth-1:0] sram_tag_rdata;
  logic                                 sram_cheri_w_tag;
  logic                                 sram_cheri_r_tag;

  // Initialisation signals and registers
  logic                    init_ctr_load;
  logic                    init_req_d;
  logic [TagAddrWidth-1:0] init_addr_q;
  logic                    tag_init_done_d;

  // Multiplexed tag memory request signals, with both initialisation requests and normal requests
  logic                             sram_tag_muxed_req;
  logic                             sram_tag_muxed_we;
  logic [TagAddrWidth-1:0]          sram_tag_muxed_word_addr;
  logic [top_pkg::AxiDataWidth-1:0] sram_tag_muxed_wdata;
  logic [top_pkg::AxiDataWidth-1:0] sram_tag_muxed_wmask;

  // AXI to 64-bit mem for SRAM
  axi_to_detailed_mem #(
    .axi_req_t  ( top_pkg::axi_dev_req_t  ),
    .axi_resp_t ( top_pkg::axi_dev_resp_t ),
    .AddrWidth  ( top_pkg::AxiAddrWidth   ),
    .DataWidth  ( top_pkg::AxiDataWidth   ),
    .IdWidth    ( top_pkg::AxiDevIdWidth  ),
    .NumBanks   ( 1                       )
  ) u_axi_to_detailed_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (axi_req_i),
    .axi_resp_o (axi_resp_o),

    // Memory interface.
    .mem_req_o       (sram_req),
    .mem_gnt_i       (tag_init_done_d),
    .mem_addr_o      (sram_addr),
    .mem_wdata_o     (sram_wdata),
    .mem_strb_o      (sram_be),
    .mem_atop_o      ( ),
    .mem_lock_o      ( ),
    .mem_id_o        ( ),
    .mem_user_o      ( ),
    .mem_cache_o     ( ),
    .mem_prot_o      ( ),
    .mem_qos_o       ( ),
    .mem_region_o    ( ),
    .mem_err_i       ('0),
    .mem_exokay_i    ('0),
    .mem_we_o        (sram_we_d),
    .mem_cheri_tag_o (sram_cheri_w_tag),
    .mem_rvalid_i    (sram_rvalid),
    // When write is enabled the block requires a read valid response.
    // In this case feed dummy data since otherwise rdata_i is undefined.
    .mem_rdata_i     ((sram_rvalid & sram_we_q) ? 64'hFEED_CAFE_8BAD_F00D : sram_rdata),
    .mem_cheri_tag_i ((sram_rvalid & sram_we_q) ? 1'b0 : sram_cheri_r_tag)
  );

  // Tag bit address calculation
  assign sram_tag_bit_addr     = TagBitAddrWidth'((sram_addr & SramMask) >>
                                 $clog2(top_pkg::CapSizeBits / 8));
  assign sram_tag_word_addr    = TagAddrWidth'(sram_tag_bit_addr >>
                                 $clog2(top_pkg::AxiDataWidth));
  assign sram_tag_bit_select_d = sram_tag_bit_addr[$clog2(top_pkg::AxiDataWidth)-1:0];

  // Shift tag bit to proper position within SRAM word
  assign sram_tag_wmask   = 1'b1 << sram_tag_bit_select_d;
  assign sram_tag_wdata   = { {top_pkg::AxiDataWidth-1{1'b0}}, sram_cheri_w_tag } <<
                               sram_tag_bit_select_d;
  assign sram_cheri_r_tag = sram_tag_rdata[sram_tag_bit_select_q];

  // Tag initialisation logic
  // Encoding generated with:
  // $ ./hw/vendor/lowrisc_ip/util/design/sparse-fsm-encode.py --language=sv \
  //     --seed 2839571378 --distance 3 --states 3 --bits 5
  //
  // Hamming distance histogram:
  //
  //  0: --
  //  1: --
  //  2: --
  //  3: |||||||||||||||||||| (66.67%)
  //  4: |||||||||| (33.33%)
  //  5: --
  //
  // Minimum Hamming distance: 3
  // Maximum Hamming distance: 4
  // Minimum Hamming weight: 1
  // Maximum Hamming weight: 4
  //
  localparam int InitStateWidth = 5;
  typedef enum logic [InitStateWidth-1:0] {
    LoadCtrSt  = 5'b11101,
    InitTagSt  = 5'b00001,
    InitDoneSt = 5'b10010
  } init_state_e;

  init_state_e init_state_d, init_state_q;

  always_comb begin : p_init_fsm
    // Defaults
    init_state_d    = init_state_q;
    tag_init_done_d = 1'b0;
    init_ctr_load   = 1'b0;

    unique case (init_state_q)
      // Initialise counter
      LoadCtrSt: begin
        init_ctr_load = 1'b1;
        init_state_d  = InitTagSt;
      end
      // Initialise tags
      InitTagSt: begin
        if (init_addr_q == '1) begin
          // Initialisation is done
          init_state_d = InitDoneSt;
        end
      end
      // Initialisation done
      InitDoneSt: begin
        // Release normal access logic
        tag_init_done_d = 1'b1;
      end
      // Invalid FSM states
      default: begin
        // Re-initialise all tags
        init_state_d = LoadCtrSt;
      end
    endcase
  end

  // Initialisation counter
  prim_count #(
    .Width                 ( TagAddrWidth ),
    // The AXI SRAM does not have an alert output,
    // therefore cannot trigger an alert on a prim_count error
    .EnableAlertTriggerSVA ( 0            )
  ) u_init_counter (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    .clr_i              (1'b0),
    .set_i              (init_ctr_load),
    .set_cnt_i          ('0),
    .incr_en_i          (1'b1),
    .decr_en_i          (1'b0),
    .step_i             (TagAddrWidth'(1)),
    .commit_i           (1'b1),
    .cnt_o              (init_addr_q),
    .cnt_after_commit_o ( ),
    .err_o              ( )
  );

  // Initialisation state register
  prim_sparse_fsm_flop #(
    .StateEnumT            ( init_state_e        ),
    .Width                 ( $bits(init_state_e) ),
    .ResetValue            ( LoadCtrSt           ),
    // The AXI SRAM does not have an alert output,
    // therefore cannot trigger an alert on a prim_sparse_fsm_flop error
    .EnableAlertTriggerSVA ( 0                   )
  ) u_state_regs (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .state_i (init_state_d),
    .state_o (init_state_q)
  );

  // Initialisation requests active only in InitTagSt
  assign init_req_d = (init_state_q == InitTagSt);

  // Tag RAM request multiplexing
  assign sram_tag_muxed_req       = tag_init_done_d ? sram_req           : init_req_d;
  assign sram_tag_muxed_we        = tag_init_done_d ? sram_we_d          : 1'b1;
  assign sram_tag_muxed_word_addr = tag_init_done_d ? sram_tag_word_addr : init_addr_q;
  assign sram_tag_muxed_wdata     = tag_init_done_d ? sram_tag_wdata     : '0;
  assign sram_tag_muxed_wmask     = tag_init_done_d ? sram_tag_wmask     : '1;

  // Tag RAM
  prim_ram_1p #(
    .Width           ( top_pkg::AxiDataWidth ),
    .DataBitsPerMask ( 1                     ),
    .Depth           ( 2 ** TagAddrWidth     )
  ) u_tag_ram (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .req_i   (sram_tag_muxed_req),
    .write_i (sram_tag_muxed_we),
    .addr_i  (sram_tag_muxed_word_addr),
    .wdata_i (sram_tag_muxed_wdata),
    .wmask_i (sram_tag_muxed_wmask),
    .rdata_o (sram_tag_rdata),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Remove base offset and convert byte address to 64-bit word address
  assign sram_word_addr = AddrWidth'((sram_addr & SramMask) >> $clog2(top_pkg::AxiDataWidth / 8));
  always_comb begin
    for (int i = 0; i < (top_pkg::AxiDataWidth / 8); ++i) begin
      sram_wmask[i*8 +: 8] = {8{sram_be[i]}};
    end
  end

  // Our RAM
  prim_ram_1p #(
    .Width           ( top_pkg::AxiDataWidth ),
    .DataBitsPerMask ( 8                     ),
    .Depth           ( 2 ** AddrWidth        ),
    .MemInitFile     ( MemInitFile           )
  ) u_ram (
    .clk_i  ( clk_i  ),
    .rst_ni ( rst_ni ),

    .req_i   (sram_req & tag_init_done_d),
    .write_i (sram_we_d),
    .addr_i  (sram_word_addr),
    .wdata_i (sram_wdata),
    .wmask_i (sram_wmask),
    .rdata_o (sram_rdata),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Single-cycle read response.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sram_rvalid           <= 1'b0;
      sram_we_q             <= 1'b0;
      sram_tag_bit_select_q <= '0;
    end else begin
      sram_rvalid           <= sram_req & tag_init_done_d; // Generate rvalid strobes even for writes
      sram_we_q             <= sram_we_d;
      sram_tag_bit_select_q <= sram_tag_bit_select_d;
    end
  end

  // The tag memory must hold one bit for every capability-sized region of the data memory.
  `ASSERT_INIT(TagRamCoversDataRam_A,
               (2 ** TagAddrWidth) * top_pkg::AxiDataWidth * top_pkg::CapSizeBits ==
               (2 ** AddrWidth) * top_pkg::AxiDataWidth)

  // The data memory must be exactly the size the address map reserves for it. The addresses are
  // masked with SramMask, so a parameter that disagrees with the map would silently wrap.
  `ASSERT_INIT(SramSizeMatchesMap_A,
               2 ** AddrWidth ==
               (SramMask + 1) / (top_pkg::AxiDataWidth / 8))

  // The read data and tag are deliberately omitted, since access to uninitialized memory reads X
  `ASSERT_KNOWN(AwReadyKnownO_A, axi_resp_o.aw_ready)
  `ASSERT_KNOWN(ArReadyKnownO_A, axi_resp_o.ar_ready)
  `ASSERT_KNOWN(WReadyKnownO_A, axi_resp_o.w_ready)
  `ASSERT_KNOWN(BValidKnownO_A, axi_resp_o.b_valid)
  `ASSERT_KNOWN(RValidKnownO_A, axi_resp_o.r_valid)
  `ASSERT_KNOWN_IF(BKnownO_A, axi_resp_o.b, axi_resp_o.b_valid)
  `ASSERT_KNOWN_IF(RIdKnownO_A, axi_resp_o.r.id, axi_resp_o.r_valid)
  `ASSERT_KNOWN_IF(RRespKnownO_A, axi_resp_o.r.resp, axi_resp_o.r_valid)
  `ASSERT_KNOWN_IF(RLastKnownO_A, axi_resp_o.r.last, axi_resp_o.r_valid)

endmodule
