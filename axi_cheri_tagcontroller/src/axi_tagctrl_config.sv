`include "common_cells/registers.svh"

module axi_tagctrl_config #(
  parameter int unsigned GROUPING_FACTOR = 512,
  parameter int unsigned TAGGED_CHUNK_SIZE = 16,
  parameter int unsigned COVERED_ALIGN = 8192,
  parameter int unsigned TAG_STORE_ALIGN = 64,
  parameter type slv_req_t = logic,
  parameter type slv_resp_t = logic,
  parameter type ar_chan_t = logic,
  parameter type r_chan_t = logic,
  parameter type aw_chan_t = logic,
  parameter type w_chan_t = logic,
  parameter type b_chan_t = logic,
  parameter type axi_addr_t = logic [63:0],
  parameter axi_addr_t init_covered_base = 64'd0,
  parameter axi_addr_t init_covered_top = 64'd0,
  parameter axi_addr_t init_tag_table_base = 64'd0,
  parameter logic init_start = 1'b0,
  parameter logic init_locked = 1'b1,
  parameter logic allow_resume = 1'b0,
  parameter logic allow_flush_when_locked = 1'b0,
  parameter int unsigned perf_counters = 1'b0
) (
  input logic clk_i,
  input logic rst_ni,

  input slv_req_t slv_req_i,
  output slv_resp_t slv_resp_o,

  // signaling
  output logic isolate_o,
  input logic isolated_i,
  output logic ignore_tags_o,
  output logic perform_zeroing_o,
  input logic done_zeroing_i,
  output logic perform_flushing_o,
  input logic done_flushing_i,

  // reporting
  output axi_addr_t covered_base_addr_o,
  output axi_addr_t covered_top_addr_o,
  output axi_addr_t tag_store_base_addr_o,
  output axi_addr_t tag_store_top_addr_o,
  output axi_addr_t root_table_base_addr_o,
  output axi_addr_t root_table_top_addr_o,
  output axi_addr_t leaf_table_base_addr_o,
  output axi_addr_t leaf_table_top_addr_o,
  output logic [7:0] error_o,

  // perf events
  output axi_tagctrl_pkg::tagctrl_cfg_events_t events_o,
  input axi_tagctrl_pkg::tagctrl_events_t events_i
);

  // helper address functions //
  //////////////////////////////

  function automatic axi_addr_t ceil_div(axi_addr_t value, int unsigned divisor);
    return (value + (divisor - 1)) / divisor;
  endfunction

  function automatic axi_addr_t align_up(axi_addr_t value, int unsigned align);
    return (value + (align - 1)) & ~(align - 1);
  endfunction

  // FSM //
  /////////
  typedef enum logic [2:0] { UNCONFIGURED,
                             PRE_ZEROING,
                             ZEROING,
                             SERVING,
                             PRE_FLUSHING,
                             FLUSHING
                           } fsm_state_t;
  fsm_state_t fsm_state_q, fsm_state_d;
  `FFL(fsm_state_q, fsm_state_d, 1'b1, init_start ? PRE_ZEROING : UNCONFIGURED, clk_i, rst_ni)
  logic cmd_start, cmd_resume, cmd_stop;
  always_comb begin : config_fsm
    fsm_state_d = fsm_state_q;
    isolate_o = 1'b0;
    ignore_tags_o = 1'b0;
    perform_zeroing_o = 1'b0;
    perform_flushing_o = 1'b0;
    case (fsm_state_q)
      UNCONFIGURED: begin
        ignore_tags_o = 1'b1;
        if (cmd_start) fsm_state_d = PRE_ZEROING;
        else if (cmd_resume) fsm_state_d = SERVING;
      end
      PRE_ZEROING: begin
        ignore_tags_o = 1'b1;
        isolate_o = 1'b1;
        if (isolated_i) begin
          perform_zeroing_o = 1'b1;
          fsm_state_d = ZEROING;
        end
      end
      ZEROING: begin
        isolate_o = 1'b1; // hold isolation until zeroing finishes
        if (done_zeroing_i) fsm_state_d = SERVING;
      end
      SERVING: begin
        if (cmd_stop) fsm_state_d = PRE_FLUSHING;
      end
      PRE_FLUSHING: begin
        isolate_o = 1'b1;
        if (isolated_i) begin
          perform_flushing_o = 1'b1;
          fsm_state_d = FLUSHING;
        end
      end
      FLUSHING: begin
        isolate_o = 1'b1; // hold isolation until flushing finishes
        if (done_flushing_i) fsm_state_d = UNCONFIGURED;
      end
    endcase
  end

  // module registers //
  //////////////////////
  // status
  typedef struct packed {
    logic [39:0] res_63_24;
    logic [7:0] error;
    logic [10:0] res_15_5;
    logic locked;
    logic unconfigured;
    logic flushing;
    logic zeroing;
    logic serving;
  } status_t;
  status_t status_w;
  logic locked_q, locked_d;
  `FFL(locked_q, locked_d, locked_d, init_locked, clk_i, rst_ni)
  // address registers
  axi_addr_t covered_base_q, covered_base_d;
  axi_addr_t covered_top_q, covered_top_d;
  axi_addr_t table_base_q, table_base_d;
  `FFL(covered_base_q, covered_base_d, 1'b1, init_covered_base, clk_i, rst_ni)
  `FFL(covered_top_q, covered_top_d, 1'b1, init_covered_top, clk_i, rst_ni)
  `FFL(table_base_q, table_base_d, 1'b1, init_tag_table_base, clk_i, rst_ni)

  // performance counters //
  //////////////////////////

  localparam int unsigned PERF_COUNTERS_MAX = 32;
  logic [PERF_COUNTERS_MAX-1:0][63:0] perf_counters_q, perf_counters_d;
  logic [PERF_COUNTERS_MAX-1:0][7:0] perf_select_q, perf_select_d;
  logic [PERF_COUNTERS_MAX-1:0] perf_inhibit_q, perf_inhibit_d;
  for (genvar i = 0; i < PERF_COUNTERS_MAX; i = i + 1) begin
    if (i < perf_counters) begin
      `FFL(perf_counters_q[i], perf_counters_d[i], 1'b1, 64'b0, clk_i, rst_ni)
      `FFL(perf_select_q[i], perf_select_d[i], 1'b1, 8'b0, clk_i, rst_ni)
      `FFL(perf_inhibit_q[i], perf_inhibit_d[i], 1'b1, 1'b0, clk_i, rst_ni)
    end else begin
      assign perf_counters_q[i] = '0;
      assign perf_select_q[i] = '0;
      assign perf_inhibit_q[i] = '0;
    end
  end

  // latch incoming events to cut paths
  axi_tagctrl_pkg::tagctrl_events_t events_q;
  `FFL(events_q, events_i, 1'b1, '0, clk_i, rst_ni);

  // produce output signals //
  ////////////////////////////

  axi_addr_t covered_size_bytes;
  assign covered_size_bytes = covered_top_q - covered_base_q;
  axi_addr_t leaf_table_bits;
  assign leaf_table_bits = ceil_div(covered_size_bytes, TAGGED_CHUNK_SIZE);
  axi_addr_t leaf_table_bytes;
  assign leaf_table_bytes = ceil_div(leaf_table_bits, 8);
  axi_addr_t root_table_bits;
  assign root_table_bits = ceil_div(leaf_table_bits, GROUPING_FACTOR);
  axi_addr_t root_table_bytes;
  assign root_table_bytes = ceil_div(root_table_bits, 8);

  assign covered_base_addr_o = covered_base_q;
  assign covered_top_addr_o = covered_top_q;

  assign leaf_table_base_addr_o = table_base_q;
  assign leaf_table_top_addr_o = leaf_table_base_addr_o + leaf_table_bytes;

  assign root_table_base_addr_o = align_up(leaf_table_top_addr_o, TAG_STORE_ALIGN);
  assign root_table_top_addr_o = root_table_base_addr_o + root_table_bytes;

  assign tag_store_base_addr_o = leaf_table_base_addr_o;
  assign tag_store_top_addr_o = align_up(root_table_top_addr_o, TAG_STORE_ALIGN);

  assign error_o =
    (covered_top_q < covered_base_q)          ? 8'd1 :
    (tag_store_top_addr_o < table_base_q)     ? 8'd2 :
    (|(covered_base_q & (COVERED_ALIGN - 1))) ? 8'd3 :
    (|(covered_top_q & (COVERED_ALIGN - 1)))  ? 8'd4 :
    (|(table_base_q & (TAG_STORE_ALIGN - 1))) ? 8'd5 :
                                                8'd0;

  // input address processing //
  //////////////////////////////

  // Take the bottom 12 bits of the address
  // Then mask off the bottom 3 (used to pick a byte within an 8-byte flit)
  function automatic logic[11:0] mask_addr (axi_addr_t addr);
    return {addr[11:3], 3'b000};
  endfunction

  // config address map //
  ////////////////////////

  typedef enum logic [11:0] { ADDR_STATUS = 12'h000,
                              ADDR_CONTROL = 12'h008,
                              ADDR_COVERED_BASE = 12'h010,
                              ADDR_COVERED_TOP = 12'h018,
                              ADDR_TABLE_BASE = 12'h020,
                              ADDR_TABLE_TOP = 12'h028,
                              ADDR_PERF_INHIBIT = 12'heb0,
                              ADDR_PERF_SELECT = 12'hec0,
                              ADDR_PERF_COUNTER = 12'hf00
                            } config_map_start_t;

  // event monitoring //
  //////////////////////
  if (perf_counters > 0) begin
    assign events_o.state_unconfigured = fsm_state_q == UNCONFIGURED;
    assign events_o.state_preflushing = fsm_state_q == PRE_FLUSHING;
    assign events_o.state_flushing = fsm_state_q == FLUSHING;
    assign events_o.state_prezeroing = fsm_state_q == PRE_ZEROING;
    assign events_o.state_zeroing = fsm_state_q == ZEROING;
    assign events_o.state_serving = fsm_state_q == SERVING;
  end else begin
    assign events_o = '0;
  end

  // handle reads //
  //////////////////
  // we latch requests to break the comb path
  // (read reqs are smaller than read resps)
  ar_chan_t read_req_q, read_req_d;
  logic read_req_valid_q, read_req_valid_d;
  `FFL(read_req_q, read_req_d, 1'b1, slv_req_t'{default: '0}, clk_i, rst_ni)
  `FFL(read_req_valid_q, read_req_valid_d, 1'b1, 1'b0, clk_i, rst_ni)
  always_comb begin : config_read
    automatic logic [11:0] addr_masked;
    addr_masked = mask_addr(read_req_q.addr);
    // accept incoming request
    read_req_valid_d = read_req_valid_q;
    read_req_d = read_req_q;
    slv_resp_o.ar_ready = 1'b0;
    if (slv_req_i.ar_valid && !read_req_valid_q) begin
      read_req_valid_d = 1'b1;
      read_req_d = slv_req_i.ar;
      slv_resp_o.ar_ready = 1'b1;
    end
    // handle previously accepted request
    slv_resp_o.r_valid = 1'b0;
    slv_resp_o.r.data = '0;
    slv_resp_o.r.id = read_req_q.id;
    slv_resp_o.r.resp = axi_pkg::RESP_OKAY;
    slv_resp_o.r.last = 1'b1;
    slv_resp_o.r.user = '0;
    if (read_req_valid_q) begin
      case (addr_masked)
        ADDR_STATUS: begin
          automatic status_t status = status_t'{default: '0};
          status.error = error_o;
          status.locked = locked_q;
          status.unconfigured = (fsm_state_q == UNCONFIGURED);
          status.flushing = (fsm_state_q inside {PRE_FLUSHING, FLUSHING});
          status.zeroing = (fsm_state_q inside {PRE_ZEROING, ZEROING});
          status.serving = (fsm_state_q == SERVING);
          slv_resp_o.r.data = status;
        end
        ADDR_COVERED_BASE: slv_resp_o.r.data = covered_base_q;
        ADDR_COVERED_TOP: slv_resp_o.r.data = covered_top_q;
        ADDR_TABLE_BASE: slv_resp_o.r.data = table_base_q;
        ADDR_TABLE_TOP: slv_resp_o.r.data = tag_store_top_addr_o;
      endcase
      if (perf_counters > 0) begin
        // Read of counter state from config interface
        // It doesn't matter if this is above the max counter value because
        // the wire is just not connected to any register in that case.

        // Reads of inhibit register
        if (addr_masked == ADDR_PERF_INHIBIT) begin
          slv_resp_o.r.data = perf_inhibit_q;
        end
        // Reads of select registers
        if (addr_masked >= ADDR_PERF_SELECT && addr_masked <= ADDR_PERF_SELECT + (PERF_COUNTERS_MAX - 1)) begin
          // We need to read 8 select registers. Select which "chunk" of 8 based on address bits
          automatic logic[1:0] perf_counter_chunk = addr_masked[4:3];
          for (int unsigned chunk = 0; chunk < 1 << $bits(perf_counter_chunk); chunk = chunk + 1) begin
            if (chunk == perf_counter_chunk) begin
              for (int unsigned b = 0; b < 8; b = b + 1) begin
                slv_resp_o.r.data[b*8+:8] = perf_select_q[chunk * 8 + b];
              end
            end
          end
        end
        // Data reads of the counters
        if (addr_masked >= ADDR_PERF_COUNTER && addr_masked <= ADDR_PERF_COUNTER + ((PERF_COUNTERS_MAX - 1) * 8)) begin
          automatic logic[4:0] perf_counter_idx = addr_masked[7:3];
          slv_resp_o.r.data = perf_counters_q[perf_counter_idx];
        end
      end
      // send response
      slv_resp_o.r_valid = 1'b1;
      // if the response is accepted, reset read interface state
      if (slv_req_i.r_ready) begin
        read_req_valid_d = 1'b0;
      end
    end
  end

  // handle writes //
  ///////////////////
  // we latch responses to break the comb path
  // (write resps are smaller than write reqs)
  b_chan_t write_resp_q, write_resp_d;
  logic write_resp_valid_q, write_resp_valid_d;
  `FFL(write_resp_q, write_resp_d, 1'b1, slv_req_t'{default: '0}, clk_i, rst_ni)
  `FFL(write_resp_valid_q, write_resp_valid_d, 1'b1, 1'b0, clk_i, rst_ni)
  always_comb begin : config_write
    automatic logic do_start, do_resume, do_stop, do_lock, do_config, accept, write_valid;
    // categorise write
    automatic logic [$bits(slv_req_i.w.data)-1:0] bit_strb;
    automatic logic [$bits(slv_req_i.w.data)-1:0] wdata_masked;
    automatic logic [11:0] addr_masked;
    bit_strb = '0;
    for (int unsigned i = 0; i < $bits(slv_req_i.w.strb); i++)
      bit_strb[i*8+:8] = slv_req_i.w.strb[i] ? '1 : '0;
    wdata_masked = slv_req_i.w.data & bit_strb;
    addr_masked = mask_addr(slv_req_i.aw.addr);

    do_start  = (addr_masked == ADDR_CONTROL) && |(wdata_masked & 'h00000001);
    do_resume = (addr_masked == ADDR_CONTROL) && |(wdata_masked & 'h00000100);
    do_stop   = (addr_masked == ADDR_CONTROL) && |(wdata_masked & 'h00010000);
    do_lock   = (addr_masked == ADDR_CONTROL) && |(wdata_masked & 'h01000000);
    do_config = addr_masked inside {ADDR_COVERED_BASE, ADDR_COVERED_TOP, ADDR_TABLE_BASE};
    // establish if write is ignored or accepted
    accept = (do_start && (fsm_state_q == UNCONFIGURED)) ||
             (do_resume && (fsm_state_q == UNCONFIGURED)) ||
             (do_stop && (fsm_state_q == SERVING)) ||
             (do_config && (fsm_state_q == UNCONFIGURED)) ||
             do_lock;
    write_valid = slv_req_i.aw_valid && slv_req_i.w_valid; // && slv_req_i.w.last // TODO assert last?
    // no register update by default
    covered_base_d = covered_base_q;
    covered_top_d = covered_top_q;
    table_base_d = table_base_q;
    locked_d = locked_q;
    cmd_start = 1'b0;
    cmd_resume = 1'b0;
    cmd_stop = 1'b0;
    write_resp_valid_d = write_resp_valid_q;
    write_resp_d = write_resp_q;
    slv_resp_o.aw_ready = 1'b0;
    slv_resp_o.w_ready = 1'b0;
    // Performance counters default
    perf_counters_d = perf_counters_q;
    perf_select_d = perf_select_q;
    perf_inhibit_d = perf_inhibit_q;
    // Performance counters update
    for (int i = 0; i < perf_counters; i = i+1) begin
      if (!perf_inhibit_q[i]) begin
        perf_counters_d[i] = perf_counters_q[i] + axi_tagctrl_pkg::get_perf_event(events_q, perf_select_q[i]);
      end
    end
    // when write request (AW & W) present and no write is pending
    if (write_valid && !write_resp_valid_q) begin
      // consume write
      slv_resp_o.aw_ready = 1'b1;
      slv_resp_o.w_ready = 1'b1;
      // prepare response
      write_resp_valid_d = 1'b1;
      write_resp_d.id = slv_req_i.aw.id;
      write_resp_d.resp = axi_pkg::RESP_OKAY;
      write_resp_d.user = '0;
      // when write is not ignored, perform desired effect
      if (locked_q && allow_flush_when_locked && do_stop && accept) begin
        cmd_stop = 1'b1;
      end else if (!locked_q && accept) begin
        case (addr_masked)
          ADDR_CONTROL: begin
            if (do_start) cmd_start = 1'b1;
            else if (do_resume && allow_resume) cmd_resume = 1'b1;
            else if (do_stop) cmd_stop = 1'b1;
            if (do_lock) locked_d = 1'b1;
          end
          ADDR_COVERED_BASE: begin
            covered_base_d = wdata_masked | (covered_base_q & ~bit_strb);
          end
          ADDR_COVERED_TOP: begin
            covered_top_d = wdata_masked | (covered_top_q & ~bit_strb);
          end
          ADDR_TABLE_BASE: begin
            table_base_d = wdata_masked | (covered_base_q & ~bit_strb);
          end
        endcase
      end
    end
    if (perf_counters > 0) begin
      // Write to counter state from config interface
      // It doesn't matter if this is above the max counter value because
      // the wire is just not connected to any register in that case.

      // Writes to inhibit register
      if (addr_masked == ADDR_PERF_INHIBIT) begin
        perf_inhibit_d = wdata_masked | (perf_inhibit_q & ~bit_strb);
      end
      // Writes to select registers
      if (addr_masked >= ADDR_PERF_SELECT && addr_masked <= ADDR_PERF_SELECT + (PERF_COUNTERS_MAX - 1)) begin
        // We need to set up to 8 select registers. Select which "chunk" of 8 based on address bits
        automatic logic[1:0] perf_counter_chunk = addr_masked[4:3];
        for (int unsigned chunk = 0; chunk < 1 << $bits(perf_counter_chunk); chunk = chunk + 1) begin
          if (chunk == perf_counter_chunk) begin
            for (int unsigned b = 0; b < 8; b = b + 1) begin
              if (slv_req_i.w.strb[b]) begin
                perf_select_d[chunk * 8 + b] = wdata_masked[b*8+:8];
              end
            end
          end
        end
      end
      // Data writes to the counters
      if (addr_masked >= ADDR_PERF_COUNTER && addr_masked <= ADDR_PERF_COUNTER + ((PERF_COUNTERS_MAX - 1) * 8)) begin
        automatic logic[4:0] perf_counter_idx = slv_req_i.aw.addr[7:3];
        perf_counters_d[perf_counter_idx] = wdata_masked | (perf_counters_q[perf_counter_idx] & ~bit_strb);
      end
    end

    slv_resp_o.b_valid = 1'b0;
    slv_resp_o.b = write_resp_q;
    // send response
    if (write_resp_valid_q) begin
      // default b response
      slv_resp_o.b_valid = 1'b1;
      // if the response is accepted, reset write interface state
      if (slv_req_i.b_ready) begin
        write_resp_valid_d = 1'b0;
      end
    end

  end

  // pragma translate_off
  initial begin : proc_assert_axi_params
    assert_config_axi_data_width :
    assert ($bits(slv_req_i.w.data) == 64)
    else $fatal(1, "AXI config only supports 64-bit data width");
  end
  // pragma translate_on

endmodule
