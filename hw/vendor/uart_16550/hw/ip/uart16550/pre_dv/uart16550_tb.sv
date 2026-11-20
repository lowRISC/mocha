// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module uart16550_tb;

// Clock and reset signals
logic clk;
logic rst_n;

// Waveform trace set up
initial begin
  $dumpfile("tb.fst");
  $dumpvars();
end

// CLock set up
initial begin
  clk = 0;
  forever #10 clk = ~clk; // Clock is at 100 MHz
end

// DUT signals
tlul_pkg::tl_h2d_t tl_i;
tlul_pkg::tl_d2h_t tl_o;

// Test variables
bit has_assert_fail;

// DUT instantiation
uart16550 u_dut (
  .clk_i  (clk),
  .rst_ni (rst_n),

  // Bus Interface
  .tl_i (tl_i),
  .tl_o (tl_o),

  // Alerts
  .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),
  .alert_tx_o ( ),

  // RACL interface
  .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
  .racl_error_o    ( ),

  .lsio_trigger_o ( ),

  .cio_rx_i    (1'b0),
  .cio_tx_o    ( ),
  .cio_tx_en_o ( ),

  // Interrupts
  .intr_tx_watermark_o  ( ),
  .intr_tx_empty_o      ( ),
  .intr_rx_watermark_o  ( ),
  .intr_tx_done_o       ( ),
  .intr_rx_overflow_o   ( ),
  .intr_rx_frame_err_o  ( ),
  .intr_rx_break_err_o  ( ),
  .intr_rx_timeout_o    ( ),
  .intr_rx_parity_err_o ( )
);

