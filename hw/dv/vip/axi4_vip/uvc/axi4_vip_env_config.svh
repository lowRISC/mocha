`ifndef AXI4_VIP_ENV_CONFIG_SVH
`define AXI4_VIP_ENV_CONFIG_SVH

class axi4_vip_env_config extends uvm_object;

  `uvm_object_utils(axi4_vip_env_config)

  int unsigned num_masters = 1;
  int unsigned num_slaves  = 1;

  axi4_vip_agent_config master_cfgs[];
  axi4_vip_agent_config slave_cfgs[];

  function new(string name="axi4_vip_env_config");
    super.new(name);
  endfunction

endclass 

`endif // AXI4_VIP_ENV_CONFIG_SVH