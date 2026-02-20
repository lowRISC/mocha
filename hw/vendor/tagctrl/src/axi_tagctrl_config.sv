// Copyright 2023 Bruno Sá and ZeroDay Labs.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Bruno Sá <bruno.vilaca.sa@gmail.com> 
// Date: 28.11.2023


/// # Configuration of the `axi_tagcontrl`

/// # Configuration of `axi_llc`
///
/// Consumes the configuration registers of the `axi_llc`.
///
/// ## Register Map
///
/// Detailed descriptions of the individual registers can be found below.
///
/// | Name        | read/write | Description                                      |
/// |:-----------:|:----------:|:------------------------------------------------:|
/// | `CfgSpm`    | read-write | [SPM Configuration](###CfgSpm)                   |
/// | `CfgFlush`  | read-write | [Flush Configuration](###CfgFlush)               |
/// | `CommitCfg` | read-write | [Configuration Commit](###CommitCfg)             |
/// | `Flushed`   | read-only  | [Flushed Flag](###Flushed)                       |
/// | `BistOut`   | read-only  | [Tag Storage BIST Result](###BistOut)            |
/// | `SetAsso`   | read-only  | [Instantiated Set-Associativity](###SetAsso)     |
/// | `NumLines`  | read-only  | [Instantiated Number of Cache-Lines](###NumLines)|
/// | `NumBlocks` | read-only  | [Instantiated Number of Blocks](###NumBlocks)    |
/// | `Version`   | read-only  | [AXI LLC Version](###Version)                    |
///
/// ### CfgSpm
///
/// The scratch-pad-memory configuration register.
/// This register is read and writable from software.
///
/// Register Bit Map:
/// | Bits                    | Reset Value | Function                |
/// |:-----------------------:|:-----------:|:-----------------------:|
/// | `[0]`                   | `1'b0`      | SPM Configuration Set-0 |
/// | ...                     | ...         | ...                     |
/// | `[SetAssociativity-1]`  | `1'b0`      | SPM Configuration Set-X |
///
///
/// ### CfgFlush
///
/// Flush configuration register.
/// This register is read and writable from software.
///
/// This register enables flushing of individual cache sets.
///
/// Register Bit Map:
/// | Bits                    | Reset Value | Function            |
/// |:-----------------------:|:-----------:|:-------------------:|
/// | `[0]`                   | `1'b0`      | Flush Trigger Set-0 |
/// | ...                     | ...         | ...                 |
/// | `[SetAssociativity-1]`  | `1'b0`      | Flush Trigger Set-X |
/// | `[63:SetAssociativity]` | `'0`        | Reserved            |
///
///
/// ### CommitCfg
///
/// Commit configuration registers
/// This register is read and writable from software.
///
/// This register notifies the hardware that the configuration registers
/// now hold their intended value. This register must be written once after
/// writing to CfgFlush or CfgSpm.
///
/// Register Bit Map:
/// | Bits                    | Reset Value | Function             |
/// |:-----------------------:|:-----------:|:--------------------:|
/// | `[0]`                   | `1'b0`      | Commit configuration |
///
///
/// ### Flushed
///
/// Flushed status of the individual cache sets.
/// This register is read only for software.
///
/// These bits are set, if the corresponding set is in a flushed state.
/// Sets configured as SPM will have the corresponding bits set.
///
/// Register Bit Map:
/// | Bits                    | Reset Value | Function               |
/// |:-----------------------:|:-----------:|:----------------------:|
/// | `[0]`                   | `1'b0`      | Flushed Status Set-0   |
/// | ...                     | ...         | ...                    |
/// | `[SetAssociativity-1]`  | `1'b0`      | Flushed Status Set-X   |
///
///
/// ### BistOut
///
/// Build-in self-test result of the tag-storage macros.
/// This register is read only for software.
///
/// When bits are set in this register the corresponding BIST failed
/// and the associated memory seems faulty. 
///
/// Register Bit Map:
/// | Bits                    | Reset Value | Function         |
/// |:-----------------------:|:-----------:|:----------------:|
/// | `[0]`                   | `1'b0`      | BIST Error Set-0 |
/// | ...                     | ...         | ...              |
/// | `[SetAssociativity-1]`  | `1'b0`      | BIST Error Set-X |
///
///
/// ### BistStatus
///
/// Status of the BIST
///
/// Register Bit Map:
/// | Bits                    | Reset Value | Function         |
/// |:-----------------------:|:-----------:|:----------------:|
/// | `[0]`                   | `1'b0`      | BIST Done Flag   |
///
///
/// ### SetAsso
///
/// Register showing the instantiated cache set-associativity.
/// This register is read only for software.
///
/// Equal to the parameter of `axi_llc_top` `SetAssociativity`.
///
/// Register Bit Map:
/// | Bits     | Reset Value        | Function          |
/// |:--------:|:------------------:|:-----------------:|
/// | `[63:0]` | `SetAssociativity` | Set-Associativity |
///
///
/// ### NumLines
///
/// Register showing the instantiated number of cache lines per set.
/// This register is read only for software.
///
/// Equal to the parameter of `axi_llc_top` `NumLines`.
///
/// Register Bit Map:
/// | Bits     | Reset Value | Function        |
/// |:--------:|:-----------:|:---------------:|
/// | `[63:0]` | `NumLines`  | Number of Lines |
///
///
/// ### `NumBlocks`
///
/// Register showing the instantiated number of blocks per cache-line.
/// This register is read only for software.
///
/// Equal to the parameter of `axi_llc_top` `NumBlocks`.
///
/// Register Bit Map:
/// | Bits     | Reset Value | Function         |
/// |:--------:|:-----------:|:----------------:|
/// | `[63:0]` | `NumBlocks` | Number of Blocks |
///
///
/// ### `Version`
///
/// Register showing the instantiated version of the module `axi_llc`.
/// This register is read only for software.
///
/// This value is defined by `axi_llc_pkg::AxiLlcVersion`.
///
/// Register Bit Map:
/// | Bits     | Reset Value                   | Function                    |
/// |:--------:|:-----------------------------:|:---------------------------:|
/// | `[63:0]` | `axi_llc_pkg::AxiLlcVersion`  | Shows the `axi_llc_version` |
///
module axi_tagctrl_config #(
    /// Static AXI LLC configuration.
    parameter axi_llc_pkg::llc_cfg_t Cfg = axi_llc_pkg::llc_cfg_t'{default: '0},
    /// Give the exact AXI parameters in struct form. This is passed down from
    /// [`axi_llc_top`](module.axi_llc_top).
    ///
    /// Required struct definition in: `axi_llc_pkg`.
    parameter axi_llc_pkg::llc_axi_cfg_t AxiCfg = axi_llc_pkg::llc_axi_cfg_t'{default: '0},
    /// Register Width
    parameter int unsigned RegWidth = 64,
    /// Register type for HW -> Register direction
    parameter type conf_regs_d_t = logic,
    /// Register type for Register -> HW direction
    parameter type conf_regs_q_t = logic,
    /// Descriptor type. This is requires as this module emits the flush descriptors.
    /// Struct definition is in [`axi_llc_top`](module.axi_llc_top).
    parameter type desc_t = logic,
    /// Address rule struct for `common_cells/addr_decode`. Is used for bypass `axi_demux`
    /// steering.
    parameter type rule_full_t = logic,
    /// Type for indicating the set associativity, same as way_ind_t in `axi_llc_top`.
    parameter type set_asso_t = logic,
    /// Address type for the memory regions defined for caching and SPM. The same width as
    /// the address field of the AXI4+ATOP slave and master port.
    parameter type addr_full_t = logic,
    /// Whether to print config of LLC
    parameter bit PrintLlcCfg = 0
) (
    /// Rising-edge clock
    input logic clk_i,
    /// Asynchronous reset, active low
    input logic rst_ni,
    /// Configuration registers Reg -> HW
    input conf_regs_q_t conf_regs_i,
    /// Configuration registers HW -> Reg
    output conf_regs_d_t conf_regs_o,
    /// SPM lock.
    ///
    /// The cache only stores new tags in ways which are not SPM locked.
    output set_asso_t spm_lock_o,
    /// Flushed way flag.
    ///
    /// This signal defines all ways which are flushed and have no valid tags in them.
    /// Tags are not looked up in the ways which are flushed.
    output set_asso_t flushed_o,
    /// Flush descriptor output.
    ///
    /// Payload data for flush descriptors. These descriptors are generated either by configuring
    /// cache ways to SPM or when an explicit flush was triggered.
    output desc_t desc_o,
    /// Flush descriptor handshake, valid
    output logic desc_valid_o,
    /// Flush descriptor handshake, ready
    input logic desc_ready_i,
    /// Isolate the AXI slave port.
    ///
    /// Flush control sets this signal to prevent active cache accesses during flushing.
    /// This is to preserve data integrity when a cache flush is underway.
    output logic tagctrl_isolate_o,
    /// The AXI salve port is isolated.
    ///
    /// This signals the flush FSM that it can safely perform the flush.
    input logic tagctrl_isolated_i,
    /// The AW descriptor generation unit is busy.
    ///
    /// This signal is needed for the flush control so that no active functional descriptors
    /// interfere with the flush operation.
    input logic aw_unit_busy_i,
    /// The AR descriptor generation unit is busy.
    ///
    /// This signal is needed for the flush control so that no active functional descriptors
    /// interfere with the flush operation.
    input logic ar_unit_busy_i,
    /// A flush descriptor is finished flushing its cache line.
    ///
    /// This is for controlling the counters which keep track of how many flush descriptors are
    /// underway.
    input logic flush_desc_recv_i,
    /// Result data of the BIST from the tag storage macros.
    input set_asso_t bist_res_i,
    /// Result data of the BIST from the tag storage macros is valid.
    input logic bist_valid_i,
    /// Address rule for the AXI memory region which maps onto the cache.
    ///
    /// This rule is used to set the AXI LLC bypass.
    /// If all cache ways are flushed, accesses onto this address region take the bypass directly
    /// to main memory.
    input rule_full_t axi_cached_rule_i,
    /// Address rule for the AXI memory region which maps to the scratch pad memory region.
    ///
    /// Accesses are only successful, if the corresponding way is mapped as SPM
    input rule_full_t axi_spm_rule_i
);
  // register macros from `common_cells`
  `include "common_cells/registers.svh"

  // Type for the Set Associativity puls padding
  localparam int unsigned SetAssoPadWidth = RegWidth - Cfg.SetAssociativity;

  localparam int unsigned FlushIdxWidth = cf_math_pkg::idx_width(Cfg.SetAssociativity);
  typedef logic [FlushIdxWidth-1:0] flush_idx_t;

  // Counter signals for flush control
  logic clear_cnt;
  logic en_send_cnt, en_recv_cnt;
  logic load_cnt;
  logic [Cfg.IndexLength-1:0] flush_addr, to_recieve;
  // Trailing zero counter signals, for flush descriptor generation.
  flush_idx_t       to_flush_nub;
  logic             lzc_empty;
  set_asso_t        flush_way_ind;

  ////////////////////////
  // AXI Bypass control //
  ////////////////////////
  // local address maps for bypass 1:Bypass 0:LLC
  rule_full_t [1:0] axi_addr_map;
  always_comb begin : proc_axi_rule
    axi_addr_map[0] = axi_spm_rule_i;
    axi_addr_map[1] = axi_cached_rule_i;
    // Define that accesses to the SPM region always go into the `axi_llc`.
    axi_addr_map[0].idx    = 32'd0;
    // define that all burst go to the bypass, if flushed is completely set
    axi_addr_map[1].idx    = 32'd0;
    axi_addr_map[1].idx[0] = &conf_regs_i.flushed;
  end

  //////////////////////////////////////////////////////////////////
  // Configuration registers: Flush Control, Performance Counters //
  //////////////////////////////////////////////////////////////////
  // States for the control FSM
  typedef enum logic [3:0] {
    FsmIdle,
    FsmWaitAx,
    FsmWaitSplitter,
    FsmInitFlush,
    FsmSendFlush,
    FsmWaitFlush,
    FsmEndFlush,
    FsmPreInit
  } flush_fsm_e;
  flush_fsm_e flush_state_d, flush_state_q;
  logic switch_state;
  set_asso_t to_flush_d, to_flush_q;
  logic load_to_flush;

  `FFLARN(flush_state_q, flush_state_d, switch_state, FsmPreInit, clk_i, rst_ni)
  `FFLARN(to_flush_q, to_flush_d, load_to_flush, '0, clk_i, rst_ni)

  // Load enable signals, so that the FF is only active when needed.
  assign switch_state                 = (flush_state_d != flush_state_q);
  assign load_to_flush                = (to_flush_d != to_flush_q);

  // Constant hardware registers
  assign conf_regs_o.bist_out         = bist_res_i;
  assign conf_regs_o.set_asso         = Cfg.SetAssociativity;
  assign conf_regs_o.num_lines        = Cfg.NumLines;
  assign conf_regs_o.num_blocks       = Cfg.NumBlocks;
  assign conf_regs_o.version          = axi_llc_pkg::AxiLlcVersion;
  assign conf_regs_o.bist_status_done = bist_valid_i;

  // Constant register write enables
  assign conf_regs_o.bist_out_en      = 1'b1;
  assign conf_regs_o.set_asso_en      = 1'b1;
  assign conf_regs_o.num_lines_en     = 1'b1;
  assign conf_regs_o.num_blocks_en    = 1'b1;
  assign conf_regs_o.version_en       = 1'b1;
  assign conf_regs_o.bist_status_en   = 1'b1;

  always_comb begin : proc_axi_llc_cfg
    // Default assignments
    // Registers
    conf_regs_o.cfg_spm       = conf_regs_i.cfg_spm;
    conf_regs_o.cfg_flush     = conf_regs_i.cfg_flush;
    conf_regs_o.commit_cfg    = conf_regs_i.commit_cfg;
    conf_regs_o.flushed       = conf_regs_i.flushed;

    // Register enables
    conf_regs_o.cfg_spm_en    = 1'b1;  // default one
    conf_regs_o.cfg_flush_en  = 1'b1;  // default one
    conf_regs_o.commit_cfg_en = 1'b0;  // default disabled
    conf_regs_o.flushed_en    = 1'b0;  // default disabled

    // Flush state machine
    flush_state_d             = flush_state_q;
    // Slave port is isolated during flush.
    tagctrl_isolate_o             = 1'b1;
    // To flush register, holds the ways which have to be flushed.
    to_flush_d                = to_flush_q;
    // Emit flush descriptors.
    desc_valid_o              = 1'b0;
    // Default signal definitions for the descriptor send and receive counter control.
    clear_cnt                 = 1'b0;
    en_send_cnt               = 1'b0;
    en_recv_cnt               = 1'b0;
    load_cnt                  = 1'b0;

    // FSM for controlling the AW AR input to the cache and flush control
    unique case (flush_state_q)
      FsmIdle: begin
        // this state is normal operation, allow Cfg editing of the fields `CfgSpm` and `CfgFlush`
        // and do not isolate main AXI
        conf_regs_o.cfg_spm_en   = 1'b0;
        conf_regs_o.cfg_flush_en = 1'b0;
        tagctrl_isolate_o            = 1'b0;
        // Change state, if there is a flush request, i.e. CommitCfg was set
        if (conf_regs_i.commit_cfg) begin
          conf_regs_o.commit_cfg    = 1'b0;  // Clear the commit configuration flag
          conf_regs_o.commit_cfg_en = 1'b1;
          flush_state_d             = FsmWaitAx;
        end
      end
      FsmWaitAx: begin
        // wait until main AXI is free
        if (tagctrl_isolated_i) begin
          flush_state_d = FsmWaitSplitter;
        end
      end
      FsmWaitSplitter: begin
        // wait till none of the splitter units still have vectors in them
        if (!aw_unit_busy_i && !ar_unit_busy_i) begin
          flush_state_d = FsmInitFlush;
        end
      end
      FsmInitFlush: begin
        // this state determines which cache way should be flushed
        // it also sets up the counters for state-keeping how far
        // the flush operation has progressed
        // define if the user requested a flush
        if (|conf_regs_i.cfg_flush) begin
          to_flush_d = conf_regs_i.cfg_flush & ~conf_regs_i.flushed;
        end else begin
          to_flush_d             = conf_regs_i.cfg_spm & ~conf_regs_i.flushed;
          conf_regs_o.flushed    = conf_regs_i.cfg_spm & conf_regs_i.flushed;
          conf_regs_o.flushed_en = 1'b1;
        end
        // now determine if we have something to do at all
        if (to_flush_d == '0) begin
          // nothing to flush, go to idle
          flush_state_d = FsmIdle;

          conf_regs_o.cfg_flush = set_asso_t'(1'b0);
        end else begin
          flush_state_d = FsmSendFlush;
          load_cnt      = 1'b1;
        end
      end
      FsmSendFlush: begin
        // this state sends all required flush descriptors to the specified way
        desc_valid_o = 1'b1;
        // transaction
        if (desc_ready_i) begin
          // last flush descriptor for this way?
          if (flush_addr == {Cfg.IndexLength{1'b1}}) begin
            flush_state_d = FsmWaitFlush;
          end else begin
            en_send_cnt = 1'b1;
          end
        end
        // further enable the receive counter if the input signal is high
        if (flush_desc_recv_i) begin
          en_recv_cnt = 1'b1;
        end
      end
      FsmWaitFlush: begin
        // this state waits till all flush operations have exited the cache, then `FsmEndFlush`
        if (flush_desc_recv_i) begin
          if (to_recieve == {Cfg.IndexLength{1'b0}}) begin
            flush_state_d = FsmEndFlush;
          end else begin
            en_recv_cnt = 1'b1;
          end
        end
      end
      FsmEndFlush: begin
        // this state decides, if we have other ways to flush, or if we can go back to idle
        clear_cnt = 1'b1;
        if (to_flush_q == flush_way_ind) begin
          flush_state_d          = FsmIdle;
          // reset the flushed register to SPM as new requests can enter the cache
          conf_regs_o.flushed    = conf_regs_i.cfg_spm;
          conf_regs_o.flushed_en = 1'b1;
          to_flush_d             = set_asso_t'(1'b0);
          // Clear the `CfgFlush` register, load enable is default '1
          conf_regs_o.cfg_flush  = set_asso_t'(1'b0);
        end else begin
          // there are still ways to flush
          flush_state_d          = FsmInitFlush;
          conf_regs_o.flushed    = conf_regs_i.flushed | flush_way_ind;
          conf_regs_o.flushed_en = 1'b1;
        end
      end
      FsmPreInit: begin
        // The state machine starts in this state. It remains in this state until the
        // BIST of the tag storage macros is finished.
        // When the result of the BIST comes in, it is also written to the SPM configuration.
        // However does not trigger a flush. This is to have per default tag-macros with errors
        // to be mapped as SPM, so that they are not used. However they can be enabled using
        // the normal SPM configuration.
        if (bist_valid_i) begin
          flush_state_d          = FsmIdle;
          conf_regs_o.cfg_spm    = bist_res_i;
          // No load specified for CfgSpm, as per default the reg is loaded anyway.
          conf_regs_o.flushed    = bist_res_i;
          conf_regs_o.flushed_en = 1'b1;
        end
      end
      default:  /*do nothing*/;
    endcase
  end

  ////////////////////////
  // Output assignments //
  ////////////////////////
  // Flush descriptor output is static, except for the fields defined here.
  localparam int unsigned FlushAddrShift = Cfg.BlockOffsetLength + Cfg.ByteOffsetLength;

  always_comb begin
    desc_o           = '0;
    desc_o.a_x_addr  = addr_full_t'(flush_addr) << FlushAddrShift;
    desc_o.a_x_len   = axi_pkg::len_t'(Cfg.NumBlocks - 32'd1);
    desc_o.a_x_size  = axi_pkg::size_t'($clog2(Cfg.BlockSize / 32'd8));
    desc_o.a_x_burst = axi_pkg::BURST_INCR;
    desc_o.x_resp    = axi_pkg::RESP_OKAY;
    desc_o.way_ind   = flush_way_ind;
    desc_o.flush     = 1'b1;
  end

  // Configuration registers which are used in other modules.
  assign spm_lock_o = conf_regs_i.cfg_spm;
  assign flushed_o  = conf_regs_i.flushed;

  // This trailing zero counter determines which way should be flushed next.
  lzc #(
      .WIDTH(Cfg.SetAssociativity),
      .MODE (1'b0)
  ) i_lzc_flush (
      .in_i   (to_flush_q),
      .cnt_o  (to_flush_nub),
      .empty_o(lzc_empty)
  );
  // Decode flush way indicator from binary to one-hot signal.
  assign flush_way_ind = (lzc_empty) ? set_asso_t'(1'b0) : set_asso_t'(64'd1) << to_flush_nub;

  ///////////////////////////////
  // Counter for flush control //
  ///////////////////////////////
  // This counts how many flush descriptors have been sent.
  counter #(
      .WIDTH(Cfg.IndexLength)
  ) i_flush_send_counter (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .clear_i   (clear_cnt),
      .en_i      (en_send_cnt),
      .load_i    (load_cnt),
      .down_i    (1'b0),
      .d_i       ({Cfg.IndexLength{1'b0}}),
      .q_o       (flush_addr),
      .overflow_o(  /*not used*/)
  );

  // This counts how many flush descriptors are not done flushing.
  counter #(
      .WIDTH(Cfg.IndexLength)
  ) i_flush_recv_counter (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .clear_i   (clear_cnt),
      .en_i      (en_recv_cnt),
      .load_i    (load_cnt),
      .down_i    (1'b1),
      .d_i       ({Cfg.IndexLength{1'b1}}),
      .q_o       (to_recieve),
      .overflow_o(  /*not used*/)
  );

  // pragma translate_off
`ifndef VERILATOR
  initial begin : proc_check_params
    set_asso :
    assert (Cfg.SetAssociativity <= RegWidth)
    else
      $fatal(
          1,
          $sformatf(
              "LlcCfg: The maximum set associativity (%0d) has to be smaller than \
                             or equal to the the configuration register width in bits: %0d (dec).\n \
                             Reason: Set associativity has to fit inside one register.",
              Cfg.SetAssociativity,
              RegWidth
          )
      );
  end

  if (PrintLlcCfg) begin : gen_llc_hello
    initial begin : proc_llc_hello
      @(posedge rst_ni);
      $display("###############################################################################");
      $display("###############################################################################");
      $display("AXI LLC module instantiated:");
      $display("%m");
      $display("###############################################################################");
      $display("Cache Size parameters:");
      $display("Max Cache/SPM size:                (decimal): %d KiB", Cfg.SPMLength / 1024);
      $display("SetAssociativity (Number of Ways)  (decimal): %d", Cfg.SetAssociativity);
      $display("Number of Cache Lines per Set      (decimal): %d", Cfg.NumLines);
      $display("Number of Blocks per Cache Line    (decimal): %d", Cfg.NumBlocks);
      $display("Block Size in Bits                 (decimal): %d", Cfg.BlockSize);
      $display("Tag Length of AXI Address          (decimal): %d", Cfg.TagLength);
      $display("Index Length of AXI Address        (decimal): %d", Cfg.IndexLength);
      $display("Block Offset Length of AXI Address (decimal): %d", Cfg.BlockOffsetLength);
      $display("Byte Offset Length of AXI Address  (decimal): %d", Cfg.ByteOffsetLength);
      $display("###############################################################################");
      $display("AXI4 Port parameters:");
      $display("Slave port (CPU):");
      $display("ID   width (decimal): %d", AxiCfg.SlvPortIdWidth);
      $display("ADDR width (decimal): %d", AxiCfg.AddrWidthFull);
      $display("DATA width (decimal): %d", AxiCfg.DataWidthFull);
      $display("STRB width (decimal): %d", AxiCfg.DataWidthFull / 8);
      $display("Master port (memory):");
      $display("ID   width (decimal): %d", AxiCfg.SlvPortIdWidth + 1);
      $display("ADDR width (decimal): %d", AxiCfg.AddrWidthFull);
      $display("DATA width (decimal): %d", AxiCfg.DataWidthFull);
      $display("STRB width (decimal): %d", AxiCfg.DataWidthFull / 8);
      $display("Address mapping information:");
      $display("Cached region Start address (hex): %h", axi_cached_rule_i.start_addr);
      $display("Cached region End   address (hex): %h", axi_cached_rule_i.end_addr);
      $display("SPM    region Start address (hex): %h", axi_spm_rule_i.start_addr);
      $display("SPM    region End   address (hex): %h", axi_spm_rule_i.end_addr);
      $display("###############################################################################");
      $display("###############################################################################");
    end
  end
`endif
  // pragma translate_on
endmodule
