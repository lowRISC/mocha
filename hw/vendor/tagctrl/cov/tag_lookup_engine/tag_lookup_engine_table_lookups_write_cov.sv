`include "cov_utils.svh"

module tag_lookup_engine_table_lookups_write_cov #(
  parameter type sb_entry_t = logic
, parameter int unsigned MAX_IN_FLIGHT = 4
, localparam int unsigned SB_IDX_W = $clog2(MAX_IN_FLIGHT)
) (
  input logic clk_i, input logic rst_ni
  // Interface Handshakes
, input logic req_valid_i, input logic req_ready_o
, input logic resp_valid_o, input logic resp_ready_i
, input logic root_req_valid_o, input logic root_req_ready_i
, input logic root_resp_valid_i, input logic root_resp_ready_o
, input logic leaf_req_valid_o, input logic leaf_req_ready_i
, input logic leaf_resp_valid_i, input logic leaf_resp_ready_o
, // Scoreboard tracking
, input sb_entry_t [MAX_IN_FLIGHT-1:0] sb_q
, input logic [SB_IDX_W-1:0] alloc_ptr_q
, input logic [SB_IDX_W-1:0] retire_ptr_q
);

  // Interface Handshakes
  //============================================================================
  `DEF_VALID_READY_COV(write_incoming_req, clk_i, rst_ni, req_valid_i, req_ready_o)
  `DEF_VALID_READY_COV(write_outgoing_resp, clk_i, rst_ni, resp_valid_o, resp_ready_i)
  `DEF_VALID_READY_COV(write_root_req, clk_i, rst_ni, root_req_valid_o, root_req_ready_i)
  `DEF_VALID_READY_COV(write_root_resp, clk_i, rst_ni, root_resp_valid_i, root_resp_ready_o)
  `DEF_VALID_READY_COV(write_leaf_req, clk_i, rst_ni, leaf_req_valid_o, leaf_req_ready_i)
  `DEF_VALID_READY_COV(write_leaf_resp, clk_i, rst_ni, leaf_resp_valid_i, leaf_resp_ready_o)

  // Scoreboard State and Pointer
  //============================================================================
  int unsigned sb_occupancy;
  always_comb begin
    sb_occupancy = 0;
    for (int i = 0; i < MAX_IN_FLIGHT; i++) if (sb_q[i].allocated) sb_occupancy++;
  end
  covergroup cg_write_scoreboard (string name) @(posedge clk_i iff rst_ni);
    option.per_instance = 1;
    option.name = name;
    cp_occupancy: coverpoint sb_occupancy {
      bins empty = {0};
      bins partial = {[1:MAX_IN_FLIGHT-1]};
      bins full = {MAX_IN_FLIGHT};
    }
    /*
    cp_occupancy_trans: coverpoint sb_occupancy {
      bins empty_to_partial  = (0 => [1:MAX_IN_FLIGHT-1]);
      bins partial_to_full   = ([1:MAX_IN_FLIGHT-1] => MAX_IN_FLIGHT);
      bins full_to_partial   = (MAX_IN_FLIGHT => [1:MAX_IN_FLIGHT-1]);
      bins partial_to_empty  = ([1:MAX_IN_FLIGHT-1] => 0);
    }
    */
    cp_alloc_ptr:  coverpoint alloc_ptr_q;
    cp_retire_ptr: coverpoint retire_ptr_q;
  endgroup
  cg_write_scoreboard inst_cg_scoreboard = new($sformatf("%m"));

endmodule

bind tag_lookup_engine_table_lookups_write tag_lookup_engine_table_lookups_write_cov #(
  .sb_entry_t
, .MAX_IN_FLIGHT
) tag_lookup_engine_table_lookups_write_cov_bind (
  .clk_i, .rst_ni
, .req_valid_i, .req_ready_o
, .resp_valid_o, .resp_ready_i
, .root_req_valid_o, .root_req_ready_i
, .root_resp_valid_i, .root_resp_ready_o
, .leaf_req_valid_o, .leaf_req_ready_i
, .leaf_resp_valid_i, .leaf_resp_ready_o
, .sb_q
, .alloc_ptr_q
, .retire_ptr_q
);
