module tag_lookup_engine_table_lookups_write #(
  parameter type tag_req_t = logic,
  parameter type tag_data_req_t = logic,
  parameter type tag_write_resp_t = logic,
  parameter type tag_read_resp_t = logic,
  parameter type axi_addr_t = logic,
  parameter type axi_slv_id_t = logic,
  parameter int unsigned GROUPING_FACTOR = 256,
  parameter int unsigned BITS_PER_ROOT_FLIT = 4,
  parameter int unsigned BITS_PER_LEAF_FLIT = 4,
  parameter int unsigned MAX_IN_FLIGHT = 4
) (
  input  logic            clk_i,
  input  logic            rst_ni,
  // incoming interface
  input  axi_addr_t       root_idx_i,
  input  logic            req_valid_i,
  output logic            req_ready_o,
  input  tag_req_t        req_i,
  input  logic            data_valid_i,
  output logic            data_ready_o,
  input  tag_data_req_t   data_i,
  output logic            resp_valid_o,
  input  logic            resp_ready_i,
  output tag_write_resp_t resp_o,
  // outgoing root read interface
  output logic            root_rd_req_valid_o,
  input  logic            root_rd_req_ready_i,
  output tag_req_t        root_rd_req_o,
  input  logic            root_rd_resp_valid_i,
  output logic            root_rd_resp_ready_o,
  input  tag_read_resp_t  root_rd_resp_i,
  // outgoing root write interface
  output logic            root_req_valid_o,
  input  logic            root_req_ready_i,
  output tag_req_t        root_req_o,
  output logic            root_data_valid_o,
  input  logic            root_data_ready_i,
  output tag_data_req_t   root_data_o,
  input  logic            root_resp_valid_i,
  output logic            root_resp_ready_o,
  input  tag_write_resp_t root_resp_i,
  // outgoing leaf interface
  output logic            leaf_req_valid_o,
  input  logic            leaf_req_ready_i,
  output tag_req_t        leaf_req_o,
  output logic            leaf_data_valid_o,
  input  logic            leaf_data_ready_i,
  output tag_data_req_t   leaf_data_o,
  input  logic            leaf_resp_valid_i,
  output logic            leaf_resp_ready_o,
  input  tag_write_resp_t leaf_resp_i,
  // performance events
  output axi_tagctrl_pkg::tag_lookup_engine_table_lookups_write_events_t events_o
);

  localparam int unsigned SB_IDX_W = $clog2(MAX_IN_FLIGHT);
  localparam int unsigned ROOT_STRB_W = $bits(data_i.strb);
  localparam int unsigned ROOT_DATA_W = $bits(data_i.data);
  localparam int unsigned ROOT_BIT_IDX_W = (ROOT_DATA_W > 1) ? $clog2(ROOT_DATA_W) : 1;
  localparam int unsigned LEAF_FLITS = (GROUPING_FACTOR + BITS_PER_LEAF_FLIT - 1) / BITS_PER_LEAF_FLIT;
  localparam int unsigned FLIT_CNT_W = (LEAF_FLITS > 1) ? $clog2(LEAF_FLITS) : 1;

  function automatic tag_req_t desc_with_addr(tag_req_t desc, axi_addr_t addr);
    automatic tag_req_t ret;
    ret = desc;
    ret.a_x_addr = addr;
    return ret;
  endfunction

  function automatic tag_req_t simple_read_desc(axi_slv_id_t id, axi_addr_t addr);
    tag_req_t ret = '0;
    ret.a_x_id = id;
    ret.a_x_addr = addr;
    ret.a_x_len = '0;
    ret.a_x_size = '0;
    ret.a_x_burst = '0;
    ret.x_resp = '0;
    ret.x_last = 1'b1;
    return ret;
  endfunction

  // Scoreboard tracking structure
  typedef struct packed {
    logic allocated;
    logic write_is_nonzero;
    logic root_is_one;
    logic root_rd_sent;
    logic root_rd_received;
    logic root_wr_sent;
    logic root_wr_data_sent;
    logic root_wr_received;
    logic leaf_wr_sent;
    logic leaf_wr_data_sent;
    logic leaf_wr_synth_zero_line;
    logic [FLIT_CNT_W-1:0] leaf_wr_req_flit_cnt;
    logic [FLIT_CNT_W-1:0] leaf_wr_data_flit_cnt;
    logic [FLIT_CNT_W-1:0] leaf_wr_resp_cnt;
    logic leaf_wr_received;
    logic leaf_wr_resp;
    axi_addr_t root_idx;
    tag_req_t req;
    tag_data_req_t data;
  } sb_entry_t;

  sb_entry_t [MAX_IN_FLIGHT-1:0] sb_d, sb_q;
  logic [SB_IDX_W-1:0] alloc_ptr_d, alloc_ptr_q;
  logic [SB_IDX_W-1:0] retire_ptr_d, retire_ptr_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sb_q <= '0;
      alloc_ptr_q <= '0;
      retire_ptr_q <= '0;
    end else begin
      sb_q <= sb_d;
      alloc_ptr_q <= alloc_ptr_d;
      retire_ptr_q <= retire_ptr_d;
    end
  end

  logic accept_req;
  logic root_wr_rd_ready, root_wr_needed;
  logic leaf_wr_rd_ready, leaf_wr_needed;
  axi_addr_t leaf_wr_line_addr;
  tag_req_t leaf_wr_temp_req;
  logic [FLIT_CNT_W-1:0] leaf_wr_current_req_flit;
  logic [FLIT_CNT_W-1:0] leaf_wr_current_data_flit;
  logic [FLIT_CNT_W-1:0] leaf_wr_target_flit;
  sb_entry_t curr_sb;
  logic root_rd_done;
  logic root_wr_done;
  logic leaf_wr_done;

  always_comb begin

    // local helper variables
    automatic sb_entry_t sb_alloc;
    automatic sb_entry_t [MAX_IN_FLIGHT-1:0] sb_r = sb_q;

    automatic logic [MAX_IN_FLIGHT-1:0] leaf_wr_synth_zero_line;
    automatic logic [MAX_IN_FLIGHT-1:0] root_rd_received;
    automatic logic [MAX_IN_FLIGHT-1:0] root_is_one;

    // default assignements
    alloc_ptr_d = alloc_ptr_q;
    retire_ptr_d = retire_ptr_q;

    // accept incoming request and allocate score-board entry
    accept_req = !sb_q[alloc_ptr_q].allocated && req_valid_i && data_valid_i;
    req_ready_o = accept_req;
    data_ready_o = accept_req;
    if (accept_req) begin
      sb_alloc.allocated = 1'b1;
      sb_alloc.write_is_nonzero = |(data_i.bit_en & data_i.data);
      sb_alloc.root_is_one = 1'b0;
      sb_alloc.root_rd_sent = 1'b0;
      sb_alloc.root_rd_received = 1'b0;
      sb_alloc.root_wr_sent = 1'b0;
      sb_alloc.root_wr_data_sent = 1'b0;
      sb_alloc.root_wr_received = 1'b0;
      sb_alloc.leaf_wr_sent = 1'b0;
      sb_alloc.leaf_wr_data_sent = 1'b0;
      sb_alloc.leaf_wr_synth_zero_line = 1'b0;
      sb_alloc.leaf_wr_req_flit_cnt = '0;
      sb_alloc.leaf_wr_data_flit_cnt = '0;
      sb_alloc.leaf_wr_resp_cnt = '0;
      sb_alloc.leaf_wr_received = 1'b0;
      sb_alloc.root_idx = root_idx_i;
      sb_alloc.req = req_i;
      sb_alloc.data = data_i;
      alloc_ptr_d = alloc_ptr_q + 1;
      sb_r[alloc_ptr_q] = sb_alloc;
    end
    sb_d = sb_r;
    events_o.alloc = accept_req;
    events_o.alloc_tags_zero = accept_req && !sb_alloc.write_is_nonzero;

    // initialize bypass signals
    for (int unsigned i = 0; i < MAX_IN_FLIGHT; i++) begin
      leaf_wr_synth_zero_line[i] = sb_r[i].leaf_wr_synth_zero_line;
      root_rd_received[i] = sb_r[i].root_rd_received;
      root_is_one[i] = sb_r[i].root_is_one;
    end

    // root reads //
    ////////////////
    // send needed root read requests
    root_rd_req_valid_o = 1'b0;
    root_rd_req_o = '0;
    for (int unsigned i = 0; i < MAX_IN_FLIGHT; i++) begin
      automatic logic [SB_IDX_W-1:0] idx = retire_ptr_q + i;
      if (sb_r[idx].allocated && !sb_r[idx].root_rd_sent) begin
        root_rd_req_valid_o = 1'b1;
        root_rd_req_o = simple_read_desc(idx, sb_r[idx].root_idx);
        if (root_rd_req_ready_i) sb_d[idx].root_rd_sent = 1'b1;
        break;
      end
    end
    // collect root read responses
    root_rd_resp_ready_o = 1'b1;
    if (root_rd_resp_valid_i) begin
      automatic logic [SB_IDX_W-1:0] resp_idx = root_rd_resp_i.id[SB_IDX_W-1:0];
      automatic logic [ROOT_BIT_IDX_W-1:0] bit_idx = sb_r[resp_idx].root_idx[ROOT_BIT_IDX_W-1:0];
      root_rd_received[resp_idx] = 1'b1;
      sb_d[resp_idx].root_rd_received = root_rd_received[resp_idx];

      root_is_one[resp_idx] = root_rd_resp_i.data[bit_idx];
      sb_d[resp_idx].root_is_one = root_is_one[resp_idx];
      // set the flit count for leaf writes
      // detect if synthesizing a line of zeroes is necessary
      sb_d[resp_idx].leaf_wr_req_flit_cnt = '0;
      sb_d[resp_idx].leaf_wr_data_flit_cnt = '0;
      sb_d[resp_idx].leaf_wr_resp_cnt = '0;
      if (!root_is_one[resp_idx] && sb_r[resp_idx].write_is_nonzero) begin
        leaf_wr_synth_zero_line[resp_idx] = 1'b1;
      end else begin // otherwise a single flit is needed
        leaf_wr_synth_zero_line[resp_idx] = 1'b0;
      end
      sb_d[resp_idx].leaf_wr_synth_zero_line = leaf_wr_synth_zero_line[resp_idx];
    end

    // root writes //
    /////////////////
    // send needed root write requests
    root_req_valid_o = 1'b0;
    root_req_o = '0;
    root_data_valid_o = 1'b0;
    root_data_o = '0;

    for (int unsigned i = 0; i < MAX_IN_FLIGHT; i++) begin
      automatic logic root_wr_sent, root_wr_data_sent;
      automatic logic [SB_IDX_W-1:0] req_idx = retire_ptr_q + i;
      automatic logic [ROOT_BIT_IDX_W-1:0] bit_idx = sb_r[req_idx].root_idx[ROOT_BIT_IDX_W-1:0];
      //root_wr_rd_ready = sb_r[req_idx].write_is_nonzero || root_rd_received[req_idx];
      //root_wr_rd_ready = root_rd_received[req_idx];
      root_wr_rd_ready = sb_r[req_idx].root_rd_received;
      //root_wr_needed = sb_r[req_idx].write_is_nonzero && !root_is_one[req_idx];
      root_wr_needed = sb_r[req_idx].write_is_nonzero && !sb_r[req_idx].root_is_one;
      root_wr_sent = sb_r[req_idx].root_wr_sent;
      root_wr_data_sent = sb_r[req_idx].root_wr_data_sent;

      if (sb_r[req_idx].allocated && root_wr_rd_ready && root_wr_needed) begin
        if (!root_wr_sent) begin
          root_req_valid_o = 1'b1;
          root_req_o = desc_with_addr(sb_r[req_idx].req, sb_r[req_idx].root_idx);
          root_req_o.a_x_id = '0;
          root_req_o.a_x_id[SB_IDX_W-1:0] = req_idx;
          if (root_req_ready_i) root_wr_sent = 1'b1;
        end
        if (!root_wr_data_sent) begin
          root_data_valid_o = 1'b1;
          root_data_o.data = ROOT_DATA_W'('b1) << bit_idx;
          root_data_o.bit_en = ROOT_DATA_W'('b1) << bit_idx;
          root_data_o.strb = ROOT_STRB_W'('b1) << (bit_idx >> 3);
          if (root_data_ready_i) root_wr_data_sent = 1'b1;
        end
        sb_d[req_idx].root_wr_sent = root_wr_sent;
        sb_d[req_idx].root_wr_data_sent = root_wr_data_sent;
        if (!sb_r[req_idx].root_wr_sent || !sb_r[req_idx].root_wr_data_sent) break;
      end
    end
    // collect root write responses
    root_resp_ready_o = 1'b1;
    if (root_resp_valid_i) begin
      automatic logic [SB_IDX_W-1:0] resp_idx = root_resp_i.id[SB_IDX_W-1:0];
      sb_d[resp_idx].root_wr_received = 1'b1;
    end

    // leaf writes //
    /////////////////
    leaf_req_valid_o = 1'b0;
    leaf_req_o = 'b0;
    leaf_data_valid_o = 1'b0;
    leaf_data_o = 'b0;

    for (int unsigned i = 0; i < MAX_IN_FLIGHT; i++) begin
      automatic logic [SB_IDX_W-1:0] req_idx = retire_ptr_q + i;
      //leaf_wr_rd_ready = sb_r[req_idx].write_is_nonzero || root_rd_received[req_idx];
      leaf_wr_rd_ready = sb_r[req_idx].write_is_nonzero || sb_r[req_idx].root_rd_received;
      //leaf_wr_needed = sb_r[req_idx].write_is_nonzero || root_is_one[req_idx];
      leaf_wr_needed = sb_r[req_idx].write_is_nonzero || sb_r[req_idx].root_is_one;

      // is the current entry qualifying as needing leaf writes
      //if (sb_r[req_idx].allocated && leaf_wr_rd_ready && leaf_wr_needed && root_rd_received[req_idx]) begin
      if (sb_r[req_idx].allocated && leaf_wr_rd_ready && leaf_wr_needed && sb_r[req_idx].root_rd_received) begin
        // More flits to go? otherwise, continue to next entry
        leaf_wr_line_addr = sb_r[req_idx].req.a_x_addr & ~((axi_addr_t'(1) << $clog2(GROUPING_FACTOR)) - 1);
        if (!sb_r[req_idx].leaf_wr_sent || !sb_r[req_idx].leaf_wr_data_sent) begin
          // request
          leaf_wr_current_req_flit = sb_r[req_idx].leaf_wr_req_flit_cnt;
          if (!sb_r[req_idx].leaf_wr_sent) begin
            //if (leaf_wr_synth_zero_line[req_idx]) begin
            if (sb_r[req_idx].leaf_wr_synth_zero_line) begin
              leaf_wr_temp_req = desc_with_addr(sb_r[req_idx].req, leaf_wr_line_addr + (axi_addr_t'(leaf_wr_current_req_flit) << $clog2(BITS_PER_LEAF_FLIT)));
            end else begin
              leaf_wr_temp_req = desc_with_addr(sb_r[req_idx].req, sb_r[req_idx].req.a_x_addr);
            end
            leaf_wr_temp_req.a_x_id = '0;
            leaf_wr_temp_req.a_x_id[SB_IDX_W-1:0] = req_idx;
            leaf_req_o = leaf_wr_temp_req;
            leaf_req_valid_o = 1'b1;
            // send the req
            if (leaf_req_ready_i) begin
              sb_d[req_idx].leaf_wr_req_flit_cnt = sb_r[req_idx].leaf_wr_req_flit_cnt + 1;
              // was it the last flit?
              //if (!leaf_wr_synth_zero_line[req_idx] || sb_r[req_idx].leaf_wr_req_flit_cnt == LEAF_FLITS - 1) begin
              if (!sb_r[req_idx].leaf_wr_synth_zero_line || sb_r[req_idx].leaf_wr_req_flit_cnt == LEAF_FLITS - 1) begin
                sb_d[req_idx].leaf_wr_sent = 1'b1;
              end
            end
          end
          // data
          leaf_wr_current_data_flit = sb_r[req_idx].leaf_wr_data_flit_cnt;
          if (!sb_r[req_idx].leaf_wr_data_sent) begin
            leaf_wr_target_flit = sb_r[req_idx].req.a_x_addr[$clog2(BITS_PER_LEAF_FLIT) +: FLIT_CNT_W];

            leaf_data_o.data = sb_r[req_idx].data.data;
            leaf_data_o.bit_en = sb_r[req_idx].data.bit_en;
            leaf_data_o.strb = sb_r[req_idx].data.strb;
            // if root was 0, need 0 leaf line synthesis, so 0 flits for the flits that aren't the one pointed at,
            // and write all bits from the pointed flit (0-ing the untouched capabilies as well)
            if (sb_r[req_idx].write_is_nonzero && !sb_r[req_idx].root_is_one) begin
              leaf_data_o.data = (leaf_wr_current_data_flit == leaf_wr_target_flit) ? sb_r[req_idx].data.data & sb_r[req_idx].data.bit_en
                                                                                    : '0;
              leaf_data_o.bit_en = '1;
              leaf_data_o.strb = '1;
            end
            leaf_data_valid_o = 1'b1;
            // send the data
            if (leaf_data_ready_i) begin
              sb_d[req_idx].leaf_wr_data_flit_cnt = sb_r[req_idx].leaf_wr_data_flit_cnt + 1;
              // was it the last flit?
              //if (!leaf_wr_synth_zero_line[req_idx] || sb_r[req_idx].leaf_wr_data_flit_cnt == LEAF_FLITS - 1) begin
              if (!sb_r[req_idx].leaf_wr_synth_zero_line || sb_r[req_idx].leaf_wr_data_flit_cnt == LEAF_FLITS - 1) begin
                sb_d[req_idx].leaf_wr_data_sent = 1'b1;
              end
            end
          end
        end
        break; // Stop loop evaluating newer entries to preserve in-order streaming
      end
    end
    // collect leaf write responses
    leaf_resp_ready_o = 1'b1;
    if (leaf_resp_valid_i) begin
      automatic logic [SB_IDX_W-1:0] resp_idx = leaf_resp_i.id[SB_IDX_W-1:0];
      sb_d[resp_idx].leaf_wr_resp = leaf_resp_i;
      sb_d[resp_idx].leaf_wr_resp_cnt = sb_r[resp_idx].leaf_wr_resp_cnt + 1;
      //if (sb_q[resp_idx].leaf_wr_resp_cnt == (leaf_wr_synth_zero_line[resp_idx] ? LEAF_FLITS - 1 : 0)) begin
      if (sb_q[resp_idx].leaf_wr_resp_cnt == (sb_r[resp_idx].leaf_wr_synth_zero_line ? LEAF_FLITS - 1 : 0)) begin
        sb_d[resp_idx].leaf_wr_received = 1'b1;
      end
    end

    // retire //
    ////////////
    resp_valid_o = 1'b0;
    resp_o = '0;

    curr_sb = sb_r[retire_ptr_q];
    root_rd_done = curr_sb.write_is_nonzero || curr_sb.root_rd_received;
    root_wr_done = !(curr_sb.write_is_nonzero && !curr_sb.root_is_one) || curr_sb.root_wr_received;
    leaf_wr_done = !(curr_sb.write_is_nonzero ||  curr_sb.root_is_one) || curr_sb.leaf_wr_received;

    events_o.retire_wait = 1'b0;
    events_o.retire_wait_root = 1'b0;
    events_o.retire_wait_leaf = 1'b0;
    events_o.retire_root_zero = 1'b0;
    if (curr_sb.allocated) begin
      if (root_rd_done && root_wr_done && leaf_wr_done) begin
        resp_valid_o = 1'b1;
        resp_o = curr_sb.leaf_wr_resp;
        resp_o.id = curr_sb.req.a_x_id;

        if (resp_ready_i) begin
          sb_d[retire_ptr_q].allocated = 1'b0;
          retire_ptr_d = retire_ptr_q + 1;
          events_o.retire_root_zero = !curr_sb.root_is_one;
        end
      end else begin
        events_o.retire_wait = 1'b1;
        events_o.retire_wait_root = !root_rd_done || !root_wr_done;
        events_o.retire_wait_leaf = !leaf_wr_done;
      end
    end
  end

endmodule
