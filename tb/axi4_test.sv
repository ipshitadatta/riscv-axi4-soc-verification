`ifndef AXI4_TEST_SV
`define AXI4_TEST_SV
class axi4_test extends uvm_test;
  `uvm_component_utils(axi4_test)
  axi4_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi4_env::type_id::create("env",this);
    `uvm_info("TEST","Test built",UVM_MEDIUM)
  endfunction

  task run_phase(uvm_phase phase);
    axi4_seq seq;
    phase.raise_objection(this);
    seq = axi4_seq::type_id::create("seq");
    seq.num_pairs = 200;
    seq.start(env.agent.sequencer);
    #500;
    `uvm_info("TEST","Test done!",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
`endif
