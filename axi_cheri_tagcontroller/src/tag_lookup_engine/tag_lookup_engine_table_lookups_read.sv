module tag_lookup_engine_table_lookups_read #(
  parameter type tag_req_t = logic,
  parameter type tag_read_resp_t = logic,
  parameter type axi_addr_t = logic,
  parameter int unsigned GROUPING_FACTOR = 256,
  parameter int unsigned MAX_IN_FLIGHT = 4
) (
  input  logic           clk_i,
  input  logic           rst_ni,
  // incoming interface
  input  axi_addr_t      root_idx_i,
  input  logic           req_valid_i,
  output logic           req_ready_o,
  input  tag_req_t       req_i,
  output logic           resp_valid_o,
  input  logic           resp_ready_i,
  output tag_read_resp_t resp_o,
  // outgoing root interface
  output logic           root_req_valid_o,
  input  logic           root_req_ready_i,
  output tag_req_t       root_req_o,
  input  logic           root_resp_valid_i,
  output logic           root_resp_ready_o,
  input  tag_read_resp_t root_resp_i,
  // outgoing leaf interface
  output logic           leaf_req_valid_o,
  input  logic           leaf_req_ready_i,
  output tag_req_t       leaf_req_o,
  output logic           leaf_req_speculative_o,
  input  logic           leaf_resp_valid_i,
  output logic           leaf_resp_ready_o,
  input  tag_read_resp_t leaf_resp_i,
  // performance events
  output axi_tagctrl_pkg::tag_lookup_engine_table_lookups_read_events_t events_o
);

  localparam int unsigned SB_IDX_W = $clog2(MAX_IN_FLIGHT);
  localparam int unsigned ROOT_DATA_IDX_W = $clog2($bits(root_resp_i.data));

  function automatic tag_req_t desc_with_addr(tag_req_t desc, axi_addr_t addr);
    automatic tag_req_t ret;
    ret = desc;
    ret.a_x_addr = addr;
    return ret;
  endfunction

  // Scoreboard for tag read requests
  typedef struct packed {
    logic allocated;
    logic root_sent;
    logic leaf_sent;
    logic root_received;
    logic leaf_received;
    tag_read_resp_t root_resp;
    tag_read_resp_t leaf_resp;
    axi_addr_t root_idx;
    tag_req_t req_payload;
    logic [$bits(req_i.a_x_id)-1:0] og_id;
    logic leaf_retry_sent;
  } sb_entry_t;

  sb_entry_t [MAX_IN_FLIGHT-1:0] sb_q, sb_d;
  logic [SB_IDX_W-1:0] alloc_ptr_q, alloc_ptr_d;
  logic [SB_IDX_W-1:0] retire_ptr_q, retire_ptr_d;

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

  // Service tag read requests
  always_comb begin

    // local helper variables
    automatic sb_entry_t sb_alloc;
    automatic sb_entry_t [MAX_IN_FLIGHT-1:0] sb_r = sb_q;
    automatic logic root_has_leaf;
    automatic logic retry_needed;

    // Default register assignments
    alloc_ptr_d = alloc_ptr_q;
    retire_ptr_d = retire_ptr_q;

    // Score board entry allocation //
    // allow consumption of incoming request if score board entry pointed at by
    // the allocation pointer isn't already allocated
    req_ready_o = !sb_q[alloc_ptr_q].allocated;
    events_o.alloc = 1'b0;
    // if a request is presente and consumed, allocate it to the score board
    if (req_valid_i && req_ready_o) begin
      sb_alloc = '0;
      sb_alloc.allocated = 1'b1;
      sb_alloc.root_sent = 1'b0;
      sb_alloc.leaf_sent = 1'b0;
      sb_alloc.root_received = 1'b0;
      sb_alloc.leaf_received = 1'b0;
      sb_alloc.root_idx = root_idx_i;
      sb_alloc.req_payload = req_i;
      sb_alloc.og_id = req_i.a_x_id;
      sb_alloc.leaf_retry_sent = 1'b0;
      alloc_ptr_d = alloc_ptr_q + 1;
      sb_r[alloc_ptr_q] = sb_alloc;
      events_o.alloc = 1'b1;
    end
    sb_d = sb_r;

    // root requests handling //
    // don't send any root requests ...
    root_req_valid_o = 1'b0;
    root_req_o = '0;
    for (int unsigned i = 0; i < MAX_IN_FLIGHT; i++) begin
      // keep idx stable by starting search from retire pointer
      // (in case of alloc wrap around, starting from 0 risks changing selected req)
      automatic logic [SB_IDX_W-1:0] idx = retire_ptr_q + i;
      // ... until we find an allocated entry without the root request sent
      if (sb_r[idx].allocated && !sb_r[idx].root_sent) begin
        root_req_valid_o = 1'b1;
        root_req_o = desc_with_addr(sb_r[idx].req_payload, sb_r[idx].root_idx);
        root_req_o.a_x_id = '0;
        root_req_o.a_x_id[SB_IDX_W-1:0] = idx; // use scoreboard idx as id
        if (root_req_ready_i) sb_d[idx].root_sent = 1'b1;
        break; // maximum 1 request per cycle
      end
    end

    // leaf requests handling //
    leaf_req_valid_o = 1'b0;
    leaf_req_o = '0;
    leaf_req_speculative_o = 1'b0;
    // Prioritise leaf miss over speculative leaf lookups. (If an earlier speculative lookup missed
    // and the root says a leaf exists, re-issue the same lookup as a non-speculative retry)
    for (int unsigned i = 0; i < MAX_IN_FLIGHT; i++) begin
      automatic logic [SB_IDX_W-1:0] idx = retire_ptr_q + i;
      root_has_leaf = sb_r[idx].root_received &&
                      sb_r[idx].root_resp.data[sb_r[idx].root_idx[ROOT_DATA_IDX_W-1:0]];
      retry_needed = sb_r[idx].allocated && root_has_leaf && sb_r[idx].leaf_received &&
                     !sb_r[idx].leaf_resp.hit && !sb_r[idx].leaf_retry_sent;
      if (retry_needed) begin
        leaf_req_valid_o = 1'b1;
        leaf_req_o = sb_r[idx].req_payload;
        leaf_req_o.a_x_id = '0;
        leaf_req_o.a_x_id[SB_IDX_W-1:0] = idx;
        if (leaf_req_ready_i) begin
          sb_d[idx].leaf_retry_sent = 1'b1;
          sb_d[idx].leaf_received = 1'b0;
        end
        break;
      end
    end

    // if no retry was needed (leaf_req_valid_o wasn't set yet)
    // If the root result is not known yet, issue a speculative leaf request. If the root result
    // arrives first, suppress the leaf access when no leaf exists, otherwise issue a single
    // non-speculative leaf request.
    if (!leaf_req_valid_o) begin
      for (int unsigned i = 0; i < MAX_IN_FLIGHT; i++) begin
        automatic logic [SB_IDX_W-1:0] idx = retire_ptr_q + i;
        if (sb_r[idx].allocated && !sb_r[idx].leaf_sent) begin
          root_has_leaf = sb_r[idx].root_received &&
                          sb_r[idx].root_resp.data[sb_r[idx].root_idx[ROOT_DATA_IDX_W-1:0]];
          if (!sb_r[idx].root_received || root_has_leaf) begin
            leaf_req_valid_o = 1'b1;
            leaf_req_o = sb_r[idx].req_payload;
            leaf_req_o.a_x_id = '0;
            leaf_req_o.a_x_id[SB_IDX_W-1:0] = idx;
            leaf_req_speculative_o = !sb_r[idx].root_received;
            if (leaf_req_ready_i) sb_d[idx].leaf_sent = 1'b1;
            break;
          end
        end
      end
    end

    // root responses handling //
    // always accept and simply update the pointed scoreboard entry
    root_resp_ready_o = 1'b1;
    if (root_resp_valid_i) begin
      automatic logic [SB_IDX_W-1:0] r_idx = root_resp_i.id[SB_IDX_W-1:0];
      sb_d[r_idx].root_received = 1'b1;
      sb_d[r_idx].root_resp = root_resp_i;
    end

    // leaf responses handling //
    leaf_resp_ready_o = 1'b1;
    if (leaf_resp_valid_i) begin
      automatic logic [SB_IDX_W-1:0] l_idx = leaf_resp_i.id[SB_IDX_W-1:0];
      sb_d[l_idx].leaf_received = 1'b1;
      sb_d[l_idx].leaf_resp = leaf_resp_i;
    end

    // retire scoreboard entry //
    resp_valid_o = 1'b0; // don't send any response until ...
    resp_o = '0;
    events_o.retire_wait = 1'b0;
    events_o.retire_wait_root = 1'b0;
    events_o.retire_wait_leaf = 1'b0;
    events_o.retire_tags_zero = 1'b0;
    events_o.retire_root_zero = 1'b0;
    if (sb_r[retire_ptr_q].allocated) begin
      if (sb_r[retire_ptr_q].root_received) begin
        root_has_leaf = sb_r[retire_ptr_q].root_resp.data[
                          sb_r[retire_ptr_q].root_idx[ROOT_DATA_IDX_W-1:0]];
        if ((!root_has_leaf && !sb_r[retire_ptr_q].leaf_sent) || sb_r[retire_ptr_q].leaf_received) begin
          retry_needed = root_has_leaf && !sb_r[retire_ptr_q].leaf_resp.hit &&
                         !sb_r[retire_ptr_q].leaf_retry_sent;

          if (!retry_needed) begin
            if (!root_has_leaf) begin
              resp_o = sb_r[retire_ptr_q].root_resp;
              resp_o.data = '0;
            end else resp_o = sb_r[retire_ptr_q].leaf_resp;
            resp_o.id = sb_r[retire_ptr_q].og_id; // overwrite id with original request id
            resp_valid_o = 1'b1; // send response
          end
        end

        if (resp_ready_i && resp_valid_o) begin // when the response is consumed ...
          sb_d[retire_ptr_q].allocated = 1'b0; // deallocate scoreboard entry
          retire_ptr_d = retire_ptr_q + 1; // bump retire slot
          events_o.retire_tags_zero = resp_o.data == '0;
          events_o.retire_root_zero = !root_has_leaf;
        end else begin
          events_o.retire_wait = 1'b1;
          events_o.retire_wait_root = 1'b0; // root received
          events_o.retire_wait_leaf = root_has_leaf ? !sb_r[retire_ptr_q].leaf_received : 1'b0;
        end
      end else begin // root still not received, blocked waiting for everything
        events_o.retire_wait = 1'b1;
        events_o.retire_wait_root = 1'b1;
        events_o.retire_wait_leaf = 1'b1;
      end
    end
  end

endmodule
