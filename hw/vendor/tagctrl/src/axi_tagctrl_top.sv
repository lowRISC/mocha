// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Bruno Sá <bruno.vilaca.sa@gmail.com>
// Date:   07.12.2023

/// [TODO] - Description goes here

module axi_tagctrl_top #(
    /// DRAM memory Base
    parameter int unsigned DRAMMemBase      = 64'd0,
    /// DRAM memory Length
    parameter int unsigned DRAMMemLength    = 64'd0,
    /// Capability size in memory
    parameter int unsigned CapSize          = 128,
    /// Tag Cache base address in memory. Location of the Tag Cache
    /// structure
    parameter int unsigned TagCacheMemBase  = 0,
    /// The set-associativity of the Tag Cache.
    ///
    /// This parameter determines how many ways/sets will be instantiated.
    ///
    /// Restrictions:
    /// * Minimum value: `32'd1`
    /// * Maximum value: `32'd63`
    /// The maximum value depends on the internal register width
    parameter int unsigned SetAssociativity = 32'd0,
    /// Number of cache lines per way.
    ///
    /// Restrictions:
    /// * Minimum value: `32'd2`
    /// * Has to be a power of two.
    ///
    /// Note on restrictions:
    /// The reason is that in the address, at least one bit has to be mapped onto a cache-line index.
    /// This is a limitation of the *system verilog* language, which requires at least one bit wide
    /// fields inside of a struct. Further this value has to be a power of 2. This has to do with the
    /// requirement that the address mapping from the address onto the cache-line index has to be
    /// continuous.
    parameter int unsigned NumLines         = 32'd0,
    /// Number of blocks (words) in a cache line.
    ///
    /// The width of a block is the same as the data width of the AXI4+ATOP ports. Defined with
    /// parameter `AxiCfg.DataWidthFull` in bits.
    ///
    /// Restrictions:
    /// * Minimum value: 32'd2
    /// * Has to be a power of two.
    ///
    /// Note on restrictions:
    /// The same restriction as of parameter `NumLines` applies.
    parameter int unsigned NumBlocks        = 32'd0,
    /// AXI4+ATOP ID field width of the slave port.
    /// The ID field width of the master port is this parameter + 1.
    parameter int unsigned AxiIdWidth       = 32'd6,
    /// AXI4+ATOP address field width of both the slave and master port.
    parameter int unsigned AxiAddrWidth     = 32'd64,
    /// AXI4+ATOP data field width of both the slave and the master port.
    parameter int unsigned AxiDataWidth     = 32'd64,
    /// AXI4+ATOP user field width of both the slave and the master port.
    parameter int unsigned AxiUserWidth     = 32'd1,
    /// Internal register width
    parameter int unsigned RegWidth         = 64,
    /// Register type for HW -> Register direction
    parameter type         conf_regs_d_t    = logic,
    /// Register type for Register -> HW direction
    parameter type         conf_regs_q_t    = logic,
    /// AXI4+ATOP request type on the slave port.
    /// Expected format can be defined using `AXI_TYPEDEF_REQ_T.
    parameter type         slv_req_t        = logic,
    /// AXI4+ATOP response type on the slave port.
    /// Expected format can be defined using `AXI_TYPEDEF_RESP_T.
    parameter type         slv_resp_t       = logic,
    /// AXI4+ATOP request type on the master port.
    /// Expected format can be defined using `AXI_TYPEDEF_REQ_T.
    parameter type         mst_req_t        = logic,
    /// AXI4+ATOP response type on the master port.
    /// Expected format can be defined using `AXI_TYPEDEF_RESP_T.
    parameter type         mst_resp_t       = logic,
    /// Full AXI4+ATOP Port address decoding rule
    parameter type         rule_full_t      = axi_pkg::xbar_rule_64_t,
    /// Whether to print SRAM configs
    parameter bit          PrintSramCfg     = 0,
    /// Whether to print config of LLC
    parameter bit          PrintLlcCfg      = 0,
    /// Dependent parameter, do **not** overwrite!
    /// Address type of the AXI4+ATOP ports.
    /// The address fields of the rule type have to be the same.
    parameter type         axi_addr_t       = logic                   [    AxiAddrWidth-1:0],
    /// Dependent parameter, do **not** overwrite!
    /// Data type of set associativity wide registers
    parameter type         way_ind_t        = logic                   [SetAssociativity-1:0]
) (
    /// Rising-edge clock of all ports.
    input logic clk_i,
    /// Asynchronous reset, active low
    input logic rst_ni,
    /// Test mode activate, active high.
    input logic test_i,
    /// AXI4+ATOP slave port request, CPU side
    input slv_req_t slv_req_i,
    /// AXI4+ATOP slave port response, CPU side
    output slv_resp_t slv_resp_o,
    /// AXI4+ATOP master port request, memory side
    output mst_req_t mst_req_o,
    /// AXI4+ATOP master port response, memory side
    input mst_resp_t mst_resp_i,
    /// Configuration registers Registers -> HW
    input conf_regs_q_t conf_regs_i,
    /// Configuration registers HW -> Registers
    output conf_regs_d_t conf_regs_o,
    /// Start of address region mapped to cache
    input axi_addr_t cached_start_addr_i,
    /// End of address region mapped to cache
    input axi_addr_t cached_end_addr_i
);
  `include "axi/typedef.svh"
  // Axi parameters are accumulated in a struct for further use.
  localparam axi_llc_pkg::llc_axi_cfg_t AxiCfg = axi_llc_pkg::llc_axi_cfg_t
'{SlvPortIdWidth: AxiIdWidth, AddrWidthFull: AxiAddrWidth, DataWidthFull: AxiDataWidth};

  typedef logic [AxiCfg.SlvPortIdWidth-1:0] axi_slv_id_t;
  typedef logic [AxiCfg.SlvPortIdWidth:0] axi_mst_id_t;
  typedef logic [AxiCfg.DataWidthFull-1:0] axi_data_t;
  typedef logic [(AxiCfg.DataWidthFull/8)-1:0] axi_strb_t;
  typedef logic [AxiUserWidth-1:0] axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_chan_t, axi_addr_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_AW_CHAN_T(mst_aw_chan_t, axi_addr_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(slv_b_chan_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(mst_b_chan_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_chan_t, axi_addr_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(mst_ar_chan_t, axi_addr_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(slv_r_chan_t, axi_data_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(mst_r_chan_t, axi_data_t, axi_mst_id_t, axi_user_t)

  // configuration struct that has all the cache parameters included for the submodules
  localparam axi_llc_pkg::llc_cfg_t LLC_Cfg = axi_llc_pkg::llc_cfg_t
'{

      SetAssociativity  : SetAssociativity,
      NumLines          : NumLines,
      NumBlocks         : NumBlocks,
      BlockSize         : AxiCfg.DataWidthFull,
      TagLength         :
      AxiCfg.AddrWidthFull
      - unsigned'(
      $clog2(NumLines)
      ) - unsigned'(
      $clog2(NumBlocks)
      ) - unsigned'(
      $clog2(AxiCfg.DataWidthFull / 32'd8)
      ),
      IndexLength       : unsigned'($clog2(NumLines)),
      BlockOffsetLength : unsigned'($clog2(NumBlocks)),
      ByteOffsetLength  : unsigned'($clog2(AxiCfg.DataWidthFull / 32'd8)),
      SPMLength         : SetAssociativity * NumLines * NumBlocks * (AxiCfg.DataWidthFull / 32'd8)
  };
  localparam axi_tagctrl_pkg::tagctrl_cfg_t Cfg = axi_tagctrl_pkg::tagctrl_cfg_t
'{
      AxiIdWidth: AxiIdWidth,
      AxiAddrWidth: AxiAddrWidth,
      AxiDataWidth: AxiDataWidth,
      CapSize: CapSize,
      DRAMMemBase: DRAMMemBase,
      DRAMMemLength : DRAMMemLength,
      TagCacheMemBase: TagCacheMemBase,
      TagWFifoDepth: 4,
      TagAXFifoDepth: 4,
      TagRFifoDepth: 8,
      tagc_cfg: LLC_Cfg
  };


  typedef struct packed {
    // AXI4+ATOP specific descriptor signals
    axi_slv_id_t a_x_id;  // AXI ID from slave port
    axi_addr_t a_x_addr;  // memory address
    axi_pkg::len_t a_x_len;  // AXI burst length
    axi_pkg::size_t a_x_size;  // AXI burst size
    axi_pkg::burst_t a_x_burst;  // AXI burst type
    logic a_x_lock;  // AXI lock signal
    axi_pkg::cache_t a_x_cache;  // AXI cache signal
    axi_pkg::prot_t a_x_prot;  // AXI protection signal
    axi_pkg::resp_t x_resp;  // AXI response signal, for error propagation
    logic x_last;  // Last descriptor of a burst
    // Cache specific descriptor signals
    logic spm;  // this descriptor targets a SPM region in the cache
    logic rw;  // this descriptor is a read:0 or write:1 access
    logic [Cfg.tagc_cfg.SetAssociativity-1:0] way_ind;  // way we have to perform an operation on
    logic evict;  // evict what is standing in the line
    logic [Cfg.tagc_cfg.TagLength -1:0] evict_tag;  // tag for evicting a line
    logic refill;  // refill the cache line
    logic flush;  // flush this line, comes from config
  } tagc_desc_t;

  // definition of the structs that are between the units and the ways
  typedef struct packed {
    axi_llc_pkg::cache_unit_e                  cache_unit;  // which unit does the access
    logic [Cfg.tagc_cfg.SetAssociativity -1:0] way_ind;     // to which way the access goes
    logic [Cfg.tagc_cfg.IndexLength      -1:0] line_addr;   // cache line address
    logic [Cfg.tagc_cfg.BlockOffsetLength-1:0] blk_offset;  // block offset
    logic                                      we;          // write enable
    axi_data_t                                 data;        // input data
    axi_strb_t                                 strb;        // write enable (equals AXI strb)
    axi_data_t                                 bit_en;      // write enable (equals AXI strb)
  } way_inp_t;

  typedef struct packed {
    axi_llc_pkg::cache_unit_e cache_unit;  // which unit had the access
    axi_data_t                data;        // read data from the way
  } way_oup_t;

  // definitions of the miss counting struct
  typedef struct packed {
    axi_slv_id_t id;     // AXI id of the count operation
    logic        rw;     // 0:read, 1:write
    logic        valid;  // valid, equals enable
  } cnt_t;

  // definition of the lock signals
  typedef struct packed {
    logic [Cfg.tagc_cfg.IndexLength-1:0]      index;    // index of lock (cache-line)
    logic [Cfg.tagc_cfg.SetAssociativity-1:0] way_ind;  // way which is locked
  } lock_t;

  // struct to pass between the tag controller and the tag cache
  typedef struct packed {
    axi_data_t data;    // input data
    axi_data_t bit_en;  // write bit enable
    axi_strb_t strb;    // write enable (equals AXI strb)
  } tagc_oup_t;

  typedef struct packed {
    axi_slv_id_t    id;    // AXI id of the count operation
    axi_data_t      data;  // read data from the way
    axi_pkg::resp_t resp;
    logic           last;
  } tagc_inp_t;

  typedef struct packed {
    // AXI4+ATOP specific descriptor signals
    axi_slv_id_t a_x_id;  // AXI ID from slave port
    axi_addr_t a_x_addr;  // memory address
    axi_pkg::len_t a_x_len;  // AXI burst length
    axi_pkg::size_t a_x_size;  // AXI burst size
    axi_pkg::burst_t a_x_burst;  // AXI burst type
    axi_pkg::resp_t x_resp;  // AXI response signal, for error propagation
    axi_pkg::len_t a_x_tag_len;  // Tag len request to the Tag Cache
    logic x_last;  // Last descriptor of a burst
    // Cache specific descriptor signals
    logic spm;  // this descriptor targets a SPM region in the cache
    logic rw;  // this descriptor is a read:0 or write:1 access
    logic [Cfg.tagc_cfg.SetAssociativity-1:0] way_ind;  // way we have to perform an operation on
    logic evict;  // evict what is standing in the line
    logic [Cfg.tagc_cfg.TagLength -1:0] evict_tag;  // tag for evicting a line
    logic refill;  // refill the cache line
    logic flush;  // flush this line, comes from config
  } tagctrl_desc_t;

  // R tag bits payload between the tag cache and tag controller
  tagc_inp_t tagc_r_inp;
  logic tagc_r_inp_valid, tagc_r_inp_ready;

  // W tag bits payload between the tag controller and tag cache
  tagc_oup_t tagc_w_oup;
  logic tagc_w_oup_valid, tagc_w_oup_ready;
  slv_b_chan_t tagc_b_chan;
  logic tagc_b_chan_valid, tagc_b_chan_ready;

  // tag controller and tag cache connection to the memory
  slv_req_t to_tagctrl_req, tagctrl_req, tagc_req;
  slv_resp_t from_tagctrl_resp, tagctrl_resp, tagc_resp;

  // signals between channel splitters and rw_arb_tree
  tagc_desc_t [2:0] ax_desc;
  logic       [2:0] ax_desc_valid;
  logic       [2:0] ax_desc_ready;

  // descriptor from the tagctrl_ar to the ar FIFO
  tagc_desc_t       tagctrl_ar_desc;
  logic tagctrl_ar_valid, tagctrl_ar_ready;

  // descriptor from the ar FIFO to the tagctrl_r unit
  tagc_desc_t tagctrl_r_desc;
  logic tagctrl_r_valid, tagctrl_r_ready;

  // descriptor from the tagctrl_aw to the aw FIFO
  tagc_desc_t tagctrl_aw_desc;
  logic tagctrl_aw_valid, tagctrl_aw_ready;

  // descriptor from the aw FIFO to the tagctrl_w unit
  tagc_desc_t tagctrl_w_desc;
  logic tagctrl_w_valid, tagctrl_w_ready;

  // descriptor from rw_arb_tree to spill register to cut longest path (hit miss detect)
  tagc_desc_t rw_desc;
  logic rw_desc_valid, rw_desc_ready;

  // descriptor from spill register to hit miss detect
  tagc_desc_t spill_desc;
  logic spill_valid, spill_ready;

  // descriptor from the hit_miss_unit
  tagc_desc_t desc;
  logic hit_valid, hit_ready;
  logic miss_valid, miss_ready;

  // descriptor from the evict_unit to the refill_unit
  tagc_desc_t evict_desc;
  logic evict_desc_valid, evict_desc_ready;

  // descriptor from the refill_unit to the merge_unit
  tagc_desc_t refill_desc;
  logic refill_desc_valid, refill_desc_ready;

  // descriptor from the merge_unit to the write_unit
  tagc_desc_t write_desc;
  logic write_desc_valid, write_desc_ready;

  // descriptor from the merge_unit to the read_unit
  tagc_desc_t read_desc;
  logic read_desc_valid, read_desc_ready;

  // signals from the unit to the data_ways
  way_inp_t [3:0] to_way;
  logic     [3:0] to_way_valid;
  logic     [3:0] to_way_ready;

  // read signals from the data SRAMs
  way_oup_t evict_way_out, read_way_out;
  logic evict_way_out_valid, read_way_out_valid;
  logic evict_way_out_ready, read_way_out_ready;

  // count down signal from the merge_unit to the hit miss unit
  cnt_t cnt_down;

  // unlock signals from the read / write unit towards the hit miss unit
  // req signal depends on gnt signal!
  lock_t r_unlock, w_unlock;
  logic r_unlock_req, w_unlock_req;  // Not AXI valid / ready dependency
  logic r_unlock_gnt, w_unlock_gnt;  // Not AXI valid / ready dependency

  // global SPM lock signal
  logic [Cfg.tagc_cfg.SetAssociativity-1:0] flushed;

  // BIST from tag_store
  logic [Cfg.tagc_cfg.SetAssociativity-1:0] bist_res;
  logic                                     bist_valid;

  // global flush signals
  logic tagctrl_isolate, tagctrl_isolated, aw_unit_busy, ar_unit_busy, flush_recv;

  // define address rules from the address ports, propagate it throughout the design
  rule_full_t cached_addr_rule;
  always_comb begin
    cached_addr_rule            = '0;
    cached_addr_rule.start_addr = cached_start_addr_i;
    cached_addr_rule.end_addr   = cached_end_addr_i;
  end

  // configuration, also has control over bypass logic and flush
  axi_tagctrl_config #(
      .Cfg          (Cfg),
      .AxiCfg       (AxiCfg),
      .RegWidth     (RegWidth),
      .conf_regs_d_t(conf_regs_d_t),
      .conf_regs_q_t(conf_regs_q_t),
      .desc_t       (tagctrl_desc_t),
      .rule_full_t  (rule_full_t),
      .set_asso_t   (way_ind_t),
      .addr_full_t  (axi_addr_t),
      .PrintLlcCfg  (PrintLlcCfg)
  ) i_tagctrl_config (
      .clk_i             (clk_i),
      .rst_ni            (rst_ni),
      // Configuration registers
      .conf_regs_i,
      .conf_regs_o,
      .spm_lock_o        (),
      .flushed_o         (flushed),
      .desc_o            (ax_desc[axi_llc_pkg::ConfigUnit]),
      .desc_valid_o      (ax_desc_valid[axi_llc_pkg::ConfigUnit]),
      .desc_ready_i      (ax_desc_ready[axi_llc_pkg::ConfigUnit]),
      // flush control signals to prevent new data in ax_cutter loading
      .tagctrl_isolate_o (tagctrl_isolate),
      .tagctrl_isolated_i(tagctrl_isolated),
      .aw_unit_busy_i    (aw_unit_busy),
      .ar_unit_busy_i    (ar_unit_busy),
      .flush_desc_recv_i (flush_recv),
      // BIST input
      .bist_res_i        (bist_res),
      .bist_valid_i      (bist_valid),
      // address rules for bypass selection
      .axi_cached_rule_i (cached_addr_rule),
      .axi_spm_rule_i    ('0)
  );

  //--------------------------------//
  // Tag controller R channel Logic //
  //--------------------------------//

  axi_tagctrl_ax #(
      .Cfg           (Cfg),
      .Write         (1'b0),            // connected to the AR channel
      .tagctrl_desc_t(tagctrl_desc_t),
      .tagc_desc_t   (tagc_desc_t),
      .ax_chan_t     (slv_ar_chan_t)
  ) axi_tag_ctrl_ar (
      .clk_i,
      .rst_ni,
      .ax_chan_slv_i      (to_tagctrl_req.ar),
      .ax_chan_valid_i    (to_tagctrl_req.ar_valid),
      .ax_chan_ready_o    (from_tagctrl_resp.ar_ready),
      .tagc_desc_o        (ax_desc[axi_llc_pkg::ArChanUnit]),
      .tagc_valid_o       (ax_desc_valid[axi_llc_pkg::ArChanUnit]),
      .tagc_ready_i       (ax_desc_ready[axi_llc_pkg::ArChanUnit]),
      .ax_mem_chan_mst_o  (tagctrl_req.ar),
      .ax_mem_chan_valid_o(tagctrl_req.ar_valid),
      .ax_mem_chan_ready_i(tagctrl_resp.ar_ready),
      .tagctrl_desc_o     (tagctrl_ar_desc),
      .tagctrl_valid_o    (tagctrl_ar_valid),
      .tagctrl_ready_i    (tagctrl_ar_ready)
  );

  // FIFO between AR master and R master, there can be DEPTH inflight transactions
  stream_fifo #(
      .FALL_THROUGH(1'b1),
      .DEPTH       (Cfg.TagAXFifoDepth),
      .T           (tagctrl_desc_t)
  ) i_stream_fifo_r (
      .clk_i,
      .rst_ni,
      .flush_i   (1'b0),
      .testmode_i(test_i),
      .usage_o   (  /*not used*/),
      .data_i    (tagctrl_ar_desc),
      .valid_i   (tagctrl_ar_valid),
      .ready_o   (tagctrl_ar_ready),
      .data_o    (tagctrl_r_desc),
      .valid_o   (tagctrl_r_valid),
      .ready_i   (tagctrl_r_ready)
  );

  axi_tagctrl_r #(
      .Cfg           (Cfg),
      .tagctrl_desc_t(tagctrl_desc_t),
      .tagc_inp_t    (tagc_inp_t),
      .r_chan_t      (slv_r_chan_t)
  ) i_axi_tag_ctrl_r (
      .clk_i,
      .rst_ni,
      .tagctrl_desc_i      (tagctrl_r_desc),
      .tagctrl_desc_valid_i(tagctrl_r_valid),
      .tagctrl_desc_ready_o(tagctrl_r_ready),
      .r_chan_mst_i        (tagctrl_resp.r),
      .r_chan_valid_i      (tagctrl_resp.r_valid),
      .r_chan_ready_o      (tagctrl_req.r_ready),
      .tagc_inp_r_i        (tagc_r_inp),
      .tagc_inp_r_valid_i  (tagc_r_inp_valid),
      .tagc_inp_r_ready_o  (tagc_r_inp_ready),
      .r_chan_slv_o        (from_tagctrl_resp.r),
      .r_chan_slv_valid_o  (from_tagctrl_resp.r_valid),
      .r_chan_slv_ready_i  (to_tagctrl_req.r_ready)
  );

  //--------------------------------//
  // Tag controller W channel Logic //
  //--------------------------------//

  axi_tagctrl_ax #(
      .Cfg           (Cfg),
      .Write         (1'b1),            // connected to the AW channel
      .tagctrl_desc_t(tagctrl_desc_t),
      .tagc_desc_t   (tagc_desc_t),
      .ax_chan_t     (slv_aw_chan_t)
  ) axi_tag_ctrl_aw (
      .clk_i,
      .rst_ni,
      .ax_chan_slv_i      (to_tagctrl_req.aw),
      .ax_chan_valid_i    (to_tagctrl_req.aw_valid),
      .ax_chan_ready_o    (from_tagctrl_resp.aw_ready),
      .tagc_desc_o        (ax_desc[axi_llc_pkg::AwChanUnit]),
      .tagc_valid_o       (ax_desc_valid[axi_llc_pkg::AwChanUnit]),
      .tagc_ready_i       (ax_desc_ready[axi_llc_pkg::AwChanUnit]),
      .ax_mem_chan_mst_o  (tagctrl_req.aw),
      .ax_mem_chan_valid_o(tagctrl_req.aw_valid),
      .ax_mem_chan_ready_i(tagctrl_resp.aw_ready),
      .tagctrl_desc_o     (tagctrl_aw_desc),
      .tagctrl_valid_o    (tagctrl_aw_valid),
      .tagctrl_ready_i    (tagctrl_aw_ready)
  );

  // FIFO between AW master and W master, there can be DEPTH inflight transactions
  stream_fifo #(
      .FALL_THROUGH(1'b1),
      .DEPTH       (Cfg.TagAXFifoDepth),
      .T           (tagctrl_desc_t)
  ) i_stream_fifo_w (
      .clk_i,
      .rst_ni,
      .flush_i   (1'b0),
      .testmode_i(test_i),
      .usage_o   (  /*not used*/),
      .data_i    (tagctrl_aw_desc),
      .valid_i   (tagctrl_aw_valid),
      .ready_o   (tagctrl_aw_ready),
      .data_o    (tagctrl_w_desc),
      .valid_o   (tagctrl_w_valid),
      .ready_i   (tagctrl_w_ready)
  );

  axi_tagctrl_w #(
      .Cfg           (Cfg),
      .tagctrl_desc_t(tagctrl_desc_t),
      .tagc_oup_t    (tagc_oup_t),
      .w_chan_t      (w_chan_t),
      .b_chan_t      (slv_b_chan_t)
  ) i_axi_tag_ctrl_w (
      .clk_i,
      .rst_ni,
      .test_i,
      .tagctrl_desc_i      (tagctrl_w_desc),
      .tagctrl_desc_valid_i(tagctrl_w_valid),
      .tagctrl_desc_ready_o(tagctrl_w_ready),
      .w_chan_slv_i        (to_tagctrl_req.w),
      .w_chan_slv_valid_i  (to_tagctrl_req.w_valid),
      .w_chan_slv_ready_o  (from_tagctrl_resp.w_ready),
      .b_chan_slv_o        (from_tagctrl_resp.b),
      .b_chan_slv_valid_o  (from_tagctrl_resp.b_valid),
      .b_chan_slv_ready_i  (to_tagctrl_req.b_ready),
      .tagc_oup_o          (tagc_w_oup),
      .tagc_oup_valid_o    (tagc_w_oup_valid),
      .tagc_oup_ready_i    (tagc_w_oup_ready),
      .tagc_resp_i         (tagc_b_chan),
      .tagc_resp_valid_i   (tagc_b_chan_valid),
      .tagc_resp_ready_o   (tagc_b_chan_ready),
      .w_chan_mst_o        (tagctrl_req.w),
      .w_chan_mst_valid_o  (tagctrl_req.w_valid),
      .w_chan_mst_ready_i  (tagctrl_resp.w_ready),
      .b_chan_mst_i        (tagctrl_resp.b),
      .b_chan_mst_valid_i  (tagctrl_resp.b_valid),
      .b_chan_mst_ready_o  (tagctrl_req.b_ready)
  );

  // arbitration tree which funnels the flush, read and write descriptors together
  rr_arb_tree #(
      .NumIn    (32'd3),
      .DataType (tagc_desc_t),
      .AxiVldRdy(1'b1),
      .LockIn   (1'b1)
  ) i_rw_arb_tree (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .flush_i('0),
      .rr_i   ('0),
      .req_i  (ax_desc_valid),
      .gnt_o  (ax_desc_ready),
      .data_i (ax_desc),
      .gnt_i  (rw_desc_ready),
      .req_o  (rw_desc_valid),
      .data_o (rw_desc),
      .idx_o  ()
  );

  spill_register #(
      .T(tagc_desc_t)
  ) i_rw_spill (
      .clk_i  (clk_i),
      .rst_ni (rst_ni),
      .valid_i(rw_desc_valid),
      .ready_o(rw_desc_ready),
      .data_i (rw_desc),
      .valid_o(spill_valid),
      .ready_i(spill_ready),
      .data_o (spill_desc)
  );

  axi_llc_hit_miss #(
      .Cfg         (Cfg.tagc_cfg),
      .AxiCfg      (AxiCfg),
      .desc_t      (tagc_desc_t),
      .lock_t      (lock_t),
      .cnt_t       (cnt_t),
      .way_ind_t   (way_ind_t),
      .PrintSramCfg(PrintSramCfg)
  ) i_hit_miss_unit (
      .clk_i,
      .rst_ni,
      .test_i,
      .desc_i        (spill_desc),
      .valid_i       (spill_valid),
      .ready_o       (spill_ready),
      .desc_o        (desc),
      .miss_valid_o  (miss_valid),
      .miss_ready_i  (miss_ready),
      .hit_valid_o   (hit_valid),
      .hit_ready_i   (hit_ready),
      .spm_lock_i    (1'b0),
      .flushed_i     (flushed),
      .w_unlock_i    (w_unlock),
      .w_unlock_req_i(w_unlock_req),
      .w_unlock_gnt_o(w_unlock_gnt),
      .r_unlock_i    (r_unlock),
      .r_unlock_req_i(r_unlock_req),
      .r_unlock_gnt_o(r_unlock_gnt),
      .cnt_down_i    (cnt_down),
      .bist_res_o    (bist_res),
      .bist_valid_o  (bist_valid)
  );

  axi_llc_evict_unit #(
      .Cfg      (Cfg.tagc_cfg),
      .AxiCfg   (AxiCfg),
      .desc_t   (tagc_desc_t),
      .way_inp_t(way_inp_t),
      .way_oup_t(way_oup_t),
      .aw_chan_t(slv_aw_chan_t),
      .w_chan_t (w_chan_t),
      .b_chan_t (slv_b_chan_t)
  ) i_evict_unit (
      .clk_i            (clk_i),
      .rst_ni           (rst_ni),
      .test_i           (test_i),
      .desc_i           (desc),
      .desc_valid_i     (miss_valid),
      .desc_ready_o     (miss_ready),
      .desc_o           (evict_desc),
      .desc_valid_o     (evict_desc_valid),
      .desc_ready_i     (evict_desc_ready),
      .way_inp_o        (to_way[axi_llc_pkg::EvictUnit]),
      .way_inp_valid_o  (to_way_valid[axi_llc_pkg::EvictUnit]),
      .way_inp_ready_i  (to_way_ready[axi_llc_pkg::EvictUnit]),
      .way_out_i        (evict_way_out),
      .way_out_valid_i  (evict_way_out_valid),
      .way_out_ready_o  (evict_way_out_ready),
      .aw_chan_mst_o    (tagc_req.aw),
      .aw_chan_valid_o  (tagc_req.aw_valid),
      .aw_chan_ready_i  (tagc_resp.aw_ready),
      .w_chan_mst_o     (tagc_req.w),
      .w_chan_valid_o   (tagc_req.w_valid),
      .w_chan_ready_i   (tagc_resp.w_ready),
      .b_chan_mst_i     (tagc_resp.b),
      .b_chan_valid_i   (tagc_resp.b_valid),
      .b_chan_ready_o   (tagc_req.b_ready),
      .flush_desc_recv_o(flush_recv)
  );

  // plug in refill unit for test
  axi_llc_refill_unit #(
      .Cfg      (Cfg.tagc_cfg),
      .AxiCfg   (AxiCfg),
      .desc_t   (tagc_desc_t),
      .way_inp_t(way_inp_t),
      .ar_chan_t(slv_ar_chan_t),
      .r_chan_t (slv_r_chan_t)
  ) i_refill_unit (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .test_i         (test_i),
      .desc_i         (evict_desc),
      .desc_valid_i   (evict_desc_valid),
      .desc_ready_o   (evict_desc_ready),
      .desc_o         (refill_desc),
      .desc_valid_o   (refill_desc_valid),
      .desc_ready_i   (refill_desc_ready),
      .way_inp_o      (to_way[axi_llc_pkg::RefilUnit]),
      .way_inp_valid_o(to_way_valid[axi_llc_pkg::RefilUnit]),
      .way_inp_ready_i(to_way_ready[axi_llc_pkg::RefilUnit]),
      .ar_chan_mst_o  (tagc_req.ar),
      .ar_chan_valid_o(tagc_req.ar_valid),
      .ar_chan_ready_i(tagc_resp.ar_ready),
      .r_chan_mst_i   (tagc_resp.r),
      .r_chan_valid_i (tagc_resp.r_valid),
      .r_chan_ready_o (tagc_req.r_ready)
  );

  // merge unit
  axi_llc_merge_unit #(
      .Cfg   (Cfg.tagc_cfg),
      .desc_t(tagc_desc_t),
      .cnt_t (cnt_t)
  ) i_merge_unit (
      .clk_i,
      .rst_ni,
      .bypass_desc_i (desc),
      .bypass_valid_i(hit_valid),
      .bypass_ready_o(hit_ready),
      .refill_desc_i (refill_desc),
      .refill_valid_i(refill_desc_valid),
      .refill_ready_o(refill_desc_ready),
      .read_desc_o   (read_desc),
      .read_valid_o  (read_desc_valid),
      .read_ready_i  (read_desc_ready),
      .write_desc_o  (write_desc),
      .write_valid_o (write_desc_valid),
      .write_ready_i (write_desc_ready),
      .cnt_down_o    (cnt_down)
  );

  // write unit
  axi_tagc_write_unit #(
      .Cfg      (Cfg.tagc_cfg),
      .AxiCfg   (AxiCfg),
      .desc_t   (tagc_desc_t),
      .way_inp_t(way_inp_t),
      .lock_t   (lock_t),
      .w_chan_t (tagc_oup_t),
      .b_chan_t (slv_b_chan_t)
  ) i_write_unit (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .test_i         (test_i),
      .desc_i         (write_desc),
      .desc_valid_i   (write_desc_valid),
      .desc_ready_o   (write_desc_ready),
      .w_chan_slv_i   (tagc_w_oup),
      .w_chan_valid_i (tagc_w_oup_valid),
      .w_chan_ready_o (tagc_w_oup_ready),
      .b_chan_slv_o   (tagc_b_chan),
      .b_chan_valid_o (tagc_b_chan_valid),
      .b_chan_ready_i (tagc_b_chan_ready),
      .way_inp_o      (to_way[axi_llc_pkg::WChanUnit]),
      .way_inp_valid_o(to_way_valid[axi_llc_pkg::WChanUnit]),
      .way_inp_ready_i(to_way_ready[axi_llc_pkg::WChanUnit]),
      .w_unlock_o     (w_unlock),
      .w_unlock_req_o (w_unlock_req),
      .w_unlock_gnt_i (w_unlock_gnt)
  );

  // read unit
  axi_tagc_read_unit #(
      .Cfg       (Cfg.tagc_cfg),
      .AxiCfg    (AxiCfg),
      .desc_t    (tagc_desc_t),
      .way_inp_t (way_inp_t),
      .way_oup_t (way_oup_t),
      .lock_t    (lock_t),
      .tagc_inp_t(tagc_inp_t)
  ) i_read_unit (
      .clk_i          (clk_i),
      .rst_ni         (rst_ni),
      .test_i         (test_i),
      .desc_i         (read_desc),
      .desc_valid_i   (read_desc_valid),
      .desc_ready_o   (read_desc_ready),
      .r_inp_slv_o    (tagc_r_inp),
      .r_inp_valid_o  (tagc_r_inp_valid),
      .r_inp_ready_i  (tagc_r_inp_ready),
      .way_inp_o      (to_way[axi_llc_pkg::RChanUnit]),
      .way_inp_valid_o(to_way_valid[axi_llc_pkg::RChanUnit]),
      .way_inp_ready_i(to_way_ready[axi_llc_pkg::RChanUnit]),
      .way_out_i      (read_way_out),
      .way_out_valid_i(read_way_out_valid),
      .way_out_ready_o(read_way_out_ready),
      .r_unlock_o     (r_unlock),
      .r_unlock_req_o (r_unlock_req),
      .r_unlock_gnt_i (r_unlock_gnt)
  );

  // data storage
  axi_tagctrl_ways #(
      .Cfg         (Cfg.tagc_cfg),
      .AxiCfg      (AxiCfg),
      .way_inp_t   (way_inp_t),
      .way_oup_t   (way_oup_t),
      .PrintSramCfg(PrintSramCfg)
  ) i_llc_ways (
      .clk_i                (clk_i),
      .rst_ni               (rst_ni),
      .test_i               (test_i),
      .way_inp_i            (to_way),
      .way_inp_valid_i      (to_way_valid),
      .way_inp_ready_o      (to_way_ready),
      .evict_way_out_o      (evict_way_out),
      .evict_way_out_valid_o(evict_way_out_valid),
      .evict_way_out_ready_i(evict_way_out_ready),
      .read_way_out_o       (read_way_out),
      .read_way_out_valid_o (read_way_out_valid),
      .read_way_out_ready_i (read_way_out_ready)
  );

  // AXI Mux to multiplex accesses from the tag cache to refill/evict tag cache lines
  // and from the tracker to read/write to memory
  // Attention: This unit widens the AXI ID by one!
  axi_mux #(
      .SlvAxiIDWidth(AxiCfg.SlvPortIdWidth),
      .slv_aw_chan_t(slv_aw_chan_t),
      .mst_aw_chan_t(mst_aw_chan_t),
      .w_chan_t     (w_chan_t),
      .slv_b_chan_t (slv_b_chan_t),
      .mst_b_chan_t (mst_b_chan_t),
      .slv_ar_chan_t(slv_ar_chan_t),
      .mst_ar_chan_t(mst_ar_chan_t),
      .slv_r_chan_t (slv_r_chan_t),
      .mst_r_chan_t (mst_r_chan_t),
      .slv_req_t    (slv_req_t),
      .slv_resp_t   (slv_resp_t),
      .mst_req_t    (mst_req_t),
      .mst_resp_t   (mst_resp_t),
      .NoSlvPorts   (32'd2),
      .MaxWTrans    (axi_llc_pkg::MaxTrans),
      .FallThrough  (1'b0),                   // No registers
      .SpillAw      (1'b0),                   // No registers
      .SpillW       (1'b0),                   // No registers
      .SpillB       (1'b0),                   // No registers
      .SpillAr      (1'b0),                   // No registers
      .SpillR       (1'b0)                    // No registers
  ) i_axi_mux (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .test_i     (test_i),
      .slv_reqs_i ({tagc_req, tagctrl_req}),
      .slv_resps_o({tagc_resp, tagctrl_resp}),
      .mst_req_o  (mst_req_o),
      .mst_resp_i (mst_resp_i)
  );
  slv_req_t  slv_req_cut;
  slv_resp_t slv_resp_cut;
  // Isolation module before demux to easy flushing,
  // AXI requests get stalled while flush is active
  axi_isolate #(
      .NumPending  (axi_llc_pkg::MaxTrans),
      .req_t   (slv_req_t),
      .resp_t  (slv_resp_t)
  ) i_axi_isolate_flush (
      .clk_i,
      .rst_ni,
      .slv_req_i (slv_req_cut),  // Slave port request
      .slv_resp_o (slv_resp_cut), // Slave port response
      .mst_req_o  ( to_tagctrl_req  ),
      .mst_resp_i ( from_tagctrl_resp  ),
      .isolate_i  ( tagctrl_isolate   ),
      .isolated_o ( tagctrl_isolated  )
  );

  axi_cut #(
      // AXI channel structs
      .aw_chan_t  (slv_aw_chan_t),
      .w_chan_t   (w_chan_t),
      .b_chan_t   (slv_b_chan_t),
      .ar_chan_t  (slv_ar_chan_t),
      .r_chan_t   (slv_r_chan_t),
      .req_t  (slv_req_t),
      .resp_t (slv_resp_t)
  ) i_axi_cut (
      .clk_i,
      .rst_ni,
      .slv_req_i (slv_req_i),
      .slv_resp_o(slv_resp_o),
      .mst_req_o (slv_req_cut),
      .mst_resp_i(slv_resp_cut)
  );

  // pragma translate_off
`ifndef VERILATOR
  initial begin : proc_assert_axi_params
    axi_addr_width :
    assert (AxiAddrWidth > 32'd0)
    else $fatal(1, "Parameter `AxiAddrWidth` has to be > 0!");
    axi_id_width :
    assert (AxiIdWidth > 32'd0)
    else $fatal(1, "Parameter `AxiIdWidth` has to be > 0!");
    axi_data_width :
    assert(AxiDataWidth inside {32'd8, 32'd16, 32'd32, 32'd64,
                                                 32'd128, 32'd256, 32'd512, 32'd1028})
    else $fatal(1, "Parameter `AxiDataWidth` has to be inside the AXI4+ATOP specification!");
    axi_user_width :
    assert (AxiUserWidth > 32'd0)
    else $fatal(1, "Parameter `AxiUserWidth` has to be > 0!");

    // check the address rule fields for the right size
    axi_start_addr :
    assert ($bits(cached_addr_rule.start_addr) == AxiAddrWidth)
    else $fatal(1, "rule_t.start_addr field does not match AxiAddrWidth!");
    axi_end_addr :
    assert ($bits(cached_addr_rule.end_addr) == AxiAddrWidth)
    else $fatal(1, "rule_t.start_addr field does not match AxiAddrWidth!");

    // check the structs against the Cfg
    slv_aw_id :
    assert ($bits(slv_req_i.aw.id) == AxiCfg.SlvPortIdWidth)
    else $fatal(1, $sformatf("llc> AXI Slave port, AW ID width not equal to AxiCfg"));
    slv_aw_addr :
    assert ($bits(slv_req_i.aw.addr) == AxiCfg.AddrWidthFull)
    else $fatal(1, $sformatf("llc> AXI Slave port, AW ADDR width not equal to AxiCfg"));
    slv_ar_id :
    assert ($bits(slv_req_i.ar.id) == AxiCfg.SlvPortIdWidth)
    else $fatal(1, $sformatf("llc> AXI Slave port, AW ID width not equal to AxiCfg"));
    slv_ar_addr :
    assert ($bits(slv_req_i.ar.addr) == AxiCfg.AddrWidthFull)
    else $fatal(1, $sformatf("llc> AXI Slave port, AW ADDR width not equal to AxiCfg"));
    slv_w_data :
    assert ($bits(slv_req_i.w.data) == AxiCfg.DataWidthFull)
    else $fatal(1, $sformatf("llc> AXI Slave port, W DATA width not equal to AxiCfg"));
    slv_r_data :
    assert ($bits(slv_resp_o.r.data) == AxiCfg.DataWidthFull)
    else $fatal(1, $sformatf("llc> AXI Slave port, R DATA width not equal to AxiCfg"));
    // compare the types against the structs
    slv_req_aw :
    assert ($bits(slv_aw_chan_t) == $bits(slv_req_i.aw))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_aw_chan_t and slv_req_i.aw not equal"));
    slv_req_w :
    assert ($bits(w_chan_t) == $bits(slv_req_i.w))
    else $fatal(1, $sformatf("llc> AXI Slave port, w_chan_t and slv_req_i.w not equal"));
    slv_req_b :
    assert ($bits(slv_b_chan_t) == $bits(slv_resp_o.b))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_b_chan_t and slv_resp_o.b not equal"));
    slv_req_ar :
    assert ($bits(slv_ar_chan_t) == $bits(slv_req_i.ar))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_ar_chan_t and slv_req_i.ar not equal"));
    slv_req_r :
    assert ($bits(slv_r_chan_t) == $bits(slv_resp_o.r))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_r_chan_t and slv_resp_o.r not equal"));
    // check the structs against the Cfg
    mst_aw_id :
    assert ($bits(mst_req_o.aw.id) == AxiCfg.SlvPortIdWidth + 1)
    else $fatal(1, $sformatf("llc> AXI Master port, AW ID not equal to AxiCfg.SlvPortIdWidth + 1"));
    mst_aw_addr :
    assert ($bits(mst_req_o.aw.addr) == AxiCfg.AddrWidthFull)
    else $fatal(1, $sformatf("llc> AXI Master port, AW ADDR width not equal to AxiCfg"));
    mst_ar_id :
    assert ($bits(mst_req_o.ar.id) == AxiCfg.SlvPortIdWidth + 1)
    else $fatal(1, $sformatf("llc> AXI Master port, AW ID not equal to AxiCfg.SlvPortIdWidth + 1"));
    mst_ar_addr :
    assert ($bits(mst_req_o.ar.addr) == AxiCfg.AddrWidthFull)
    else $fatal(1, $sformatf("llc> AXI Master port, AW ADDR width not equal to AxiCfg"));
    mst_w_data :
    assert ($bits(mst_req_o.w.data) == AxiCfg.DataWidthFull)
    else $fatal(1, $sformatf("llc> AXI Master port, W DATA width not equal to AxiCfg"));
    mst_r_data :
    assert ($bits(mst_resp_i.r.data) == AxiCfg.DataWidthFull)
    else $fatal(1, $sformatf("llc> AXI Master port, R DATA width not equal to AxiCfg"));
    // compare the types against the structs
    mst_req_aw :
    assert ($bits(mst_aw_chan_t) == $bits(mst_req_o.aw))
    else $fatal(1, $sformatf("llc> AXI Master port, mst_aw_chan_t and mst_req_o.aw not equal"));
    mst_req_w :
    assert ($bits(w_chan_t) == $bits(mst_req_o.w))
    else $fatal(1, $sformatf("llc> AXI Master port, w_chan_t and mst_req_o.w not equal"));
    mst_req_b :
    assert ($bits(mst_b_chan_t) == $bits(mst_resp_i.b))
    else $fatal(1, $sformatf("llc> AXI Master port, mst_b_chan_t and mst_resp_i.b not equal"));
    mst_req_ar :
    assert ($bits(mst_ar_chan_t) == $bits(mst_req_o.ar))
    else $fatal(1, $sformatf("llc> AXI Master port, mst_ar_chan_t and mst_req_i.ar not equal"));
    mst_req_r :
    assert ($bits(mst_r_chan_t) == $bits(mst_resp_i.r))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_r_chan_t and mst_resp_i.r not equal"));
  end
`endif
  // pragma translate_on

endmodule
