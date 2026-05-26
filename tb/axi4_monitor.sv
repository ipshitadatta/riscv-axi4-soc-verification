`ifndef AXI4_MONITOR_SV
`define AXI4_MONITOR_SV
class axi4_monitor extends uvm_monitor;
  `uvm_component_utils(axi4_monitor)
  virtual axi4_if vif;
  uvm_analysis_port #(axi4_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap",this);
    if (!uvm_config_db#(virtual axi4_if)::get(this,"","vif",vif))
      `uvm_fatal("MON","No vif")
    `uvm_info("MON","Monitor built",UVM_MEDIUM)
  endfunction

  task run_phase(uvm_phase phase);
    `uvm_info("MON","Monitor running",UVM_MEDIUM)
    fork
      mon_wr();
      mon_rd();
    join
  endtask

  task mon_wr();
    forever begin
      axi4_seq_item t;
      logic [7:0] alen;
      // Poll for AW handshake — sample AFTER clock edge settles
      do begin @(posedge vif.clk); #1; end
      while (!(vif.awvalid===1 && vif.awready===1));

      t = axi4_seq_item::type_id::create("mw");
      t.kind = axi4_seq_item::WRITE;
      t.id   = vif.awid;
      t.addr = vif.awaddr;
      alen   = vif.awlen;
      t.burst_len = (alen==0)?2'b00:(alen==1)?2'b01:2'b10;

      for (int i=0; i<=alen; i++) begin
        do begin @(posedge vif.clk); #1; end
        while (!(vif.wvalid===1 && vif.wready===1));
        t.wdata[i] = vif.wdata;
      end

      do begin @(posedge vif.clk); #1; end
      while (!(vif.bvalid===1 && vif.bready===1));
      t.bresp = vif.bresp;

      `uvm_info("MON",$sformatf("WR addr=0x%08x beats=%0d",t.addr,alen+1),UVM_MEDIUM)
      ap.write(t);
    end
  endtask

  task mon_rd();
    forever begin
      axi4_seq_item t;
      logic [7:0] alen;
      // Poll for AR handshake
      do begin @(posedge vif.clk); #1; end
      while (!(vif.arvalid===1 && vif.arready===1));

      t = axi4_seq_item::type_id::create("mr");
      t.kind = axi4_seq_item::READ;
      t.id   = vif.arid;
      t.addr = vif.araddr;
      alen   = vif.arlen;
      t.burst_len = (alen==0)?2'b00:(alen==1)?2'b01:2'b10;

      for (int i=0; i<=alen; i++) begin
        do begin @(posedge vif.clk); #1; end
        while (!(vif.rvalid===1 && vif.rready===1));
        t.rdata[i] = vif.rdata;
      end

      `uvm_info("MON",$sformatf("RD addr=0x%08x beats=%0d",t.addr,alen+1),UVM_MEDIUM)
      ap.write(t);
    end
  endtask
endclass
`endif
