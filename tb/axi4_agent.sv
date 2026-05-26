`ifndef AXI4_AGENT_SV
`define AXI4_AGENT_SV
class axi4_agent extends uvm_agent;
  `uvm_component_utils(axi4_agent)
  axi4_driver    driver;
  axi4_monitor   monitor;
  uvm_sequencer #(axi4_seq_item) sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver    = axi4_driver::type_id::create("driver",this);
    monitor   = axi4_monitor::type_id::create("monitor",this);
    sequencer = uvm_sequencer#(axi4_seq_item)::type_id::create("sequencer",this);
    `uvm_info("AGT","Agent built",UVM_MEDIUM)
  endfunction

  function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
    `uvm_info("AGT","Agent connected",UVM_MEDIUM)
  endfunction
endclass
`endif
