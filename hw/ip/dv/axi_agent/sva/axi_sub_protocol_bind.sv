// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Bind AXI Subordinate assertions to every axi_if, regardless of the agent's role
module axi_sub_protocol_bind;
`ifndef GATE_LEVEL

  bind axi_if axi_sub_protocol_sva_if u_axi_sub_protocol_sva_if (
    .clk_i              (clk_i                   ),
    .rst_ni             (rst_ni                  ),
    .awvalid            (aw_if.awvalid           ),
    .awready            (aw_if.awready           ),
    .awid               (aw_if.awid              ),
    .awaddr             (aw_if.awaddr            ),
    .awlen              (aw_if.awlen             ),
    .awsize             (aw_if.awsize            ),
    .awburst            (aw_if.awburst           ),
    .awlock             (aw_if.awlock            ),
    .wvalid             (w_if.wvalid             ),
    .wready             (w_if.wready             ),
    .wlast              (w_if.wlast              ),
    .bvalid             (b_if.bvalid             ),
    .bready             (b_if.bready             ),
    .bid                (b_if.bid                ),
    .bresp              (b_if.bresp              ),
    .buser              (b_if.buser              ),
    .arvalid            (ar_if.arvalid           ),
    .arready            (ar_if.arready           ),
    .arid               (ar_if.arid              ),
    .araddr             (ar_if.araddr            ),
    .arlen              (ar_if.arlen             ),
    .arsize             (ar_if.arsize            ),
    .arburst            (ar_if.arburst           ),
    .arlock             (ar_if.arlock            ),
    .rvalid             (r_if.rvalid             ),
    .rready             (r_if.rready             ),
    .rid                (r_if.rid                ),
    .rdata              (r_if.rdata              ),
    .rresp              (r_if.rresp              ),
    .rlast              (r_if.rlast              ),
    .ruser              (r_if.ruser              ),
    .id_w_width         (b_if.id_w_width         ),
    .id_r_width         (r_if.id_r_width         ),
    .addr_width         (ar_if.addr_width        ),
    .data_width         (r_if.data_width         ),
    .user_data_width    (r_if.user_data_width    ),
    .b_user_resp_width  (b_if.user_resp_width    ),
    .r_user_resp_width  (r_if.user_resp_width    ),
    .is_lite            (is_lite                 ),
    .disable_sva        (sub_disable_sva         ),
    .max_ready_wait     (sub_max_ready_wait      ),
    .max_output_delay_ps(sub_max_output_delay_ps )
  );

`endif
endmodule : axi_sub_protocol_bind