// Test sequence
initial begin
  // Initial signals
  rst_n = 0;
  tl_i = tlul_pkg::TL_H2D_DEFAULT;
  tl_i.d_ready = 0;
  has_assert_fail = 0;

  // Deassert reset
  repeat(10) @(posedge clk);
  rst_n <= 1;

  repeat(2) @(posedge clk);


  // Fixed register tests
  uart_req(.is_wr(1), .a(0), .data_in(32'hFE45AB01), .exp_data_out(32'hFFFFFFFF)); // Reg 0 wr FE45AB01
  uart_req(.is_wr(0), .a(0), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000000)); // Reg 0 rd
  uart_req(.is_wr(0), .a(1), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000000)); // Reg 1 rd
  uart_req(.is_wr(1), .a(1), .data_in(32'hFE120005), .exp_data_out(32'hFFFFFFFF)); // Reg 1 wr FE120005
  uart_req(.is_wr(0), .a(1), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000005)); // Reg 1 rd
  uart_req(.is_wr(1), .a(1), .data_in(32'h44EEFF0A), .exp_data_out(32'hFFFFFFFF)); // Reg 1 wr 44EEFF0A
  uart_req(.is_wr(0), .a(1), .data_in(32'hFFFFEEEE), .exp_data_out(32'h0000000A)); // Reg 1 rd
  uart_req(.is_wr(1), .a(1), .data_in(32'h00000000), .exp_data_out(32'hFFFFFFFF)); // Reg 1 wr 00000000
  uart_req(.is_wr(0), .a(2), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000001)); // Reg 2 rd
  uart_req(.is_wr(1), .a(2), .data_in(32'hFFFF0087), .exp_data_out(32'hFFFFFFFF)); // Reg 2 wr FFFF0087
  uart_req(.is_wr(0), .a(2), .data_in(32'hFFFFEEEE), .exp_data_out(32'h000000C1)); // Reg 2 rd
  uart_req(.is_wr(0), .a(3), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000013)); // Reg 3 rd
  uart_req(.is_wr(1), .a(3), .data_in(32'hFFFF00FC), .exp_data_out(32'hFFFFFFFF)); // Reg 3 wr FFFF00FC
  uart_req(.is_wr(0), .a(3), .data_in(32'hFFFFEEEE), .exp_data_out(32'h000000DB)); // Reg 3 rd
  uart_req(.is_wr(1), .a(3), .data_in(32'h00000000), .exp_data_out(32'hFFFFFFFF)); // Reg 3 wr 00000000
  uart_req(.is_wr(0), .a(3), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000003)); // Reg 3 rd
  uart_req(.is_wr(0), .a(4), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000000)); // Reg 4 rd
  uart_req(.is_wr(1), .a(4), .data_in(32'hDDDDDD5A), .exp_data_out(32'hFFFFFFFF)); // Reg 4 wr DDDDDD5A
  uart_req(.is_wr(0), .a(4), .data_in(32'hFFFFEEEE), .exp_data_out(32'h0000001A)); // Reg 4 rd
  uart_req(.is_wr(1), .a(4), .data_in(32'hBBBBBBA5), .exp_data_out(32'hFFFFFFFF)); // Reg 4 wr BBBBBBA5
  uart_req(.is_wr(0), .a(4), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000005)); // Reg 4 rd
  uart_req(.is_wr(1), .a(5), .data_in(32'hFFFFAA55), .exp_data_out(32'hFFFFFFFF)); // Reg 5 wr FFFFAA55
  uart_req(.is_wr(0), .a(5), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000060)); // Reg 5 rd
  uart_req(.is_wr(0), .a(6), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000000)); // Reg 6 rd
  uart_req(.is_wr(1), .a(4), .data_in(32'hFFFF0015), .exp_data_out(32'hFFFFFFFF)); // Reg 4 wr FFFF0015
  uart_req(.is_wr(0), .a(6), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000060)); // Reg 6 rd
  uart_req(.is_wr(1), .a(4), .data_in(32'hFFFF001B), .exp_data_out(32'hFFFFFFFF)); // Reg 4 wr FFFF001B
  uart_req(.is_wr(0), .a(6), .data_in(32'hFFFFEEEE), .exp_data_out(32'h000000B0)); // Reg 6 rd
  uart_req(.is_wr(1), .a(4), .data_in(32'hFFFF000F), .exp_data_out(32'hFFFFFFFF)); // Reg 4 wr FFFF000F
  uart_req(.is_wr(0), .a(6), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000000)); // Reg 6 rd
  uart_req(.is_wr(0), .a(7), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000000)); // Reg 7 rd
  uart_req(.is_wr(1), .a(7), .data_in(32'hABCDEF5A), .exp_data_out(32'hFFFFFFFF)); // Reg 7 wr ABCDEF5A
  uart_req(.is_wr(0), .a(7), .data_in(32'hFFFFEEEE), .exp_data_out(32'h0000005A)); // Reg 7 rd
  uart_req(.is_wr(1), .a(7), .data_in(32'hFC5612A5), .exp_data_out(32'hFFFFFFFF)); // Reg 7 wr FC5612A5
  uart_req(.is_wr(0), .a(7), .data_in(32'hFFFFEEEE), .exp_data_out(32'h000000A5)); // Reg 7 rd
  uart_req(.is_wr(1), .a(1), .data_in(32'h44EEFF0A), .exp_data_out(32'hFFFFFFFF)); // Reg 1 wr 44EEFF0A
  uart_req(.is_wr(1), .a(3), .data_in(32'h00000080), .exp_data_out(32'hFFFFFFFF)); // Reg 3 wr 00000080
  uart_req(.is_wr(0), .a(0), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000000)); // Reg 0 rd
  uart_req(.is_wr(0), .a(1), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000000)); // Reg 1 rd
  uart_req(.is_wr(1), .a(0), .data_in(32'h9AB5EEAB), .exp_data_out(32'hFFFFFFFF)); // Reg 0 wr 9AB5EEAB
  uart_req(.is_wr(1), .a(1), .data_in(32'h3CBE0191), .exp_data_out(32'hFFFFFFFF)); // Reg 1 wr 3CBE0191
  uart_req(.is_wr(0), .a(0), .data_in(32'hFFFFEEEE), .exp_data_out(32'h000000AB)); // Reg 0 rd
  uart_req(.is_wr(0), .a(1), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000091)); // Reg 1 rd
  uart_req(.is_wr(1), .a(3), .data_in(32'h00000000), .exp_data_out(32'hFFFFFFFF)); // Reg 3 wr 00000000
  uart_req(.is_wr(0), .a(0), .data_in(32'hFFFFEEEE), .exp_data_out(32'h00000000)); // Reg 0 rd
  uart_req(.is_wr(0), .a(1), .data_in(32'hFFFFEEEE), .exp_data_out(32'h0000000A)); // Reg 1 rd


  repeat(10) @(posedge clk);

  if (has_assert_fail)
    $display("Test failed!");
  else
    $display("Test passed!");

  $finish();
