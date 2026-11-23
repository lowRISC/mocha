// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// AXI agent self-test links, each with at least one agent endpoint. +axi_link selects the link
// under test and enables only its clock (see axi_agent_link_cfg).
//
//   agent            manager agent to subordinate agent, widths from +axi_data_width,
//                    +axi_id_width, +axi_addr_width, +axi_user_width and +axi_lite
//   pulp_mgr         pulp_axi axi_rand_master to subordinate agent, 64 bit data, 5 bit IDs
//   pulp_lite_mgr    pulp_axi AXI4-Lite driver to subordinate agent in AXI4-Lite mode, 32 bit data
//   sim_mem          manager agent to pulp_axi axi_sim_mem, 64 bit data, 5 bit IDs
//   rand_slave       manager agent to pulp_axi axi_rand_slave, 64 bit data, 5 bit IDs
//   lite_regs        manager agent in AXI4-Lite mode to pulp_axi axi_lite_regs, 64 bit data
//   lite_rand_slave  manager agent in AXI4-Lite mode to pulp_axi axi_lite_rand_slave, 32 bit data
//   lite_bridge      manager agent to pulp_axi axi_to_axi_lite to subordinate agent in AXI4-Lite
//                    mode, 64 bit data
//   lite_to_axi      pulp_axi AXI4-Lite driver to pulp_axi axi_lite_to_axi to subordinate agent,
//                    32 bit data
//   xbar             two manager agents to pulp_axi axi_xbar, with the transaction limits of
//                    mocha's crossbar, to three subordinate agents, 64 bit data and address, 4 bit
//                    IDs widened to 5
//
// pulp_axi applies at 2ns and samples at 8ns after each rising edge of a 10ns clock, avoiding races
// with agent clocking blocks. The protocol assertions let the side that a pulp_axi model drives
// change up to 2ns after the edge.

`include "axi/typedef.svh"
`include "axi/assign.svh"

