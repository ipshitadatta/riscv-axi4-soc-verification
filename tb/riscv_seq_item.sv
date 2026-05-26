`ifndef RISCV_SEQ_ITEM_SV
`define RISCV_SEQ_ITEM_SV
class riscv_seq_item extends uvm_sequence_item;
  `uvm_object_utils(riscv_seq_item)

  rand logic [31:0] instr;

  // Only ADDI and ADD — safe, no memory, no branches
  // ADDI x(rd), x(rs1), imm  opcode=0010011 funct3=000
  // ADD  x(rd), x(rs1), x(rs2) opcode=0110011 funct3=000 funct7=0
  rand bit use_rtype;  // 0=ADDI, 1=ADD

  rand logic [4:0] rd, rs1, rs2;
  rand logic [11:0] imm12;

  // registers 1-7 only — safe range
  constraint c_regs {
    rd  inside {[1:7]};
    rs1 inside {[0:7]};
    rs2 inside {[0:7]};
    imm12 inside {[0:127]};  // small positive immediate
  }

  constraint c_build {
    if (use_rtype == 0)
      // ADDI rd, rs1, imm
      instr == {imm12, rs1, 3'b000, rd, 7'b0010011};
    else
      // ADD rd, rs1, rs2
      instr == {7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011};
  }

  function new(string name = "riscv_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("INSTR=0x%08x", instr);
  endfunction
endclass
`endif
