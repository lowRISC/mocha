module tag_lookup_engine_root_init #(
  parameter type tag_req_t = logic,
  parameter type tag_data_req_t = logic,
  parameter type tag_write_resp_t = logic,
  parameter type axi_addr_t = logic,
  parameter int unsigned BITS_PER_ROOT_FLIT = 4
) (
  input logic clk_i,
  input logic rst_ni,
  input axi_addr_t root_table_size_i,
  input logic start_i,
  output logic ready_o,
  // write interface
  output logic            root_write_req_valid_o,
  input  logic            root_write_req_ready_i,
  output tag_req_t        root_write_req_o,
  output logic            root_write_data_req_valid_o,
  input  logic            root_write_data_req_ready_i,
  output tag_data_req_t   root_write_data_req_o,
  input  logic            root_write_resp_valid_i,
  output logic            root_write_resp_ready_o,
  input  tag_write_resp_t root_write_resp_i
);

  // FSM state elements
  typedef enum logic [1:0] {
    READY = 2'b00,
    INIT = 2'b01,
    INIT_WAIT_WRITE_RSP = 2'b10
  } state_t;
  state_t state_d, state_q;
  axi_addr_t req_cnt_d, req_cnt_q;
  axi_addr_t resp_cnt_d, resp_cnt_q;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= READY;
      req_cnt_q <= 0;
      resp_cnt_q <= 0;
    end else begin
      state_q <= state_d;
      req_cnt_q <= req_cnt_d;
      resp_cnt_q <= resp_cnt_d;
    end
  end

  // assert ready_o when in READY state
  assign ready_o = (state_q == READY);

  // prepare write request
  always_comb begin
    // TODO sanity check current place holder values here
    root_write_req_o = '0;
    root_write_req_o.a_x_addr = req_cnt_q * BITS_PER_ROOT_FLIT;
    root_write_req_o.x_last = 1'b1;
    root_write_data_req_o = '0;
    root_write_data_req_o.bit_en = '1;
    root_write_data_req_o.strb = '1;
  end

  // track hand shakes on each of req/data/resp channels
  logic req_hs, data_hs, resp_hs;
  assign req_hs = root_write_req_valid_o && root_write_req_ready_i;
  assign data_hs = root_write_data_req_valid_o && root_write_data_req_ready_i;
  assign resp_hs = root_write_resp_valid_i && root_write_resp_ready_o;

  // actual state machine
  always_comb begin
    // default assignments
    state_d = state_q;
    req_cnt_d = req_cnt_q;
    resp_cnt_d = resp_cnt_q;
    root_write_req_valid_o = 1'b0;
    root_write_data_req_valid_o = 1'b0;
    root_write_resp_ready_o = 1'b0;

    unique case (state_q)
      READY: begin
        // check whether to start the state machine
        if (start_i) begin
          state_d = INIT;
          req_cnt_d = 0;
          resp_cnt_d = 0;
        end
      end

      // ongoing initialisation
      INIT: begin
        // send a request
        root_write_req_valid_o = 1'b1;
        root_write_data_req_valid_o = 1'b1;

        // book keeping based on handshake happening
        if (req_hs) req_cnt_d = req_cnt_q + 1'b1;
        // check whether the last request was sent
        if (req_hs && (req_cnt_q * BITS_PER_ROOT_FLIT == root_table_size_i * 8 - BITS_PER_ROOT_FLIT)) begin
          state_d = INIT_WAIT_WRITE_RSP;
        end
        // book keep for responses
        root_write_resp_ready_o = 1'b1;
        if (resp_hs) resp_cnt_d = resp_cnt_q + 1'b1;
      end

      // drain remaining responses
      INIT_WAIT_WRITE_RSP: begin
        // book keep for responses
        root_write_resp_ready_o = 1'b1;
        if (resp_hs) resp_cnt_d = resp_cnt_q + 1'b1;
        // check whether the last response was received
        if (resp_cnt_d * BITS_PER_ROOT_FLIT == root_table_size_i * 8) begin
          state_d = READY;
        end
      end
    endcase
  end

endmodule
