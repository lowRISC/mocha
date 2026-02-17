// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module axi_frame_buffer #(
  parameter      LogoRomInitFile     = "" // VMEM file to initialize the logo ROM with
) (
  // Clock and reset.
  input  logic clk_axi_i,
  input  logic clk_pix_i,
  input  logic rst_ni,

  // AXI interface
  input  top_pkg::axi_req_t  axi_req_i,
  output top_pkg::axi_resp_t axi_resp_o,

  // Transmitter frame buffer access port
  input  logic        mem_en,
  input  logic [16:0] mem_addr,
  output logic [63:0] mem_data,

  // Transmitter logo ROM access port
  input  logic        logo_rom_en,
  input  logic [17:0] logo_rom_addr,
  output logic  [7:0] logo_rom_data
);
  // Local parameters.
  localparam int unsigned FRAME_BUFFER_WIDTH          = 512;
  localparam int unsigned FRAME_BUFFER_HEIGHT         = 1024;
  localparam int unsigned FRAME_BUFFER_BITS_PER_PIXEL = 16;
  localparam int unsigned FRAME_BUFFER_DEPTH          = FRAME_BUFFER_WIDTH * FRAME_BUFFER_HEIGHT / (top_pkg::AxiDataWidth / FRAME_BUFFER_BITS_PER_PIXEL);
  localparam int unsigned FRAME_BUFFER_ADDR_BITS      = $clog2(FRAME_BUFFER_DEPTH);
  localparam int unsigned LOGO_WIDTH       = 1024;
  localparam int unsigned LOGO_HEIGHT      = 765;
  localparam int unsigned LOGO_BITS_PER_PIXEL = 2;
  localparam int unsigned LOGO_ROM_DEPTH = (LOGO_WIDTH * LOGO_HEIGHT) / 4;

  // 64-bit memory format signals
  logic                                 axi_port_req;
  logic                                 axi_port_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] axi_port_be;
  logic [top_pkg::AxiAddrWidth-1:0]     axi_port_addr;
  logic [top_pkg::AxiDataWidth-1:0]     axi_port_wdata;
  logic                                 axi_port_rvalid;
  logic [top_pkg::AxiDataWidth-1:0]     axi_port_rdata;
  logic [FRAME_BUFFER_ADDR_BITS-1:0]                 axi_port_word_addr;
  logic [top_pkg::AxiDataWidth-1:0]     axi_port_wmask;

  // Address pipeline stage for large memories
  logic [16:0] mem_addr_pipe;
  logic [17:0] logo_rom_addr_pipe;

  // Data pipeline stage for large memories
  logic [63:0] mem_data_prepipe;
  logic  [7:0] logo_rom_data_prepipe;

  // AXI to 64-bit mem for frame buffer
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) u_frame_buffer_axi_to_mem (
    .clk_i  (clk_axi_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (axi_req_i),
    .axi_resp_o (axi_resp_o),

    // Memory interface.
    .mem_req_o    (axi_port_req),
    .mem_gnt_i    (1'b1),
    .mem_addr_o   (axi_port_addr),
    .mem_wdata_o  (axi_port_wdata),
    .mem_strb_o   (axi_port_be),
    .mem_atop_o   ( ),
    .mem_we_o     (axi_port_we),
    .mem_rvalid_i (axi_port_rvalid),
    .mem_rdata_i  (axi_port_rdata)
  );

  // Remove base offset and convert byte address to 64-bit word address
  assign axi_port_word_addr = FRAME_BUFFER_ADDR_BITS'((axi_port_addr & top_pkg::FrameBufferMask) >> $clog2(top_pkg::AxiDataWidth / 8));
  always_comb begin
    for (int i = 0; i < (top_pkg::AxiDataWidth / 8); ++i) begin
      axi_port_wmask[i*8 +: 8] = {8{axi_port_be[i]}};
    end
  end

  // Memory address and data pipeline
  always_ff @(posedge clk_pix_i) begin
    mem_addr_pipe      <= mem_addr;
    logo_rom_addr_pipe <= logo_rom_addr;
    mem_data      <= mem_data_prepipe;
    logo_rom_data <= logo_rom_data_prepipe;
  end

  // Frame buffer memory
  prim_ram_2p #(
    .Width           ( top_pkg::AxiDataWidth ),
    .DataBitsPerMask ( 8                     ),
    .Depth           ( FRAME_BUFFER_DEPTH    )
  ) u_frame_buffer_mem (
    .clk_a_i (clk_axi_i),
    .clk_b_i (clk_pix_i),

    .a_req_i   (axi_port_req),
    .a_write_i (axi_port_we),
    .a_addr_i  (axi_port_word_addr),
    .a_wdata_i (axi_port_wdata),
    .a_wmask_i (axi_port_wmask),
    .a_rdata_o (axi_port_rdata),

    .b_req_i   (mem_en),
    .b_write_i ('0),
    .b_addr_i  (mem_addr_pipe),
    .b_wdata_i ('0),
    .b_wmask_i ('0),
    .b_rdata_o (mem_data_prepipe),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Single-cycle read response.
  always_ff @(posedge clk_axi_i or negedge rst_ni) begin
    if (!rst_ni) axi_port_rvalid <= '0;
    else         axi_port_rvalid <= axi_port_req; // Generate rvalid strobes even for writes
  end

  // Logo ROM
  prim_ram_1p #(
    .Width           ( LOGO_BITS_PER_PIXEL * 4 ),
    .DataBitsPerMask ( 8                     ),
    .Depth           ( LOGO_ROM_DEPTH        ),
    .MemInitFile     ( LogoRomInitFile           )
  ) u_logo_rom (
    .clk_i  (clk_pix_i),
    .rst_ni (rst_ni),

    .req_i   (logo_rom_en),
    .write_i ('0),
    .addr_i  (logo_rom_addr_pipe),
    .wdata_i ('0),
    .wmask_i ('0),
    .rdata_o (logo_rom_data_prepipe),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

endmodule
