`ifndef AXI4_VIP_DRIVER_SVH
`define AXI4_VIP_DRIVER_SVH

class axi4_vip_driver extends uvm_driver #(axi4_vip_transaction);

  `uvm_component_utils(axi4_vip_driver)

  axi4_vip_agent_config m_cfg;
  virtual axi4_vip_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (! uvm_config_db #(axi4_vip_agent_config)::get(this, "", "m_cfg", m_cfg)) begin
       `uvm_fatal("NOCFG", {"Configuration item  must be set for: ", get_full_name(), "m_cfg"})
    end

    if (! uvm_config_db #(virtual interface axi4_vip_if)::get(this, get_full_name(),"vif", vif)) begin
      `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".vif"})
    end
  endfunction: build_phase

  task run_phase(uvm_phase phase);
    forever begin
      // TODO: Placeholder
      seq_item_port.get_next_item(req);
      seq_item_port.item_done();
    end
  endtask

endclass 

`endif // AXI4_VIP_DRIVER_SVH