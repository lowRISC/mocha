`ifndef __AXI4_VIP_PKG_SV
`define __AXI4_VIP_PKG_SV

`include "axi4_vip_if.sv"

package axi4_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "axi4_vip_defines.svh"
  `include "axi4_vip_types.svh"

  `include "axi4_vip_agent_config.svh"
  `include "axi4_vip_env_config.svh"

  `include "axi4_vip_transaction.svh"

  `include "axi4_vip_driver.svh"
  `include "axi4_vip_sequencer.svh"

  `include "axi4_vip_monitor.svh"
  `include "axi4_vip_master_agent.svh"
  `include "axi4_vip_slave_agent.svh"

  `include "axi4_vip_env.svh"

endpackage

`endif // __AXI4_VIP_PKG_SV