module tb;
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import axi_widths_pkg::*;
  import axi_agent_pkg::*;
  import axi_agent_env_pkg::*;
  import axi_agent_test_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  localparam time         ApplTime   = 2ns;
  localparam time         TestTime   = 8ns;
  localparam int unsigned ApplTimePs = ApplTime / 1ps;

  typedef logic [31:0] addr_t;
  typedef logic [63:0] addr64_t;
  typedef logic [1:0]  user_t;
  typedef logic [3:0]  id4_t;
  typedef logic [4:0]  id5_t;
  typedef logic [63:0] data64_t;
  typedef logic [7:0]  strb64_t;
  typedef logic [31:0] data32_t;
  typedef logic [3:0]  strb32_t;

  `AXI_TYPEDEF_ALL(axi64, addr_t, id5_t, data64_t, strb64_t, user_t)
  `AXI_TYPEDEF_ALL(axi32_id0, addr_t, logic [0:0], data32_t, strb32_t, user_t)
  `AXI_TYPEDEF_ALL(axi64_id0, addr_t, logic [0:0], data64_t, strb64_t, user_t)
  `AXI_TYPEDEF_ALL(xbar_mgr, addr64_t, id4_t, data64_t, strb64_t, user_t)
  `AXI_TYPEDEF_ALL(xbar_sub, addr64_t, id5_t, data64_t, strb64_t, user_t)
  `AXI_LITE_TYPEDEF_ALL(lite32, addr_t, data32_t, strb32_t)
  `AXI_LITE_TYPEDEF_ALL(lite64, addr_t, data64_t, strb64_t)

  // Probe every axi_if to check required bus activity
  bind axi_if axi_agent_probe_if u_probe (
    .clk_i     (clk_i             ),
    .rst_ni    (rst_ni            ),
    .awvalid   (aw_if.awvalid     ),
    .awready   (aw_if.awready     ),
    .awid      (aw_if.awid        ),
    .awaddr    (aw_if.awaddr      ),
    .awlen     (aw_if.awlen       ),
    .awsize    (aw_if.awsize      ),
    .awburst   (aw_if.awburst     ),
    .awlock    (aw_if.awlock      ),
    .wvalid    (w_if.wvalid       ),
    .wready    (w_if.wready       ),
    .wlast     (w_if.wlast        ),
    .bvalid    (b_if.bvalid       ),
    .bready    (b_if.bready       ),
    .bid       (b_if.bid          ),
    .bresp     (b_if.bresp        ),
    .arvalid   (ar_if.arvalid     ),
    .arready   (ar_if.arready     ),
    .arid      (ar_if.arid        ),
    .araddr    (ar_if.araddr      ),
    .arlen     (ar_if.arlen       ),
    .arsize    (ar_if.arsize      ),
    .arburst   (ar_if.arburst     ),
    .arlock    (ar_if.arlock      ),
    .rvalid    (r_if.rvalid       ),
    .rready    (r_if.rready       ),
    .rid       (r_if.rid          ),
    .rresp     (r_if.rresp        ),
    .rlast     (r_if.rlast        ),
    .id_w_width(aw_if.id_w_width  ),
    .id_r_width(ar_if.id_r_width  ),
    .data_width(w_if.data_width   ),
    .is_lite   (is_lite           )
  );

  // Struct port and axi_if for an agent endpoint facing pulp_axi. tb publishes the bus directly, so
  // CfgScope names no component.
  `define AXI_AGENT_VIP(inst, req, resp, id_w, addr_w, data_w, lite, mode, clk, rst_n) \
    axi_vip_if #(                                                                    \
      .req_t    (req               ),                                                \
      .resp_t   (resp              ),                                                \
      .IdWidth  (id_w              ),                                                \
      .AddrWidth(addr_w            ),                                                \
      .DataWidth(data_w            ),                                                \
      .UserWidth(2                 ),                                                \
      .IsLite   (lite              ),                                                \
      .IfMode   (mode              ),                                                \
      .CfgScope ({"tb.", `"inst`"})                                                  \
    ) inst (                                                                         \
      .clk_i (clk  ),                                                                \
      .rst_ni(rst_n)                                                                 \
    )

  wire agent_clk, agent_rst_n, pm_clk, pm_rst_n, pl_clk, pl_rst_n, sm_clk, sm_rst_n;
  wire rs_clk, rs_rst_n, ls_clk, ls_rst_n, lr_clk, lr_rst_n, br_clk, br_rst_n;
  wire lt_clk, lt_rst_n, xb_clk, xb_rst_n;
  clk_rst_if agent_clk_rst_if (.clk(agent_clk), .rst_n(agent_rst_n));
  clk_rst_if pm_clk_rst_if    (.clk(pm_clk),    .rst_n(pm_rst_n));
  clk_rst_if pl_clk_rst_if    (.clk(pl_clk),    .rst_n(pl_rst_n));
  clk_rst_if sm_clk_rst_if    (.clk(sm_clk),    .rst_n(sm_rst_n));
  clk_rst_if rs_clk_rst_if    (.clk(rs_clk),    .rst_n(rs_rst_n));
  clk_rst_if ls_clk_rst_if    (.clk(ls_clk),    .rst_n(ls_rst_n));
  clk_rst_if lr_clk_rst_if    (.clk(lr_clk),    .rst_n(lr_rst_n));
  clk_rst_if br_clk_rst_if    (.clk(br_clk),    .rst_n(br_rst_n));
  clk_rst_if lt_clk_rst_if    (.clk(lt_clk),    .rst_n(lt_rst_n));
  clk_rst_if xb_clk_rst_if    (.clk(xb_clk),    .rst_n(xb_rst_n));

  // Cross-wire two interfaces so each agent owns its driven side, because if_mode permits only one
  // active role per instance. Leave the undriven side at 'z.
  axi_if u_agent_mgr_if (.clk_i(agent_clk), .rst_ni(agent_rst_n));
  axi_if u_agent_sub_if (.clk_i(agent_clk), .rst_ni(agent_rst_n));

  // With +axi_undriven_footprint, connect only the ID, address and WSTRB bits that the configured
  // bus has. The other bits of each maximum-width signal are undriven at the far end.
  int unsigned conn_id_bits   = AxiMaxIdWidth;
  int unsigned conn_addr_bits = AxiMaxAddrWidth;
  int unsigned conn_strb_bits = AxiMaxStrbWidth;

  // With +axi_x_unstrobed_wdata, the subordinate agent sees X on every WDATA lane whose strobe is
  // low, which a manager may drive with any value (H.c A3.4.4)
  bit x_unstrobed_wdata;

  // Return the low bits of a signal width bits wide, and Z above them
  function automatic logic [AxiMaxDataWidth-1:0] low_bits_only(logic [AxiMaxDataWidth-1:0] value,
                                                              int unsigned             bits,
                                                              int unsigned             width);
    logic [AxiMaxDataWidth-1:0] result = {AxiMaxDataWidth{1'bz}};

    for (int unsigned i = 0; i < bits && i < width; i++) begin
      result[i] = value[i];
    end
    return result;
  endfunction : low_bits_only

  // Return data with X on every lane whose strobe is not 1
  function automatic logic [AxiMaxDataWidth-1:0] x_unstrobed(logic [AxiMaxDataWidth-1:0] data,
                                                            logic [AxiMaxStrbWidth-1:0] strb);
    logic [AxiMaxDataWidth-1:0] result = data;

    for (int unsigned lane = 0; lane < AxiMaxStrbWidth; lane++) begin
      if (strb[lane] !== 1'b1) begin
        result[8 * lane +: 8] = 'x;
      end
    end
    return result;
  endfunction : x_unstrobed

  assign u_agent_sub_if.aw_if.awvalid  = u_agent_mgr_if.aw_if.awvalid;
  assign u_agent_sub_if.aw_if.awid     = low_bits_only(u_agent_mgr_if.aw_if.awid, conn_id_bits,
                                                       AxiMaxIdWidth);
  assign u_agent_sub_if.aw_if.awaddr   = low_bits_only(u_agent_mgr_if.aw_if.awaddr, conn_addr_bits,
                                                       AxiMaxAddrWidth);
  assign u_agent_sub_if.aw_if.awregion = u_agent_mgr_if.aw_if.awregion;
  assign u_agent_sub_if.aw_if.awlen    = u_agent_mgr_if.aw_if.awlen;
  assign u_agent_sub_if.aw_if.awsize   = u_agent_mgr_if.aw_if.awsize;
  assign u_agent_sub_if.aw_if.awburst  = u_agent_mgr_if.aw_if.awburst;
  assign u_agent_sub_if.aw_if.awlock   = u_agent_mgr_if.aw_if.awlock;
  assign u_agent_sub_if.aw_if.awcache  = u_agent_mgr_if.aw_if.awcache;
  assign u_agent_sub_if.aw_if.awprot   = u_agent_mgr_if.aw_if.awprot;
  assign u_agent_sub_if.aw_if.awqos    = u_agent_mgr_if.aw_if.awqos;
  assign u_agent_sub_if.aw_if.awuser   = u_agent_mgr_if.aw_if.awuser;
  assign u_agent_mgr_if.aw_if.awready  = u_agent_sub_if.aw_if.awready;

  assign u_agent_sub_if.w_if.wvalid    = u_agent_mgr_if.w_if.wvalid;
  assign u_agent_sub_if.w_if.wdata     = x_unstrobed_wdata ?
                                         x_unstrobed(u_agent_mgr_if.w_if.wdata,
                                                     u_agent_mgr_if.w_if.wstrb) :
                                         u_agent_mgr_if.w_if.wdata;
  assign u_agent_sub_if.w_if.wstrb     = low_bits_only(u_agent_mgr_if.w_if.wstrb, conn_strb_bits,
                                                       AxiMaxStrbWidth);
  assign u_agent_sub_if.w_if.wlast     = u_agent_mgr_if.w_if.wlast;
  assign u_agent_sub_if.w_if.wuser     = u_agent_mgr_if.w_if.wuser;
  assign u_agent_mgr_if.w_if.wready    = u_agent_sub_if.w_if.wready;

  assign u_agent_mgr_if.b_if.bvalid    = u_agent_sub_if.b_if.bvalid;
  assign u_agent_mgr_if.b_if.bid       = low_bits_only(u_agent_sub_if.b_if.bid, conn_id_bits,
                                                       AxiMaxIdWidth);
  assign u_agent_mgr_if.b_if.bresp     = u_agent_sub_if.b_if.bresp;
  assign u_agent_mgr_if.b_if.buser     = u_agent_sub_if.b_if.buser;
  assign u_agent_sub_if.b_if.bready    = u_agent_mgr_if.b_if.bready;

  assign u_agent_sub_if.ar_if.arvalid  = u_agent_mgr_if.ar_if.arvalid;
  assign u_agent_sub_if.ar_if.arid     = low_bits_only(u_agent_mgr_if.ar_if.arid, conn_id_bits,
                                                       AxiMaxIdWidth);
  assign u_agent_sub_if.ar_if.araddr   = low_bits_only(u_agent_mgr_if.ar_if.araddr, conn_addr_bits,
                                                       AxiMaxAddrWidth);
  assign u_agent_sub_if.ar_if.arregion = u_agent_mgr_if.ar_if.arregion;
  assign u_agent_sub_if.ar_if.arlen    = u_agent_mgr_if.ar_if.arlen;
  assign u_agent_sub_if.ar_if.arsize   = u_agent_mgr_if.ar_if.arsize;
  assign u_agent_sub_if.ar_if.arburst  = u_agent_mgr_if.ar_if.arburst;
  assign u_agent_sub_if.ar_if.arlock   = u_agent_mgr_if.ar_if.arlock;
  assign u_agent_sub_if.ar_if.arcache  = u_agent_mgr_if.ar_if.arcache;
  assign u_agent_sub_if.ar_if.arprot   = u_agent_mgr_if.ar_if.arprot;
  assign u_agent_sub_if.ar_if.arqos    = u_agent_mgr_if.ar_if.arqos;
  assign u_agent_sub_if.ar_if.aruser   = u_agent_mgr_if.ar_if.aruser;
  assign u_agent_mgr_if.ar_if.arready  = u_agent_sub_if.ar_if.arready;

  assign u_agent_mgr_if.r_if.rvalid    = u_agent_sub_if.r_if.rvalid;
  assign u_agent_mgr_if.r_if.rid       = low_bits_only(u_agent_sub_if.r_if.rid, conn_id_bits,
                                                       AxiMaxIdWidth);
  assign u_agent_mgr_if.r_if.rdata     = u_agent_sub_if.r_if.rdata;
  assign u_agent_mgr_if.r_if.rresp     = u_agent_sub_if.r_if.rresp;
  assign u_agent_mgr_if.r_if.rlast     = u_agent_sub_if.r_if.rlast;
  assign u_agent_mgr_if.r_if.ruser     = u_agent_sub_if.r_if.ruser;
  assign u_agent_sub_if.r_if.rready    = u_agent_mgr_if.r_if.rready;

  // pulp_mgr: pulp_axi random manager to subordinate agent
  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(64),
    .AXI_ID_WIDTH  (5 ),
    .AXI_USER_WIDTH(2 )
  ) pm_dv (
    .clk_i(pm_clk)
  );
  axi64_req_t  pm_req;
  axi64_resp_t pm_resp;
  `AXI_ASSIGN_TO_REQ(pm_req, pm_dv)
  `AXI_ASSIGN_FROM_RESP(pm_dv, pm_resp)
  `AXI_AGENT_VIP(u_pm_sub, axi64_req_t, axi64_resp_t, 5, 32, 64, 1'b0, Subordinate, pm_clk,
                 pm_rst_n);
  assign u_pm_sub.axi_req = pm_req;
  assign pm_resp          = u_pm_sub.axi_resp;

  axi_agent_pulp_ctrl_if pm_ctrl();

  // +pulp_mgr_kind selects the random manager. Default writes are serial so memory comparison knows
  // overlapping write order. Exclude WRAP and exclusive accesses: axi_rand_master misaligns WRAP
  // and adds a beat to exclusive bursts (AMBA AXI H.c A3.4.1, A7.2.4). Limit bursts to 16 beats
  // because it does not cap FIXED lengths (A3.4.1). Select incr for INCR-only bursts up to 256
  // beats (pulp_axi's INCR-only axi_scoreboard checks read-only runs), wrap for misaligned WRAP,
  // excl for oversized exclusive bursts, or long_fixed for FIXED bursts up to 256 beats.
  `define PM_MASTER_T(name, fixed, wrap, excls, beats) \
    typedef axi_test::axi_rand_master #(               \
      .AW                  (32      ),                 \
      .DW                  (64      ),                 \
      .IW                  (5       ),                 \
      .UW                  (2       ),                 \
      .TA                  (ApplTime),                 \
      .TT                  (TestTime),                 \
      .MAX_READ_TXNS       (8       ),                 \
      .MAX_WRITE_TXNS      (1       ),                 \
      .AX_MAX_WAIT_CYCLES  (4       ),                 \
      .W_MAX_WAIT_CYCLES   (2       ),                 \
      .RESP_MAX_WAIT_CYCLES(4       ),                 \
      .AXI_MAX_BURST_LEN   (beats   ),                 \
      .AXI_EXCLS           (excls   ),                 \
      .AXI_BURST_FIXED     (fixed   ),                 \
      .AXI_BURST_INCR      (1'b1    ),                 \
      .AXI_BURST_WRAP      (wrap    )                  \
    ) name;
  `PM_MASTER_T(pm_master_t, 1'b1, 1'b0, 1'b0, 16)
  `PM_MASTER_T(pm_incr_master_t, 1'b0, 1'b0, 1'b0, 256)
  `PM_MASTER_T(pm_wrap_master_t, 1'b1, 1'b1, 1'b0, 16)
  `PM_MASTER_T(pm_excl_master_t, 1'b1, 1'b0, 1'b1, 16)
  `PM_MASTER_T(pm_long_fixed_master_t, 1'b1, 1'b0, 1'b0, 256)
  `undef PM_MASTER_T

  typedef axi_test::axi_scoreboard #(
    .IW(5       ),
    .AW(32      ),
    .DW(64      ),
    .UW(2       ),
    .TT(TestTime)
  ) pm_scoreboard_t;

  initial begin : pm_run
    automatic string                 kind = "mixed";
    automatic pm_master_t            master;
    automatic pm_incr_master_t       incr_master;
    automatic pm_wrap_master_t       wrap_master;
    automatic pm_excl_master_t       excl_master;
    automatic pm_long_fixed_master_t long_fixed_master;
    automatic pm_scoreboard_t        scoreboard;

    void'($value$plusargs("pulp_mgr_kind=%s", kind));
    case (kind)
      "incr": begin
        incr_master = new(pm_dv);
        incr_master.add_memory_region(AxiWinBase, AxiWinBase + AxiWinBytes - 1,
                                      axi_pkg::NORMAL_NONCACHEABLE_BUFFERABLE);
        scoreboard = new(pm_dv);
      end
      "wrap": begin
        wrap_master = new(pm_dv);
        wrap_master.add_memory_region(AxiWinBase, AxiWinBase + AxiWinBytes - 1,
                                      axi_pkg::NORMAL_NONCACHEABLE_BUFFERABLE);
      end
      "excl": begin
        excl_master = new(pm_dv);
        excl_master.add_memory_region(AxiWinBase, AxiWinBase + AxiWinBytes - 1,
                                      axi_pkg::NORMAL_NONCACHEABLE_BUFFERABLE);
      end
      "long_fixed": begin
        long_fixed_master = new(pm_dv);
        long_fixed_master.add_memory_region(AxiWinBase, AxiWinBase + AxiWinBytes - 1,
                                            axi_pkg::NORMAL_NONCACHEABLE_BUFFERABLE);
      end
      default: begin
        master = new(pm_dv);
        master.add_memory_region(AxiWinBase, AxiWinBase + AxiWinBytes - 1,
                                 axi_pkg::NORMAL_NONCACHEABLE_BUFFERABLE);
      end
    endcase
    wait (pm_rst_n === 1'b1);
    if (scoreboard != null) begin
      scoreboard.monitor();
    end
    forever begin
      wait (pm_ctrl.start);
      pm_ctrl.start = 1'b0;
      // The scoreboard invalidates old bytes at B, but earlier reads may still return them (AMBA
      // AXI H.c A6.1). Check read data only in runs without writes.
      if (scoreboard != null && pm_ctrl.n_writes == 0) begin
        scoreboard.enable_read_check();
      end
      case (kind)
        "incr": begin
          incr_master.run(pm_ctrl.n_reads, pm_ctrl.n_writes);
        end
        "wrap": begin
          wrap_master.run(pm_ctrl.n_reads, pm_ctrl.n_writes);
        end
        "excl": begin
          excl_master.run(pm_ctrl.n_reads, pm_ctrl.n_writes);
        end
        "long_fixed": begin
          long_fixed_master.run(pm_ctrl.n_reads, pm_ctrl.n_writes);
        end
        default: begin
          master.run(pm_ctrl.n_reads, pm_ctrl.n_writes);
        end
      endcase
      pm_ctrl.runs_done++;
    end
  end

  // pulp_lite_mgr: pulp_axi AXI4-Lite driver to subordinate agent in AXI4-Lite mode
  AXI_LITE_DV #(
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(32)
  ) pl_dv (
    .clk_i(pl_clk)
  );
  lite32_req_t     pl_lite_req;
  lite32_resp_t    pl_lite_resp;
  axi32_id0_req_t  pl_req;
  axi32_id0_resp_t pl_resp;
  `AXI_LITE_ASSIGN_TO_REQ(pl_lite_req, pl_dv)
  `AXI_LITE_ASSIGN_FROM_RESP(pl_dv, pl_lite_resp)
  axi_agent_lite_to_full #(
    .DataWidth  (32              ),
    .lite_req_t (lite32_req_t    ),
    .lite_resp_t(lite32_resp_t   ),
    .req_t      (axi32_id0_req_t ),
    .resp_t     (axi32_id0_resp_t)
  ) u_pl_glue (
    .lite_req_i (pl_lite_req ),
    .lite_resp_o(pl_lite_resp),
    .req_o      (pl_req      ),
    .resp_i     (pl_resp     )
  );
  `AXI_AGENT_VIP(u_pl_sub, axi32_id0_req_t, axi32_id0_resp_t, 1, 32, 32, 1'b1, Subordinate, pl_clk,
                 pl_rst_n);
  assign u_pl_sub.axi_req = pl_req;
  assign pl_resp          = u_pl_sub.axi_resp;

  axi_agent_pulp_ctrl_if pl_ctrl();

  // Random unaligned addresses and strobes violate H.c A3.4.4. Use directed accesses through the
  // same driver. +pulp_lite_rand enables the random manager to reproduce the defect.
  typedef axi_test::axi_lite_rand_master #(
    .AW      (32                      ),
    .DW      (32                      ),
    .TA      (ApplTime                ),
    .TT      (TestTime                ),
    .MIN_ADDR(AxiWinBase              ),
    .MAX_ADDR(AxiWinBase + 255        )
  ) lite_master_t;

  initial begin : pl_run
    automatic lite_master_t master = new(pl_dv, "pl_master");

    master.reset();
    wait (pl_rst_n === 1'b1);
    if ($test$plusargs("pulp_lite_rand")) begin
      forever begin
        wait (pl_ctrl.start);
        pl_ctrl.start = 1'b0;
        master.run(pl_ctrl.n_reads, pl_ctrl.n_writes);
        pl_ctrl.runs_done++;
      end
    end
    forever begin
      automatic logic [31:0]    addr, rdata;
      automatic axi_pkg::resp_t resp;

      wait (pl_ctrl.op_write.size() > 0);
      addr = pl_ctrl.op_addr.pop_front();
      if (pl_ctrl.op_write.pop_front()) begin
        master.write(addr, axi_pkg::prot_t'(0), pl_ctrl.op_wdata.pop_front(),
                     pl_ctrl.op_wstrb.pop_front(), resp);
      end else begin
        void'(pl_ctrl.op_wdata.pop_front());
        void'(pl_ctrl.op_wstrb.pop_front());
        master.read(addr, axi_pkg::prot_t'(0), rdata, resp);
      end
      pl_ctrl.ops_done++;
    end
  end

  // sim_mem: manager agent to pulp_axi axi_sim_mem, with two pages that answer SLVERR and DECERR
  axi64_resp_t sm_resp;
  `AXI_AGENT_VIP(u_sm_mgr, axi64_req_t, axi64_resp_t, 5, 32, 64, 1'b0, Manager, sm_clk, sm_rst_n);
  assign u_sm_mgr.axi_resp = sm_resp;
  axi_sim_mem #(
    .AddrWidth        (32          ),
    .DataWidth        (64          ),
    .IdWidth          (5           ),
    .UserWidth        (2           ),
    .axi_req_t        (axi64_req_t ),
    .axi_rsp_t        (axi64_resp_t),
    .UninitializedData("random"    ),
    .ApplDelay        (ApplTime    ),
    .AcqDelay         (TestTime    )
  ) u_sm_mem (
    .clk_i             (sm_clk          ),
    .rst_ni            (sm_rst_n        ),
    .axi_req_i         (u_sm_mgr.axi_req),
    .axi_rsp_o         (sm_resp         ),
    .mon_w_valid_o     (                ),
    .mon_w_addr_o      (                ),
    .mon_w_data_o      (                ),
    .mon_w_id_o        (                ),
    .mon_w_user_o      (                ),
    .mon_w_beat_count_o(                ),
    .mon_w_last_o      (                ),
    .mon_r_valid_o     (                ),
    .mon_r_addr_o      (                ),
    .mon_r_data_o      (                ),
    .mon_r_id_o        (                ),
    .mon_r_user_o      (                ),
    .mon_r_beat_count_o(                ),
    .mon_r_last_o      (                )
  );

  initial begin : sm_error_pages
    for (int unsigned i = 0; i < 4096; i++) begin
      u_sm_mem.rerr[SimMemSlverrPage + i] = axi_pkg::RESP_SLVERR;
      u_sm_mem.werr[SimMemSlverrPage + i] = axi_pkg::RESP_SLVERR;
      u_sm_mem.rerr[SimMemDecerrPage + i] = axi_pkg::RESP_DECERR;
      u_sm_mem.werr[SimMemDecerrPage + i] = axi_pkg::RESP_DECERR;
    end
  end

  // axi_rand_slave on rand_slave reorders reads across IDs. MAPPED writes always get OKAY, and
  // RAND_RESP does not affect reads in four-state simulation, so all responses are OKAY.
  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(64),
    .AXI_ID_WIDTH  (5 ),
    .AXI_USER_WIDTH(2 )
  ) rs_dv (
    .clk_i(rs_clk)
  );
  axi64_resp_t rs_resp;
  `AXI_AGENT_VIP(u_rs_mgr, axi64_req_t, axi64_resp_t, 5, 32, 64, 1'b0, Manager, rs_clk, rs_rst_n);
  `AXI_ASSIGN_FROM_REQ(rs_dv, u_rs_mgr.axi_req)
  `AXI_ASSIGN_TO_RESP(rs_resp, rs_dv)
  assign u_rs_mgr.axi_resp = rs_resp;

  typedef axi_test::axi_rand_slave #(
    .AW                  (32      ),
    .DW                  (64      ),
    .IW                  (5       ),
    .UW                  (2       ),
    .TA                  (ApplTime),
    .TT                  (TestTime),
    .AX_MAX_WAIT_CYCLES  (4       ),
    .R_MAX_WAIT_CYCLES   (2       ),
    .RESP_MAX_WAIT_CYCLES(4       ),
    .MAPPED              (1'b1    )
  ) rs_slave_t;

  initial begin : rs_run
    automatic rs_slave_t slave = new(rs_dv);

    wait (rs_rst_n === 1'b1);
    slave.run();
  end

  axi_agent_pulp_ctrl_if rs_ctrl();

  // +pulp_repro_ar_4kb drives a read across 4KB on rand_slave, first with AWBURST FIXED, then INCR.
  // AXI_BUS_DV checks AR's 4KB rule only in the second case. Count completion in rs_ctrl.ops_done.
  initial begin : rs_ar_4kb_repro
    logic [1:0] aw_burst;

    if ($test$plusargs("pulp_repro_ar_4kb")) begin
      // The forces below change manager outputs ApplTime after the edge, as a pulp_axi model does
      u_rs_mgr.u_axi_if.set_mgr_max_output_delay_ps(ApplTimePs);
      wait (rs_rst_n === 1'b1);
      repeat (10) begin
        @(posedge rs_clk);
      end
      force u_rs_mgr.u_axi_if.r_if.rready   = 1'b1;
      force u_rs_mgr.u_axi_if.aw_if.awburst = aw_burst;
      for (int unsigned pass = 0; pass < 2; pass++) begin
        @(posedge rs_clk);
        #(ApplTime);
        aw_burst = (pass == 0) ? axi_pkg::BURST_FIXED : axi_pkg::BURST_INCR;
        force u_rs_mgr.u_axi_if.ar_if.arid     = '0;
        force u_rs_mgr.u_axi_if.ar_if.araddr   = AxiWinBase + 32'h1000 - 16;
        force u_rs_mgr.u_axi_if.ar_if.arlen    = 8'd3;
        force u_rs_mgr.u_axi_if.ar_if.arsize   = 3'd3;
        force u_rs_mgr.u_axi_if.ar_if.arburst  = axi_pkg::BURST_INCR;
        force u_rs_mgr.u_axi_if.ar_if.arlock   = 1'b0;
        force u_rs_mgr.u_axi_if.ar_if.arcache  = '0;
        force u_rs_mgr.u_axi_if.ar_if.arprot   = '0;
        force u_rs_mgr.u_axi_if.ar_if.arqos    = '0;
        force u_rs_mgr.u_axi_if.ar_if.arregion = '0;
        force u_rs_mgr.u_axi_if.ar_if.aruser   = '0;
        force u_rs_mgr.u_axi_if.ar_if.arvalid  = 1'b1;
        do begin
          @(posedge rs_clk);
        end while (rs_dv.ar_ready !== 1'b1);
        #(ApplTime);
        force u_rs_mgr.u_axi_if.ar_if.arvalid = 1'b0;
        repeat (20) begin
          @(posedge rs_clk);
        end
      end
      rs_ctrl.ops_done++;
    end
  end

  // lite_regs: manager agent in AXI4-Lite mode to pulp_axi axi_lite_regs
  axi64_id0_req_t  ls_req;
  axi64_id0_resp_t ls_resp;
  lite64_req_t     ls_lite_req;
  lite64_resp_t    ls_lite_resp;
  `AXI_AGENT_VIP(u_ls_mgr, axi64_id0_req_t, axi64_id0_resp_t, 1, 32, 64, 1'b1, Manager, ls_clk,
                 ls_rst_n);
  assign ls_req            = u_ls_mgr.axi_req;
  assign u_ls_mgr.axi_resp = ls_resp;
  axi_agent_full_to_lite #(
    .lite_req_t (lite64_req_t    ),
    .lite_resp_t(lite64_resp_t   ),
    .req_t      (axi64_id0_req_t ),
    .resp_t     (axi64_id0_resp_t)
  ) u_ls_glue (
    .req_i      (ls_req      ),
    .resp_o     (ls_resp     ),
    .lite_req_o (ls_lite_req ),
    .lite_resp_i(ls_lite_resp)
  );
  axi_lite_regs #(
    .RegNumBytes (LiteRegsBytes),
    .AxiAddrWidth(32           ),
    .AxiDataWidth(64           ),
    .req_lite_t  (lite64_req_t ),
    .resp_lite_t (lite64_resp_t)
  ) u_ls_regs (
    .clk_i      (ls_clk      ),
    .rst_ni     (ls_rst_n    ),
    .axi_req_i  (ls_lite_req ),
    .axi_resp_o (ls_lite_resp),
    .wr_active_o(            ),
    .rd_active_o(            ),
    .reg_d_i    ('0          ),
    .reg_load_i ('0          ),
    .reg_q_o    (            )
  );

  // lite_rand_slave: AXI4-Lite manager to axi_lite_rand_slave, with random data and responses and
  // no memory
  AXI_LITE_DV #(
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(32)
  ) lr_dv (
    .clk_i(lr_clk)
  );
  axi32_id0_req_t  lr_req;
  axi32_id0_resp_t lr_resp;
  lite32_req_t     lr_lite_req;
  lite32_resp_t    lr_lite_resp;
  `AXI_AGENT_VIP(u_lr_mgr, axi32_id0_req_t, axi32_id0_resp_t, 1, 32, 32, 1'b1, Manager, lr_clk,
                 lr_rst_n);
  assign lr_req            = u_lr_mgr.axi_req;
  assign u_lr_mgr.axi_resp = lr_resp;
  axi_agent_full_to_lite #(
    .lite_req_t (lite32_req_t    ),
    .lite_resp_t(lite32_resp_t   ),
    .req_t      (axi32_id0_req_t ),
    .resp_t     (axi32_id0_resp_t)
  ) u_lr_glue (
    .req_i      (lr_req      ),
    .resp_o     (lr_resp     ),
    .lite_req_o (lr_lite_req ),
    .lite_resp_i(lr_lite_resp)
  );
  `AXI_LITE_ASSIGN_FROM_REQ(lr_dv, lr_lite_req)
  `AXI_LITE_ASSIGN_TO_RESP(lr_lite_resp, lr_dv)

  typedef axi_test::axi_lite_rand_slave #(
    .AW                  (32      ),
    .DW                  (32      ),
    .TA                  (ApplTime),
    .TT                  (TestTime),
    .AX_MAX_WAIT_CYCLES  (4       ),
    .R_MAX_WAIT_CYCLES   (2       ),
    .RESP_MAX_WAIT_CYCLES(4       )
  ) lr_slave_t;

  initial begin : lr_run
    automatic lr_slave_t slave = new(lr_dv, "lr_slave");

    slave.reset();
    wait (lr_rst_n === 1'b1);
    slave.run();
  end

  // lite_bridge: manager agent to pulp_axi axi_to_axi_lite to subordinate agent in AXI4-Lite mode
  axi64_req_t      br_req;
  axi64_resp_t     br_resp;
  lite64_req_t     br_lite_req;
  lite64_resp_t    br_lite_resp;
  axi64_id0_req_t  br_sub_req;
  axi64_id0_resp_t br_sub_resp;
  `AXI_AGENT_VIP(u_br_mgr, axi64_req_t, axi64_resp_t, 5, 32, 64, 1'b0, Manager, br_clk, br_rst_n);
  assign br_req            = u_br_mgr.axi_req;
  assign u_br_mgr.axi_resp = br_resp;
  axi_to_axi_lite #(
    .AxiAddrWidth   (32           ),
    .AxiDataWidth   (64           ),
    .AxiIdWidth     (5            ),
    .AxiUserWidth   (2            ),
    .AxiMaxWriteTxns(4            ),
    .AxiMaxReadTxns (4            ),
    .full_req_t     (axi64_req_t  ),
    .full_resp_t    (axi64_resp_t ),
    .lite_req_t     (lite64_req_t ),
    .lite_resp_t    (lite64_resp_t)
  ) u_br_bridge (
    .clk_i     (br_clk      ),
    .rst_ni    (br_rst_n    ),
    .test_i    (1'b0        ),
    .slv_req_i (br_req      ),
    .slv_resp_o(br_resp     ),
    .mst_req_o (br_lite_req ),
    .mst_resp_i(br_lite_resp)
  );
  axi_agent_lite_to_full #(
    .DataWidth  (64              ),
    .lite_req_t (lite64_req_t    ),
    .lite_resp_t(lite64_resp_t   ),
    .req_t      (axi64_id0_req_t ),
    .resp_t     (axi64_id0_resp_t)
  ) u_br_glue (
    .lite_req_i (br_lite_req ),
    .lite_resp_o(br_lite_resp),
    .req_o      (br_sub_req  ),
    .resp_i     (br_sub_resp )
  );
  `AXI_AGENT_VIP(u_br_sub, axi64_id0_req_t, axi64_id0_resp_t, 1, 32, 64, 1'b1, Subordinate, br_clk,
                 br_rst_n);
  assign u_br_sub.axi_req = br_sub_req;
  assign br_sub_resp      = u_br_sub.axi_resp;

  // lite_to_axi: AXI4-Lite driver through axi_lite_to_axi to the subordinate agent
  AXI_LITE_DV #(
    .AXI_ADDR_WIDTH(32),
    .AXI_DATA_WIDTH(32)
  ) lt_dv (
    .clk_i(lt_clk)
  );
  lite32_req_t     lt_lite_req;
  lite32_resp_t    lt_lite_resp;
  axi32_id0_req_t  lt_req;
  axi32_id0_resp_t lt_resp;
  `AXI_LITE_ASSIGN_TO_REQ(lt_lite_req, lt_dv)
  `AXI_LITE_ASSIGN_FROM_RESP(lt_dv, lt_lite_resp)
  axi_lite_to_axi #(
    .AxiDataWidth(32              ),
    .req_lite_t  (lite32_req_t    ),
    .resp_lite_t (lite32_resp_t   ),
    .axi_req_t   (axi32_id0_req_t ),
    .axi_resp_t  (axi32_id0_resp_t)
  ) u_lt_bridge (
    .slv_req_lite_i (lt_lite_req ),
    .slv_resp_lite_o(lt_lite_resp),
    .slv_aw_cache_i ('0          ),
    .slv_ar_cache_i ('0          ),
    .mst_req_o      (lt_req      ),
    .mst_resp_i     (lt_resp     )
  );
  `AXI_AGENT_VIP(u_lt_sub, axi32_id0_req_t, axi32_id0_resp_t, 1, 32, 32, 1'b0, Subordinate, lt_clk,
                 lt_rst_n);
  assign u_lt_sub.axi_req = lt_req;
  assign lt_resp          = u_lt_sub.axi_resp;

  axi_agent_pulp_ctrl_if lt_ctrl();

  initial begin : lt_run
    automatic lite_master_t master = new(lt_dv, "lt_master");

    master.reset();
    wait (lt_rst_n === 1'b1);
    forever begin
      automatic logic [31:0]    addr, rdata;
      automatic axi_pkg::resp_t resp;

      wait (lt_ctrl.op_write.size() > 0);
      addr = lt_ctrl.op_addr.pop_front();
      if (lt_ctrl.op_write.pop_front()) begin
        master.write(addr, axi_pkg::prot_t'(0), lt_ctrl.op_wdata.pop_front(),
                     lt_ctrl.op_wstrb.pop_front(), resp);
      end else begin
        void'(lt_ctrl.op_wdata.pop_front());
        void'(lt_ctrl.op_wstrb.pop_front());
        master.read(addr, axi_pkg::prot_t'(0), rdata, resp);
      end
      lt_ctrl.ops_done++;
    end
  end

  // xbar: two managers and three subordinates through axi_xbar, with the transaction limits,
  // latency mode and pipeline of mocha's crossbar
  localparam axi_pkg::xbar_cfg_t XbarCfg = '{
    NoSlvPorts:         XbarNumMgrs,
    NoMstPorts:         XbarNumSubs,
    MaxMstTrans:        32'd10,
    MaxSlvTrans:        32'd6,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_AX,
    PipelineStages:     32'd1,
    AxiIdWidthSlvPorts: XbarMgrIdBits,
    AxiIdUsedSlvPorts:  32'd1,
    UniqueIds:          1'b0,
    AxiAddrWidth:       32'd64,
    AxiDataWidth:       32'd64,
    NoAddrRules:        XbarNumSubs
  };

  xbar_mgr_req_t  [XbarNumMgrs-1:0] xb_mgr_req;
  xbar_mgr_resp_t [XbarNumMgrs-1:0] xb_mgr_resp;
  xbar_sub_req_t  [XbarNumSubs-1:0] xb_sub_req;
  xbar_sub_resp_t [XbarNumSubs-1:0] xb_sub_resp;
  axi_pkg::xbar_rule_64_t [XbarNumSubs-1:0] xb_addr_map;

  for (genvar s = 0; s < XbarNumSubs; s++) begin : gen_xb_rules
    assign xb_addr_map[s] = '{
      idx:        s,
      start_addr: AxiWinBase + s * XbarSubBytes,
      end_addr:   AxiWinBase + (s + 1) * XbarSubBytes
    };
  end

  `AXI_AGENT_VIP(u_xb_mgr0, xbar_mgr_req_t, xbar_mgr_resp_t, XbarMgrIdBits, 64, 64, 1'b0, Manager,
                 xb_clk, xb_rst_n);
  `AXI_AGENT_VIP(u_xb_mgr1, xbar_mgr_req_t, xbar_mgr_resp_t, XbarMgrIdBits, 64, 64, 1'b0, Manager,
                 xb_clk, xb_rst_n);
  `AXI_AGENT_VIP(u_xb_sub0, xbar_sub_req_t, xbar_sub_resp_t, XbarMgrIdBits + 1, 64, 64, 1'b0,
                 Subordinate, xb_clk, xb_rst_n);
  `AXI_AGENT_VIP(u_xb_sub1, xbar_sub_req_t, xbar_sub_resp_t, XbarMgrIdBits + 1, 64, 64, 1'b0,
                 Subordinate, xb_clk, xb_rst_n);
  `AXI_AGENT_VIP(u_xb_sub2, xbar_sub_req_t, xbar_sub_resp_t, XbarMgrIdBits + 1, 64, 64, 1'b0,
                 Subordinate, xb_clk, xb_rst_n);
  assign xb_mgr_req[0]      = u_xb_mgr0.axi_req;
  assign xb_mgr_req[1]      = u_xb_mgr1.axi_req;
  assign u_xb_mgr0.axi_resp = xb_mgr_resp[0];
  assign u_xb_mgr1.axi_resp = xb_mgr_resp[1];
  assign u_xb_sub0.axi_req  = xb_sub_req[0];
  assign u_xb_sub1.axi_req  = xb_sub_req[1];
  assign u_xb_sub2.axi_req  = xb_sub_req[2];
  assign xb_sub_resp[0]     = u_xb_sub0.axi_resp;
  assign xb_sub_resp[1]     = u_xb_sub1.axi_resp;
  assign xb_sub_resp[2]     = u_xb_sub2.axi_resp;

  axi_xbar #(
    .Cfg          (XbarCfg                ),
    .ATOPs        (1'b0                   ),
    .slv_aw_chan_t(xbar_mgr_aw_chan_t     ),
    .mst_aw_chan_t(xbar_sub_aw_chan_t     ),
    .w_chan_t     (xbar_mgr_w_chan_t      ),
    .slv_b_chan_t (xbar_mgr_b_chan_t      ),
    .mst_b_chan_t (xbar_sub_b_chan_t      ),
    .slv_ar_chan_t(xbar_mgr_ar_chan_t     ),
    .mst_ar_chan_t(xbar_sub_ar_chan_t     ),
    .slv_r_chan_t (xbar_mgr_r_chan_t      ),
    .mst_r_chan_t (xbar_sub_r_chan_t      ),
    .slv_req_t    (xbar_mgr_req_t         ),
    .slv_resp_t   (xbar_mgr_resp_t        ),
    .mst_req_t    (xbar_sub_req_t         ),
    .mst_resp_t   (xbar_sub_resp_t        ),
    .rule_t       (axi_pkg::xbar_rule_64_t)
  ) u_xb_xbar (
    .clk_i                (xb_clk     ),
    .rst_ni               (xb_rst_n   ),
    .test_i               (1'b0       ),
    .slv_ports_req_i      (xb_mgr_req ),
    .slv_ports_resp_o     (xb_mgr_resp),
    .mst_ports_req_o      (xb_sub_req ),
    .mst_ports_resp_i     (xb_sub_resp),
    .addr_map_i           (xb_addr_map),
    .en_default_mst_port_i('0         ),
    .default_mst_port_i   ('0         )
  );

  `undef AXI_AGENT_VIP

  initial begin
    string                         link;
    int unsigned                   data_width;
    int unsigned                   id_width;
    int unsigned                   addr_width;
    int unsigned                   user_width;
    bit                            is_lite;
    virtual clk_rst_if             clk_rst_vif;
    axi_vif_t                      mgr_vifs[XbarNumMgrs];
    axi_vif_t                      sub_vifs[XbarNumSubs];
    int unsigned                   num_mgrs;
    int unsigned                   num_subs;
    virtual axi_agent_probe_if     probe_vif;
    virtual axi_agent_probe_if     bus_probes[$];
    virtual axi_agent_pulp_ctrl_if pulp_ctrl_vif;

    // Configure agent-link widths at run time to share one build
    link       = "agent";
    data_width = 64;
    id_width   = 5;
    addr_width = 32;
    user_width = 2;
    is_lite    = 1'b0;
    num_mgrs   = 1;
    num_subs   = 1;
    void'($value$plusargs("axi_link=%s", link));
    void'($value$plusargs("axi_data_width=%0d", data_width));
    void'($value$plusargs("axi_id_width=%0d", id_width));
    void'($value$plusargs("axi_addr_width=%0d", addr_width));
    void'($value$plusargs("axi_user_width=%0d", user_width));
    void'($value$plusargs("axi_lite=%0b", is_lite));

    // Match both instances' bus properties so width masks agree
    u_agent_mgr_if.set_if_mode(Manager);
    u_agent_sub_if.set_if_mode(Subordinate);
    u_agent_mgr_if.set_user_width(user_width);
    u_agent_mgr_if.set_id_width(id_width);
    u_agent_mgr_if.set_addr_width(addr_width);
    u_agent_mgr_if.set_data_width(data_width);
    u_agent_mgr_if.set_lite(is_lite);
    u_agent_sub_if.set_user_width(user_width);
    u_agent_sub_if.set_id_width(id_width);
    u_agent_sub_if.set_addr_width(addr_width);
    u_agent_sub_if.set_data_width(data_width);
    u_agent_sub_if.set_lite(is_lite);
    if ($test$plusargs("axi_undriven_footprint")) begin
      conn_id_bits   = is_lite ? 0 : id_width;
      conn_addr_bits = addr_width;
      conn_strb_bits = data_width / 8;
    end
    x_unstrobed_wdata = $test$plusargs("axi_x_unstrobed_wdata");

    // pulp_axi models drive their side ApplTime after each rising edge
    u_pm_sub.u_axi_if.set_mgr_max_output_delay_ps(ApplTimePs);
    u_pl_sub.u_axi_if.set_mgr_max_output_delay_ps(ApplTimePs);
    u_lt_sub.u_axi_if.set_mgr_max_output_delay_ps(ApplTimePs);
    u_sm_mgr.u_axi_if.set_sub_max_output_delay_ps(ApplTimePs);
    u_rs_mgr.u_axi_if.set_sub_max_output_delay_ps(ApplTimePs);
    u_lr_mgr.u_axi_if.set_sub_max_output_delay_ps(ApplTimePs);

    case (link)
      "agent": begin
        clk_rst_vif = agent_clk_rst_if;
        mgr_vifs[0] = u_agent_mgr_if;
        sub_vifs[0] = u_agent_sub_if;
        probe_vif   = u_agent_mgr_if.u_probe;
        bus_probes  = '{u_agent_mgr_if.u_probe, u_agent_sub_if.u_probe};
      end
      "pulp_mgr": begin
        clk_rst_vif   = pm_clk_rst_if;
        mgr_vifs[0]   = u_pm_sub.u_axi_if;
        sub_vifs[0]   = u_pm_sub.u_axi_if;
        probe_vif     = u_pm_sub.u_axi_if.u_probe;
        pulp_ctrl_vif = pm_ctrl;
      end
      "pulp_lite_mgr": begin
        clk_rst_vif   = pl_clk_rst_if;
        mgr_vifs[0]   = u_pl_sub.u_axi_if;
        sub_vifs[0]   = u_pl_sub.u_axi_if;
        probe_vif     = u_pl_sub.u_axi_if.u_probe;
        pulp_ctrl_vif = pl_ctrl;
      end
      "sim_mem": begin
        clk_rst_vif = sm_clk_rst_if;
        mgr_vifs[0] = u_sm_mgr.u_axi_if;
        sub_vifs[0] = u_sm_mgr.u_axi_if;
        probe_vif   = u_sm_mgr.u_axi_if.u_probe;
      end
      "rand_slave": begin
        clk_rst_vif   = rs_clk_rst_if;
        mgr_vifs[0]   = u_rs_mgr.u_axi_if;
        sub_vifs[0]   = u_rs_mgr.u_axi_if;
        probe_vif     = u_rs_mgr.u_axi_if.u_probe;
        pulp_ctrl_vif = rs_ctrl;
      end
      "lite_regs": begin
        clk_rst_vif = ls_clk_rst_if;
        mgr_vifs[0] = u_ls_mgr.u_axi_if;
        sub_vifs[0] = u_ls_mgr.u_axi_if;
        probe_vif   = u_ls_mgr.u_axi_if.u_probe;
      end
      "lite_rand_slave": begin
        clk_rst_vif = lr_clk_rst_if;
        mgr_vifs[0] = u_lr_mgr.u_axi_if;
        sub_vifs[0] = u_lr_mgr.u_axi_if;
        probe_vif   = u_lr_mgr.u_axi_if.u_probe;
      end
      "lite_bridge": begin
        clk_rst_vif = br_clk_rst_if;
        mgr_vifs[0] = u_br_mgr.u_axi_if;
        sub_vifs[0] = u_br_sub.u_axi_if;
        probe_vif   = u_br_mgr.u_axi_if.u_probe;
        bus_probes  = '{u_br_mgr.u_axi_if.u_probe, u_br_sub.u_axi_if.u_probe};
      end
      "lite_to_axi": begin
        clk_rst_vif   = lt_clk_rst_if;
        mgr_vifs[0]   = u_lt_sub.u_axi_if;
        sub_vifs[0]   = u_lt_sub.u_axi_if;
        probe_vif     = u_lt_sub.u_axi_if.u_probe;
        pulp_ctrl_vif = lt_ctrl;
      end
      "xbar": begin
        clk_rst_vif = xb_clk_rst_if;
        num_mgrs    = XbarNumMgrs;
        num_subs    = XbarNumSubs;
        mgr_vifs[0] = u_xb_mgr0.u_axi_if;
        mgr_vifs[1] = u_xb_mgr1.u_axi_if;
        sub_vifs[0] = u_xb_sub0.u_axi_if;
        sub_vifs[1] = u_xb_sub1.u_axi_if;
        sub_vifs[2] = u_xb_sub2.u_axi_if;
        probe_vif   = u_xb_mgr0.u_axi_if.u_probe;
        bus_probes  = '{u_xb_mgr0.u_axi_if.u_probe, u_xb_mgr1.u_axi_if.u_probe,
                        u_xb_sub0.u_axi_if.u_probe, u_xb_sub1.u_axi_if.u_probe,
                        u_xb_sub2.u_axi_if.u_probe};
      end
      default: begin
        `uvm_fatal("tb", $sformatf("There is no link called %0s.", link))
      end
    endcase

    clk_rst_vif.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*.env*", "clk_rst_vif", clk_rst_vif);
    for (int unsigned i = 0; i < num_mgrs; i++) begin
      uvm_config_db#(axi_vif_t)::set(null, "*.env", $sformatf("mgr_vif_%0d", i), mgr_vifs[i]);
    end
    for (int unsigned i = 0; i < num_subs; i++) begin
      uvm_config_db#(axi_vif_t)::set(null, "*.env", $sformatf("sub_vif_%0d", i), sub_vifs[i]);
    end
    uvm_config_db#(virtual axi_agent_probe_if)::set(null, "*.env", "probe_vif", probe_vif);

    // Publish a probe for every bus of the link, for the checks at the end of the test. A link on
    // one bus has only probe_vif.
    if (bus_probes.size() == 0) begin
      bus_probes.push_back(probe_vif);
    end
    foreach (bus_probes[i]) begin
      uvm_config_db#(virtual axi_agent_probe_if)::set(null, "*.env",
                                                      $sformatf("bus_probe_vif_%0d", i),
                                                      bus_probes[i]);
    end
    if (pulp_ctrl_vif != null) begin
      uvm_config_db#(virtual axi_agent_pulp_ctrl_if)::set(null, "*.env", "pulp_ctrl_vif",
                                                          pulp_ctrl_vif);
    end

    $timeformat(-12, 0, " ps", 12);
    run_test();
  end

endmodule : tb
