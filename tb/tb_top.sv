`include "uvm_macros.svh"
import uvm_pkg::*;

`include "axi4_seq_item.sv"
`include "axi4_sequence.sv"
`include "axi4_driver.sv"
`include "axi4_monitor.sv"
`include "axi4_scoreboard.sv"
`include "axi4_coverage.sv"
`include "axi4_agent.sv"
`include "axi4_env.sv"
`include "axi4_test.sv"

interface axi4_if(input logic clk, rst_n);
  logic [3:0]  awid;  logic [31:0] awaddr; logic [7:0] awlen;
  logic [2:0]  awsize; logic [1:0] awburst; logic awvalid; logic awready;
  logic [31:0] wdata;  logic [3:0] wstrb;   logic wlast; logic wvalid; logic wready;
  logic [3:0]  bid;    logic [1:0] bresp;   logic bvalid; logic bready;
  logic [3:0]  arid;  logic [31:0] araddr; logic [7:0] arlen;
  logic [2:0]  arsize; logic [1:0] arburst; logic arvalid; logic arready;
  logic [3:0]  rid;    logic [31:0] rdata;  logic [1:0] rresp;
  logic        rlast;  logic rvalid; logic rready;
endinterface

module tb_top;
  logic clk, rst_n;
  initial clk = 0;
  always  #5 clk = ~clk;
  initial begin
    rst_n = 0;
    repeat(4) @(posedge clk);
    rst_n = 1;
    `uvm_info("TOP","Reset released",UVM_NONE)
  end

  axi4_if dut_if(.clk(clk),.rst_n(rst_n));

  axi4_slave dut(
    .clk(clk),.rst_n(rst_n),
    .awid(dut_if.awid),.awaddr(dut_if.awaddr),.awlen(dut_if.awlen),
    .awsize(dut_if.awsize),.awburst(dut_if.awburst),
    .awvalid(dut_if.awvalid),.awready(dut_if.awready),
    .wdata(dut_if.wdata),.wstrb(dut_if.wstrb),
    .wlast(dut_if.wlast),.wvalid(dut_if.wvalid),.wready(dut_if.wready),
    .bid(dut_if.bid),.bresp(dut_if.bresp),
    .bvalid(dut_if.bvalid),.bready(dut_if.bready),
    .arid(dut_if.arid),.araddr(dut_if.araddr),.arlen(dut_if.arlen),
    .arsize(dut_if.arsize),.arburst(dut_if.arburst),
    .arvalid(dut_if.arvalid),.arready(dut_if.arready),
    .rid(dut_if.rid),.rdata(dut_if.rdata),.rresp(dut_if.rresp),
    .rlast(dut_if.rlast),.rvalid(dut_if.rvalid),.rready(dut_if.rready)
  );

  // ── SVA checker instance ─────────────────────────
  axi4_sva u_sva (
    .clk    (clk),
    .rst_n  (rst_n),
    .awvalid(dut_if.awvalid), .awready(dut_if.awready),
    .awid   (dut_if.awid),    .awlen  (dut_if.awlen),
    .wvalid (dut_if.wvalid),  .wready (dut_if.wready),
    .wlast  (dut_if.wlast),
    .bvalid (dut_if.bvalid),  .bready (dut_if.bready),
    .bid    (dut_if.bid),
    .bresp  (dut_if.bresp),
    .arvalid(dut_if.arvalid), .arready(dut_if.arready),
    .arid   (dut_if.arid),    .arlen  (dut_if.arlen),
    .rvalid (dut_if.rvalid),  .rready (dut_if.rready),
    .rlast  (dut_if.rlast),   .rid    (dut_if.rid),
    .rresp  (dut_if.rresp)
  );

  initial begin
    uvm_config_db#(virtual axi4_if)::set(null,"uvm_test_top.*","vif",dut_if);
    run_test("axi4_test");
  end
endmodule
