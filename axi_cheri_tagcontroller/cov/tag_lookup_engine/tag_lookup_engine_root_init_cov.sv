`include "cov_utils.svh"

module tag_lookup_engine_root_init_cov (
  input logic clk_i, input logic rst_ni
, input logic root_write_req_valid_o, input logic root_write_req_ready_i
, input logic root_write_data_req_valid_o, input logic root_write_data_req_ready_i
);
  `DEF_VALID_READY_COV(init_write_req, clk_i, rst_ni, root_write_req_valid_o, root_write_req_ready_i)
  `DEF_VALID_READY_COV(init_write_data, clk_i, rst_ni, root_write_data_req_valid_o, root_write_data_req_ready_i)
endmodule

bind tag_lookup_engine_root_init tag_lookup_engine_root_init_cov tag_lookup_engine_root_init_cov_bind (
  .clk_i, .rst_ni
, .root_write_req_valid_o, .root_write_req_ready_i
, .root_write_data_req_valid_o, .root_write_data_req_ready_i
);
