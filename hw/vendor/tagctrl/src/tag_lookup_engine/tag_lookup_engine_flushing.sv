module tag_lookup_engine_flushing (
  input logic clk_i,
  input logic rst_ni,
  input  logic            perform_flushing_i,
  output logic            done_flushing_o,
  // outgoing root write interface
  output logic            root_req_valid_o,
  input  logic            root_req_ready_i,
  output logic            root_data_valid_o,
  input  logic            root_data_ready_i,
  input  logic            root_resp_valid_i,
  output logic            root_resp_ready_o,
  // outgoing leaf write interface
  output logic            leaf_req_valid_o,
  input  logic            leaf_req_ready_i,
  output logic            leaf_data_valid_o,
  input  logic            leaf_data_ready_i,
  input  logic            leaf_resp_valid_i,
  output logic            leaf_resp_ready_o
);

  typedef enum logic { IDLE, BUSY } state_t;
  state_t state_d, state_q;
  logic root_req_sent_d, root_req_sent_q, root_data_sent_d, root_data_sent_q;
  logic leaf_req_sent_d, leaf_req_sent_q, leaf_data_sent_d, leaf_data_sent_q;
  logic root_rsp_got_d, root_rsp_got_q, leaf_rsp_got_d, leaf_rsp_got_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      root_req_sent_q <= 1'b0;
      root_data_sent_q <= 1'b0;
      root_rsp_got_q <= 1'b0;
      leaf_req_sent_q <= 1'b0;
      leaf_data_sent_q <= 1'b0;
      leaf_rsp_got_q <= 1'b0;
    end else begin
      state_q <= state_d;
      root_req_sent_q <= root_req_sent_d;
      root_data_sent_q <= root_data_sent_d;
      root_rsp_got_q <= root_rsp_got_d;
      leaf_req_sent_q <= leaf_req_sent_d;
      leaf_data_sent_q <= leaf_data_sent_d;
      leaf_rsp_got_q <= leaf_rsp_got_d;
    end
  end

  assign done_flushing_o = (state_q == IDLE);

  assign root_req_valid_o = (state_q == BUSY) && !root_req_sent_q;
  assign root_data_valid_o = (state_q == BUSY) && !root_data_sent_q;
  assign leaf_req_valid_o = (state_q == BUSY) && !leaf_req_sent_q;
  assign leaf_data_valid_o = (state_q == BUSY) && !leaf_data_sent_q;

  assign root_resp_ready_o = 1'b1;
  assign leaf_resp_ready_o = 1'b1;

  always_comb begin
    state_d = state_q;
    root_req_sent_d = root_req_sent_q;
    root_data_sent_d = root_data_sent_q;
    root_rsp_got_d = root_rsp_got_q;
    leaf_req_sent_d = leaf_req_sent_q;
    leaf_data_sent_d = leaf_data_sent_q;
    leaf_rsp_got_d = leaf_rsp_got_q;
    unique case (state_q)
      IDLE: begin
        root_req_sent_d = 1'b0;
        root_data_sent_d = 1'b0;
        root_rsp_got_d = 1'b0;
        leaf_req_sent_d = 1'b0;
        leaf_data_sent_d = 1'b0;
        leaf_rsp_got_d = 1'b0;
        if (perform_flushing_i) state_d = BUSY;
      end
      BUSY: begin
        if (root_req_valid_o && root_req_ready_i) root_req_sent_d = 1'b1;
        if (root_data_valid_o && root_data_ready_i) root_data_sent_d = 1'b1;
        if (leaf_req_valid_o && leaf_req_ready_i) leaf_req_sent_d = 1'b1;
        if (leaf_data_valid_o && leaf_data_ready_i) leaf_data_sent_d = 1'b1;
        if (root_req_sent_q && root_data_sent_q && root_resp_valid_i) root_rsp_got_d = 1'b1;
        if (leaf_req_sent_q && leaf_data_sent_q && leaf_resp_valid_i) leaf_rsp_got_d = 1'b1;
        if (root_rsp_got_d && leaf_rsp_got_d) state_d = IDLE;
      end
      default: state_d = IDLE;
    endcase
  end

endmodule
