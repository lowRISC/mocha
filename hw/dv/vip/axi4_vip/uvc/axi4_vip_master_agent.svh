`ifndef __AXI4_VIP_MASTER_AGENT_SVH
`define __AXI4_VIP_MASTER_AGENT_SVH

class axi4_vip_master_agent extends uvm_agent;

  `uvm_component_utils(axi4_vip_master_agent)

  axi4_vip_agent_config m_cfg;

  axi4_vip_monitor      m_monitor;
  axi4_vip_driver       m_driver;
  axi4_vip_sequencer    m_sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!uvm_config_db#(axi4_vip_agent_config)::get(this,"","m_cfg",m_cfg)) begin
      `uvm_fatal("NOCFG", {"Configuration item  must be set for: ", get_full_name(), "m_cfg"})
    end

    m_monitor = axi4_vip_monitor::type_id::create("m_monitor", this);

    if(m_cfg.m_active_passive == UVM_ACTIVE) begin
      m_driver    = axi4_vip_driver   ::type_id::create("m_driver", this);
      m_sequencer = axi4_vip_sequencer::type_id::create("m_sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    if(m_cfg.m_active_passive == UVM_ACTIVE)
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
  endfunction

endclass

`endif // __AXI4_VIP_MASTER_AGENT_SVH