end

// Task to make TL-UL access to uart16550
task uart_req(
  input logic                      is_wr,
  input logic [3-1:0]              a,
  input logic [top_pkg::TL_DW-1:0] data_in,
  input logic [top_pkg::TL_DW-1:0] exp_data_out
);

tlul_pkg::tl_h2d_t          req_tl_h2d;
tlul_pkg::tl_d_op_e         exp_d_opcode;
logic [top_pkg::TL_AIW-1:0] exp_d_source;

begin
  // Set expected device opcode
  if (is_wr) begin
    exp_d_opcode = tlul_pkg::AccessAck;
  end else begin
    exp_d_opcode = tlul_pkg::AccessAckData;
  end

  // Set expected source
  exp_d_source = top_pkg::TL_AIW'($urandom());

  // Send request
  @(posedge clk);
  req_tl_h2d.a_valid   = 1;
  if (is_wr) begin
    req_tl_h2d.a_opcode  = tlul_pkg::PutFullData;
  end else begin
    req_tl_h2d.a_opcode  = tlul_pkg::Get;
  end
  req_tl_h2d.a_param   = '0;
  req_tl_h2d.a_size    = 2;
  req_tl_h2d.a_source  = exp_d_source;
  req_tl_h2d.a_address                               = $urandom(); // Unused address bits are randomised
  req_tl_h2d.a_address[0 +: $clog2(top_pkg::TL_DBW)] = '0;  // Address is word aligned
  req_tl_h2d.a_address[$clog2(top_pkg::TL_DBW) +: 3] = a;   // Register ID
  req_tl_h2d.a_mask    = 4'hF;
  req_tl_h2d.a_data    = data_in;
  req_tl_h2d.a_user    = '{
    rsvd: '0,
    instr_type: prim_mubi_pkg::MuBi4False,
    cmd_intg:  tlul_pkg::get_cmd_intg(.tl(req_tl_h2d)),
    data_intg: tlul_pkg::get_data_intg(.data(req_tl_h2d.a_data))
  };
  req_tl_h2d.d_ready = 1'b0; // Not ready for a response by default

  tl_i <= req_tl_h2d;
  do @(posedge clk); while (!tl_o.a_ready);

  // Clear a_valid and wait for response
  req_tl_h2d = tlul_pkg::TL_H2D_DEFAULT;
  if ($urandom_range(1) == 1) begin
    // Assert d_ready immediately
    tl_i <= req_tl_h2d;
  end else begin
    // Assert d_ready after some delay
    req_tl_h2d.d_ready = 1'b0;
    tl_i <= req_tl_h2d;

    repeat($urandom_range(1, 10)) @(posedge clk);
    tl_i.d_ready <= 1;
  end

  while (!tl_o.d_valid) @(posedge clk);
  assert(tl_o.d_error == 0) else begin
    $warning("[t=%0t] d_error test failed!", $time());
    has_assert_fail = 1;
  end
  assert(tl_o.d_opcode == exp_d_opcode) else begin
    $warning("[t=%0t] d_opcode test failed!", $time());
    has_assert_fail = 1;
  end
  assert(tl_o.d_param == '0) else begin
    $warning("[t=%0t] d_param test failed!", $time());
    has_assert_fail = 1;
  end
  assert(tl_o.d_size == 2) else begin
    $warning("[t=%0t] d_size test failed!", $time());
    has_assert_fail = 1;
  end
  assert(tl_o.d_source == exp_d_source) else begin
    $warning("[t=%0t] d_source test failed!", $time());
    has_assert_fail = 1;
  end
  assert(tl_o.d_data == exp_data_out) else begin
    $warning("[t=%0t] d_data test failed!", $time());
    has_assert_fail = 1;
  end
  assert(tl_o.d_user.data_intg == tlul_pkg::get_data_intg(.data(tl_o.d_data))) else begin
    $warning("[t=%0t] d_user.data_intg test failed!", $time());
    has_assert_fail = 1;
  end
  assert(tl_o.d_user.rsp_intg == tlul_pkg::get_rsp_intg(.tl(tl_o))) else begin
    $warning("[t=%0t] d_user.rsp_intg test failed!", $time());
    has_assert_fail = 1;
  end
end

endtask

endmodule
