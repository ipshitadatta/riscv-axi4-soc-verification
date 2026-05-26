`ifndef AXI4_DRIVER_SV
`define AXI4_DRIVER_SV
class axi4_driver extends uvm_driver #(axi4_seq_item);
  `uvm_component_utils(axi4_driver)
  virtual axi4_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi4_if)::get(this,"","vif",vif))
      `uvm_fatal("DRV","No vif")
    `uvm_info("DRV","Driver built",UVM_MEDIUM)
  endfunction

  task run_phase(uvm_phase phase);
    axi4_seq_item t;
    // Zero all master-driven signals
    vif.awvalid<=0; vif.awid<=0; vif.awaddr<=0;
    vif.awlen<=0;   vif.awsize<=3'b010; vif.awburst<=2'b01;
    vif.wvalid<=0;  vif.wdata<=0; vif.wstrb<=4'hF; vif.wlast<=0;
    vif.bready<=0;
    vif.arvalid<=0; vif.arid<=0; vif.araddr<=0;
    vif.arlen<=0;   vif.arsize<=3'b010; vif.arburst<=2'b01;
    vif.rready<=0;
    // Wait for reset deassert
    do @(posedge vif.clk); while (vif.rst_n !== 1'b1);
    repeat(2) @(posedge vif.clk);
    `uvm_info("DRV","Out of reset",UVM_MEDIUM)
    forever begin
      seq_item_port.get_next_item(t);
      if (t.kind == axi4_seq_item::WRITE) do_write(t);
      else                                do_read(t);
      seq_item_port.item_done();
    end
  endtask

  task do_write(axi4_seq_item t);
    int n = t.beats();
    // AW
    @(posedge vif.clk);
    vif.awvalid<=1; vif.awid<=t.id; vif.awaddr<=t.addr;
    vif.awlen<=t.awlen_val(); vif.awsize<=3'b010; vif.awburst<=2'b01;
    do @(posedge vif.clk); while (vif.awready!==1'b1);
    vif.awvalid<=0;
    // W beats
    for (int i=0;i<n;i++) begin
      @(posedge vif.clk);
      vif.wvalid<=1; vif.wdata<=t.wdata[i];
      vif.wstrb<=4'hF; vif.wlast<=(i==n-1)?1'b1:1'b0;
      do @(posedge vif.clk); while (vif.wready!==1'b1);
    end
    vif.wvalid<=0; vif.wlast<=0;
    // B
    vif.bready<=1;
    do @(posedge vif.clk); while (vif.bvalid!==1'b1);
    vif.bready<=0;
    @(posedge vif.clk);
  endtask

  task do_read(axi4_seq_item t);
    int n = t.beats();
    // AR
    @(posedge vif.clk);
    vif.arvalid<=1; vif.arid<=t.id; vif.araddr<=t.addr;
    vif.arlen<=t.awlen_val(); vif.arsize<=3'b010; vif.arburst<=2'b01;
    do @(posedge vif.clk); while (vif.arready!==1'b1);
    vif.arvalid<=0;
    // R beats
    vif.rready<=1;
    for (int i=0;i<n;i++) begin
      do @(posedge vif.clk); while (vif.rvalid!==1'b1);
      t.rdata[i] = vif.rdata;
    end
    vif.rready<=0;
    @(posedge vif.clk);
  endtask
endclass
`endif
