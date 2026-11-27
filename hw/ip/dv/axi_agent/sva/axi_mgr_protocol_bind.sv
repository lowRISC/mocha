// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Bind AXI Manager assertions to every axi_if, regardless of the agent's role
module axi_mgr_protocol_bind;
`ifndef GATE_LEVEL

  bind axi_if axi_mgr_protocol_sva_if u_axi_mgr_protocol_sva_if (
    .clk_i                     (clk_i                      ),
    .rst_ni                    (rst_ni                     ),
    .awvalid                   (aw_if.awvalid              ),
    .awready                   (aw_if.awready              ),
    .awid                      (aw_if.awid                 ),
    .awaddr                    (aw_if.awaddr               ),
    .awregion                  (aw_if.awregion             ),
    .awlen                     (aw_if.awlen                ),
    .awsize                    (aw_if.awsize               ),
    .awburst                   (aw_if.awburst              ),
    .awlock                    (aw_if.awlock               ),
    .awcache                   (aw_if.awcache              ),
    .awprot                    (aw_if.awprot               ),
    .awqos                     (aw_if.awqos                ),
    .awuser                    (aw_if.awuser               ),
    .wvalid                    (w_if.wvalid                ),
    .wready                    (w_if.wready                ),
    .wdata                     (w_if.wdata                 ),
    .wstrb                     (w_if.wstrb                 ),
    .wlast                     (w_if.wlast                 ),
    .wuser                     (w_if.wuser                 ),
    .bvalid                    (b_if.bvalid                ),
    .bready                    (b_if.bready                ),
    .arvalid                   (ar_if.arvalid              ),
    .arready                   (ar_if.arready              ),
    .arid                      (ar_if.arid                 ),
    .araddr                    (ar_if.araddr               ),
    .arregion                  (ar_if.arregion             ),
    .arlen                     (ar_if.arlen                ),
    .arsize                    (ar_if.arsize               ),
    .arburst                   (ar_if.arburst              ),
    .arlock                    (ar_if.arlock               ),
    .arcache                   (ar_if.arcache              ),
    .arprot                    (ar_if.arprot               ),
    .arqos                     (ar_if.arqos                ),
    .aruser                    (ar_if.aruser               ),
    .rvalid                    (r_if.rvalid                ),
    .rready                    (r_if.rready                ),
    .rid                       (r_if.rid                   ),
    .rlast                     (r_if.rlast                 ),
    .id_w_width                (aw_if.id_w_width           ),
    .id_r_width                (ar_if.id_r_width           ),
    .addr_width                (aw_if.addr_width           ),
    .data_width                (w_if.data_width            ),
    .aw_user_req_width         (aw_if.user_req_width       ),
    .ar_user_req_width         (ar_if.user_req_width       ),
    .user_data_width           (w_if.user_data_width       ),
    .is_lite                   (is_lite                    ),
    .disable_sva               (mgr_disable_sva            ),
    .max_ready_wait            (mgr_max_ready_wait         ),
    .max_output_delay_ps       (mgr_max_output_delay_ps    ),
    .max_reset_release_delay_ps(max_reset_release_delay_ps )
  );

`endif
endmodule : axi_mgr_protocol_bind
