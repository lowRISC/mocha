`ifndef AXI4_VIP_ENV_SVH
`define AXI4_VIP_ENV_SVH

class axi4_vip_env extends uvm_env;

  `uvm_component_utils(axi4_vip_env)

  axi4_vip_env_config cfg;

  axi4_vip_master_agent masters[];
  axi4_vip_slave_agent  slaves[];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db#(axi4_vip_env_config)::get(this,"","cfg",cfg))
      `uvm_fatal("CFG","No env config")

    masters = new[cfg.num_masters];
    slaves  = new[cfg.num_slaves];

    foreach(masters[i]) begin
      masters[i] = axi4_vip_master_agent::type_id::create($sformatf("master_%0d",i), this);
      uvm_config_db#(axi4_vip_agent_config)::set(this,
        masters[i].get_full_name(), "cfg", cfg.master_cfgs[i]);
    end

    foreach(slaves[i]) begin
      slaves[i] = axi4_vip_slave_agent::type_id::create($sformatf("slave_%0d",i), this);
      uvm_config_db#(axi4_vip_agent_config)::set(this,
        slaves[i].get_full_name(), "cfg", cfg.slave_cfgs[i]);
    end
  endfunction

endclass

`endif // AXI4_VIP_ENV_SVH