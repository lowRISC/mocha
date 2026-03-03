`ifndef AXI4_VIP_TRANSACTION_SVH
`define AXI4_VIP_TRANSACTION_SVH

class axi4_vip_transaction extends uvm_sequence_item;

  // observation type
  t_axi_obs obs_kind;
  t_axi_dir dir;

  // -------------------------------------------------
  // Write Address Channel
  // -------------------------------------------------
  rand bit [`AXI4_MAX_ID_WIDTH-1:0]     awid;
  rand bit [`AXI4_MAX_ADDR_WIDTH-1:0]   awaddr;
  rand bit [7:0]                        awlen;
  rand bit [2:0]                        awsize;
  rand bit [1:0]                        awburst;
  rand bit                              awlock;
  rand bit [3:0]                        awcache;
  rand bit [2:0]                        awprot;
  rand bit [`AXI4_MAX_QOS_WIDTH-1:0]    awqos;
  rand bit [`AXI4_MAX_REGION_WIDTH-1:0] awregion;
  rand bit [`AXI4_MAX_USER_WIDTH-1:0]   awuser;

  // -------------------------------------------------
  // Write Data Channel (Queues for multi-beat bursts)
  // -------------------------------------------------
  rand bit [`AXI4_MAX_DATA_WIDTH-1:0]   wdata[$];
  rand bit [`AXI4_MAX_DATA_WIDTH/8-1:0] wstrb[$];
  rand bit                              wlast[$];
  rand bit [`AXI4_MAX_USER_WIDTH-1:0]   wuser[$];

  // -------------------------------------------------
  // Write Response Channel
  // -------------------------------------------------
  rand bit [`AXI4_MAX_ID_WIDTH-1:0]     bid;
  rand bit [1:0]                        bresp;
  rand bit [`AXI4_MAX_USER_WIDTH-1:0]   buser;

  // -------------------------------------------------
  // Read Address Channel
  // -------------------------------------------------
  rand bit [`AXI4_MAX_ID_WIDTH-1:0]     arid;
  rand bit [`AXI4_MAX_ADDR_WIDTH-1:0]   araddr;
  rand bit [7:0]                        arlen;
  rand bit [2:0]                        arsize;
  rand bit [1:0]                        arburst;
  rand bit                              arlock;
  rand bit [3:0]                        arcache;
  rand bit [2:0]                        arprot;
  rand bit [`AXI4_MAX_QOS_WIDTH-1:0]    arqos;
  rand bit [`AXI4_MAX_REGION_WIDTH-1:0] arregion;
  rand bit [`AXI4_MAX_USER_WIDTH-1:0]   aruser;

  // -------------------------------------------------
  // Read Data Channel
  // -------------------------------------------------
  rand bit [`AXI4_MAX_ID_WIDTH-1:0]     rid;
  rand bit [`AXI4_MAX_DATA_WIDTH-1:0]   rdata[$];
  rand bit [1:0]                        rresp[$];
  rand bit                              rlast[$];
  rand bit [`AXI4_MAX_USER_WIDTH-1:0]   ruser[$];

  // -------------------------------------------------
  // UVM Automation Macros
  // -------------------------------------------------
  `uvm_object_utils_begin(axi4_vip_transaction)
    `uvm_field_enum(t_axi_obs, obs_kind, UVM_ALL_ON)
    `uvm_field_enum(t_axi_dir, dir,      UVM_ALL_ON)
    
    // Write Address
    `uvm_field_int(awid,     UVM_ALL_ON)
    `uvm_field_int(awaddr,   UVM_ALL_ON)
    `uvm_field_int(awlen,    UVM_ALL_ON)
    `uvm_field_int(awsize,   UVM_ALL_ON)
    `uvm_field_int(awburst,  UVM_ALL_ON)
    `uvm_field_int(awlock,   UVM_ALL_ON)
    `uvm_field_int(awcache,  UVM_ALL_ON)
    `uvm_field_int(awprot,   UVM_ALL_ON)
    `uvm_field_int(awqos,    UVM_ALL_ON)
    `uvm_field_int(awregion, UVM_ALL_ON)
    `uvm_field_int(awuser,   UVM_ALL_ON)

    // Write Data (Queues)
    `uvm_field_queue_int(wdata, UVM_ALL_ON)
    `uvm_field_queue_int(wstrb, UVM_ALL_ON)
    `uvm_field_queue_int(wlast, UVM_ALL_ON)
    `uvm_field_queue_int(wuser, UVM_ALL_ON)

    // Write Response
    `uvm_field_int(bid,   UVM_ALL_ON)
    `uvm_field_int(bresp, UVM_ALL_ON)
    `uvm_field_int(buser, UVM_ALL_ON)

    // Read Address
    `uvm_field_int(arid,     UVM_ALL_ON)
    `uvm_field_int(araddr,   UVM_ALL_ON)
    `uvm_field_int(arlen,    UVM_ALL_ON)
    `uvm_field_int(arsize,   UVM_ALL_ON)
    `uvm_field_int(arburst,  UVM_ALL_ON)
    `uvm_field_int(arlock,   UVM_ALL_ON)
    `uvm_field_int(arcache,  UVM_ALL_ON)
    `uvm_field_int(arprot,   UVM_ALL_ON)
    `uvm_field_int(arqos,    UVM_ALL_ON)
    `uvm_field_int(arregion, UVM_ALL_ON)
    `uvm_field_int(aruser,   UVM_ALL_ON)

    // Read Data (Queues)
    `uvm_field_int(rid,       UVM_ALL_ON)
    `uvm_field_queue_int(rdata, UVM_ALL_ON)
    `uvm_field_queue_int(rresp, UVM_ALL_ON)
    `uvm_field_queue_int(rlast, UVM_ALL_ON)
    `uvm_field_queue_int(ruser, UVM_ALL_ON)
  `uvm_object_utils_end

  // -------------------------------------------------
  // Constraints (Basic AXI4 Sanity)
  // -------------------------------------------------
  constraint c_awlen_wdata_match {
    if (dir == AXI_WRITE) {
      wdata.size() == (awlen + 1);
      wstrb.size() == wdata.size();
      wlast.size() == wdata.size();
      foreach(wlast[i]) wlast[i] == (i == awlen);
    }
  }

  constraint c_arlen_rdata_match {
    if (dir == AXI_READ) {
      rdata.size() == (arlen + 1);
      rresp.size() == rdata.size();
      rlast.size() == rdata.size();
      foreach(rlast[i]) rlast[i] == (i == arlen);
    }
  }

  function new(string name="axi4_vip_transaction");
    super.new(name);
  endfunction

endclass

`endif