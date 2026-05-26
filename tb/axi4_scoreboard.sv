`ifndef AXI4_SCOREBOARD_SV
`define AXI4_SCOREBOARD_SV
class axi4_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(axi4_scoreboard)
  uvm_analysis_imp #(axi4_seq_item, axi4_scoreboard) analysis_export;

  logic [31:0] mem [logic [31:0]];  // reference model
  int wr_cnt, rd_cnt, pass_cnt, fail_cnt;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    analysis_export = new("analysis_export",this);
    `uvm_info("SB","Scoreboard built",UVM_MEDIUM)
  endfunction

  function void write(axi4_seq_item t);
    if (t.kind == axi4_seq_item::WRITE) begin
      logic [31:0] a = t.addr;
      int n = t.beats();
      for (int i=0;i<n;i++) begin mem[a]=t.wdata[i]; a+=4; end
      wr_cnt++;
      `uvm_info("SB",$sformatf("WR PASS addr=0x%08x %0d beats",t.addr,n),UVM_MEDIUM)
    end else begin
      logic [31:0] a = t.addr;
      int n = t.beats();
      int ok = 1;
      rd_cnt++;
      for (int i=0;i<n;i++) begin
        if (mem.exists(a)) begin
          if (t.rdata[i] !== mem[a]) begin
            `uvm_error("SB",$sformatf(
              "RD FAIL beat[%0d] addr=0x%08x GOT=0x%08x EXP=0x%08x",
              i,a,t.rdata[i],mem[a]))
            fail_cnt++; ok=0;
          end
        end
        a+=4;
      end
      if (ok) begin
        pass_cnt++;
        `uvm_info("SB",$sformatf("RD PASS addr=0x%08x %0d beats",t.addr,n),UVM_MEDIUM)
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SB",$sformatf(
      "\n========= SCOREBOARD SUMMARY =========\n  WRITES : %0d\n  READS  : %0d\n  PASSED : %0d\n  FAILED : %0d\n======================================",
      wr_cnt,rd_cnt,pass_cnt,fail_cnt),UVM_NONE)
    if (fail_cnt==0)
      `uvm_info("SB","ALL PASSED!",UVM_NONE)
    else
      `uvm_error("SB",$sformatf("%0d FAILURES",fail_cnt))
  endfunction
endclass
`endif
