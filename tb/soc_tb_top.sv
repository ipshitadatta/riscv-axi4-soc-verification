`include "uvm_macros.svh"
import uvm_pkg::*;

`include "riscv_seq_item.sv"
`include "riscv_iss.sv"

module soc_tb_top;
  logic clk, rst_n;

  initial clk = 0;
  always #5 clk = ~clk;

  initial begin
    rst_n = 0;
    repeat(4) @(posedge clk);
    rst_n = 1;
    `uvm_info("TOP", "Reset released", UVM_NONE)
  end

  soc_top dut (
    .clk(clk), .rst_n(rst_n),
    .pc_out(), .reg_out(), .instr_valid()
  );

  riscv_iss iss;

  // Program: 10 instructions — ADDI + ADD only
  // x1=6, x2=16, x3=20, x4=35, x5=50, x6=150, x7=200
  logic [31:0] prog [0:9];
  int          pass;

  initial begin
    prog[0] = 32'h00500093; // ADDI x1, x0, 5
    prog[1] = 32'h00a00113; // ADDI x2, x0, 10
    prog[2] = 32'h002081b3; // ADD  x3, x1, x2
    prog[3] = 32'h01418213; // ADDI x4, x3, 20
    prog[4] = 32'h004182b3; // ADD  x5, x3, x4
    prog[5] = 32'h06428313; // ADDI x6, x5, 100
    prog[6] = 32'h006283b3; // ADD  x7, x5, x6
    prog[7] = 32'h00108093; // ADDI x1, x1, 1
    prog[8] = 32'h00208133; // ADD  x2, x1, x2
    prog[9] = 32'h00410193; // ADDI x3, x2, 4

    // Wait for reset
    @(posedge rst_n);
    repeat(2) @(posedge clk);

    iss = new();

    // Load program into ISS and force into DUT instruction memory
    // Use static indices — no automatic variable in force
    iss.load_instr(32'h00, prog[0]); force dut.slave_i.regs[0] = prog[0];
    iss.load_instr(32'h04, prog[1]); force dut.slave_i.regs[1] = prog[1];
    iss.load_instr(32'h08, prog[2]); force dut.slave_i.regs[2] = prog[2];
    iss.load_instr(32'h0c, prog[3]); force dut.slave_i.regs[3] = prog[3];
    iss.load_instr(32'h10, prog[4]); force dut.slave_i.regs[4] = prog[4];
    iss.load_instr(32'h14, prog[5]); force dut.slave_i.regs[5] = prog[5];
    iss.load_instr(32'h18, prog[6]); force dut.slave_i.regs[6] = prog[6];
    iss.load_instr(32'h1c, prog[7]); force dut.slave_i.regs[7] = prog[7];
    iss.load_instr(32'h20, prog[8]); force dut.slave_i.regs[8] = prog[8];
    iss.load_instr(32'h24, prog[9]); force dut.slave_i.regs[9] = prog[9];

    // Run ISS for 10 instructions
    repeat(10) iss.execute();

    `uvm_info("ISS", $sformatf(
      "ISS done: x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d x6=%0d x7=%0d",
      iss.regs[1], iss.regs[2], iss.regs[3], iss.regs[4],
      iss.regs[5], iss.regs[6], iss.regs[7]), UVM_NONE)

    // Wait for DUT to execute all 10 instructions (~6 cycles each)
    repeat(400) @(posedge clk);

    // Compare ISS vs DUT
    pass = 1;
    for (int i = 1; i <= 7; i++) begin
      if (dut.core.regs[i] !== iss.regs[i]) begin
        `uvm_error("SOC_TB", $sformatf(
          "MISMATCH x%0d: DUT=0x%08x ISS=0x%08x",
          i, dut.core.regs[i], iss.regs[i]))
        pass = 0;
      end else begin
        `uvm_info("SOC_TB", $sformatf(
          "MATCH x%0d = 0x%08x (%0d)",
          i, dut.core.regs[i], dut.core.regs[i]), UVM_NONE)
      end
    end

    if (pass)
      `uvm_info("SOC_TB", "ALL REGISTERS MATCH — ISS == DUT", UVM_NONE)
    else
      `uvm_error("SOC_TB", "REGISTER MISMATCH DETECTED")

    #20;
    $finish;
  end

endmodule
