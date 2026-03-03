`ifndef AXI4_VIP_SEQUENCER_SVH
`define AXI4_VIP_SEQUENCER_SVH

class axi4_vip_sequencer extends uvm_sequencer #(axi4_vip_transaction);

  `uvm_component_utils(axi4_vip_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass

`endif // AXI4_VIP_SEQUENCER_SVH