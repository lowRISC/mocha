`ifndef AXI4_VIP_AGENT_CONFIG_SVH
`define AXI4_VIP_AGENT_CONFIG_SVH

class axi4_vip_agent_config extends uvm_object;

  `uvm_object_utils(axi4_vip_agent_config)

  uvm_active_passive_enum m_active_passive = UVM_PASSIVE;

  // actual bus widths (<= max defines)
  string       m_inst_id       = "AXI4";
  int unsigned m_id_width      =  16;
  int unsigned m_addr_width    =  64;
  int unsigned m_data_width    = 512;
  int unsigned m_user_width    =  32;
  int unsigned m_region_width  =   8;
  int unsigned m_qos_width     =   8;

  function new(string name="axi4_vip_agent_config");
    super.new(name);
  endfunction

endclass

`endif // AXI4_VIP_AGENT_CONFIG_SVH