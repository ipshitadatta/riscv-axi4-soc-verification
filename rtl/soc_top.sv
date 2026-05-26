module soc_top (
  input  logic clk,
  input  logic rst_n,
  output logic [31:0] pc_out,
  output logic [31:0] reg_out [0:31],
  output logic        instr_valid
);

  logic [3:0]  arid_i;  logic [31:0] araddr_i; logic [7:0] arlen_i;
  logic [2:0]  arsize_i; logic [1:0] arburst_i; logic arvalid_i, arready_i;
  logic [3:0]  rid_i;   logic [31:0] rdata_i;  logic [1:0] rresp_i;
  logic        rlast_i, rvalid_i, rready_i;

  logic [3:0]  awid_d;  logic [31:0] awaddr_d; logic [7:0] awlen_d;
  logic [2:0]  awsize_d; logic [1:0] awburst_d; logic awvalid_d, awready_d;
  logic [31:0] wdata_d; logic [3:0] wstrb_d;
  logic        wlast_d, wvalid_d, wready_d;
  logic [3:0]  bid_d;   logic [1:0] bresp_d;   logic bvalid_d, bready_d;
  logic [3:0]  arid_d;  logic [31:0] araddr_d; logic [7:0] arlen_d;
  logic [2:0]  arsize_d; logic [1:0] arburst_d; logic arvalid_d, arready_d;
  logic [3:0]  rid_d;   logic [31:0] rdata_d;  logic [1:0] rresp_d;
  logic        rlast_d, rvalid_d, rready_d;

  riscv_core core (
    .clk(clk), .rst_n(rst_n),
    .arid_i(arid_i), .araddr_i(araddr_i), .arlen_i(arlen_i),
    .arsize_i(arsize_i), .arburst_i(arburst_i),
    .arvalid_i(arvalid_i), .arready_i(arready_i),
    .rid_i(rid_i), .rdata_i(rdata_i), .rresp_i(rresp_i),
    .rlast_i(rlast_i), .rvalid_i(rvalid_i), .rready_i(rready_i),
    .awid_d(awid_d), .awaddr_d(awaddr_d), .awlen_d(awlen_d),
    .awsize_d(awsize_d), .awburst_d(awburst_d),
    .awvalid_d(awvalid_d), .awready_d(awready_d),
    .wdata_d(wdata_d), .wstrb_d(wstrb_d),
    .wlast_d(wlast_d), .wvalid_d(wvalid_d), .wready_d(wready_d),
    .bid_d(bid_d), .bresp_d(bresp_d),
    .bvalid_d(bvalid_d), .bready_d(bready_d),
    .arid_d(arid_d), .araddr_d(araddr_d), .arlen_d(arlen_d),
    .arsize_d(arsize_d), .arburst_d(arburst_d),
    .arvalid_d(arvalid_d), .arready_d(arready_d),
    .rid_d(rid_d), .rdata_d(rdata_d), .rresp_d(rresp_d),
    .rlast_d(rlast_d), .rvalid_d(rvalid_d), .rready_d(rready_d),
    .pc_out(pc_out), .reg_out(reg_out), .instr_valid(instr_valid)
  );

  axi4_slave slave_i (
    .clk(clk), .rst_n(rst_n),
    .awid(4'h0), .awaddr(32'h0), .awlen(8'h0),
    .awsize(3'b0), .awburst(2'b0),
    .awvalid(1'b0), .awready(),
    .wdata(32'h0), .wstrb(4'h0),
    .wlast(1'b0), .wvalid(1'b0), .wready(),
    .bid(), .bresp(), .bvalid(), .bready(1'b0),
    .arid(arid_i), .araddr(araddr_i), .arlen(arlen_i),
    .arsize(arsize_i), .arburst(arburst_i),
    .arvalid(arvalid_i), .arready(arready_i),
    .rid(rid_i), .rdata(rdata_i), .rresp(rresp_i),
    .rlast(rlast_i), .rvalid(rvalid_i), .rready(rready_i)
  );

  axi4_slave slave_d (
    .clk(clk), .rst_n(rst_n),
    .awid(awid_d), .awaddr(awaddr_d), .awlen(awlen_d),
    .awsize(awsize_d), .awburst(awburst_d),
    .awvalid(awvalid_d), .awready(awready_d),
    .wdata(wdata_d), .wstrb(wstrb_d),
    .wlast(wlast_d), .wvalid(wvalid_d), .wready(wready_d),
    .bid(bid_d), .bresp(bresp_d),
    .bvalid(bvalid_d), .bready(bready_d),
    .arid(arid_d), .araddr(araddr_d), .arlen(arlen_d),
    .arsize(arsize_d), .arburst(arburst_d),
    .arvalid(arvalid_d), .arready(arready_d),
    .rid(rid_d), .rdata(rdata_d), .rresp(rresp_d),
    .rlast(rlast_d), .rvalid(rvalid_d), .rready(rready_d)
  );

endmodule
