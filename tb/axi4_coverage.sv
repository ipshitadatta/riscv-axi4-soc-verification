`ifndef AXI4_COVERAGE_SV
`define AXI4_COVERAGE_SV

class axi4_coverage extends uvm_subscriber #(axi4_seq_item);
  `uvm_component_utils(axi4_coverage)

  // ── Covergroups ──────────────────────────────────

  // 1. Write burst length coverage
  covergroup cg_write_burst;
    cp_len: coverpoint item.burst_len {
      bins single = {2'b00};   // 1 beat
      bins double = {2'b01};   // 2 beats
      bins quad   = {2'b10};   // 4 beats
    }
    cp_addr_region: coverpoint item.addr[5:4] {
      bins low  = {2'b00};     // 0x00-0x0F
      bins mid  = {2'b01};     // 0x10-0x1F
      bins high = {2'b10, 2'b11}; // 0x20-0x3F
    }
    // Cross: every burst length at every address region
    cx_len_addr: cross cp_len, cp_addr_region;
  endgroup

  // 2. Read burst length coverage
  covergroup cg_read_burst;
    cp_len: coverpoint item.burst_len {
      bins single = {2'b00};
      bins double = {2'b01};
      bins quad   = {2'b10};
    }
    cp_addr_region: coverpoint item.addr[5:4] {
      bins low  = {2'b00};
      bins mid  = {2'b01};
      bins high = {2'b10, 2'b11};
    }
    cx_len_addr: cross cp_len, cp_addr_region;
  endgroup

  // 3. Transaction kind coverage
  covergroup cg_txn_kind;
    cp_kind: coverpoint item.kind {
      bins write = {axi4_seq_item::WRITE};
      bins read  = {axi4_seq_item::READ};
    }
  endgroup

  axi4_seq_item item;
  int wr_count, rd_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_write_burst = new();
    cg_read_burst  = new();
    cg_txn_kind    = new();
  endfunction

  function void write(axi4_seq_item t);
    item = t;
    cg_txn_kind.sample();
    if (t.kind == axi4_seq_item::WRITE) begin
      cg_write_burst.sample();
      wr_count++;
    end else begin
      cg_read_burst.sample();
      rd_count++;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("COV", $sformatf(
      "\n========= COVERAGE SUMMARY =========\n  Write burst cov : %0.1f%%\n  Read  burst cov : %0.1f%%\n  Txn kind cov    : %0.1f%%\n=====================================",
      cg_write_burst.get_coverage(),
      cg_read_burst.get_coverage(),
      cg_txn_kind.get_coverage()), UVM_NONE)
  endfunction

endclass
`endif
