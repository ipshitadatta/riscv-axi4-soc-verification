`ifndef RISCV_ISS_SV
`define RISCV_ISS_SV
class riscv_iss;

  logic [31:0] regs [0:31];
  logic [31:0] imem [0:255];   // instruction memory (word-addressed)
  logic [31:0] dmem [0:255];   // data memory (word-addressed)
  logic [31:0] pc;
  int          instr_count;

  function new();
    pc = 32'h0;
    instr_count = 0;
    for (int i = 0; i < 32;  i++) regs[i] = 32'h0;
    for (int i = 0; i < 256; i++) imem[i]  = 32'h0000_0013; // NOP
    for (int i = 0; i < 256; i++) dmem[i]  = 32'h0;
  endfunction

  function void load_instr(logic [31:0] addr, logic [31:0] instr);
    imem[addr[9:2]] = instr;
  endfunction

  function void write_dmem(logic [31:0] addr, logic [31:0] data);
    dmem[addr[9:2]] = data;
  endfunction

  function automatic void execute();
    // ALL locals declared at top — no declarations inside case
    logic [31:0] instr, rs1v, rs2v, result, next_pc, ea;
    logic [6:0]  opcode, funct7;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    logic        branch_taken;

    instr  = imem[pc[9:2]];
    opcode = instr[6:0];
    rd     = instr[11:7];
    funct3 = instr[14:12];
    rs1    = instr[19:15];
    rs2    = instr[24:20];
    funct7 = instr[31:25];

    imm_i  = {{20{instr[31]}}, instr[31:20]};
    imm_s  = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    imm_b  = {{19{instr[31]}}, instr[31], instr[7],
               instr[30:25], instr[11:8], 1'b0};
    imm_u  = {instr[31:12], 12'h0};
    imm_j  = {{11{instr[31]}}, instr[31], instr[19:12],
               instr[20], instr[30:21], 1'b0};

    rs1v   = (rs1 == 0) ? 32'h0 : regs[rs1];
    rs2v   = (rs2 == 0) ? 32'h0 : regs[rs2];
    next_pc = pc + 4;
    result  = 32'h0;
    branch_taken = 1'b0;
    ea = 32'h0;

    case (opcode)
      7'b0110011: begin // R-type
        case ({funct7, funct3})
          10'b0000000_000: result = rs1v + rs2v;
          10'b0100000_000: result = rs1v - rs2v;
          10'b0000000_001: result = rs1v << rs2v[4:0];
          10'b0000000_010: result = ($signed(rs1v) < $signed(rs2v)) ? 32'h1 : 32'h0;
          10'b0000000_011: result = (rs1v < rs2v) ? 32'h1 : 32'h0;
          10'b0000000_100: result = rs1v ^ rs2v;
          10'b0000000_101: result = rs1v >> rs2v[4:0];
          10'b0100000_101: result = $signed(rs1v) >>> rs2v[4:0];
          10'b0000000_110: result = rs1v | rs2v;
          10'b0000000_111: result = rs1v & rs2v;
          default:         result = 32'h0;
        endcase
        if (rd != 0) regs[rd] = result;
      end

      7'b0010011: begin // I-type ALU
        case (funct3)
          3'b000: result = rs1v + imm_i;
          3'b010: result = ($signed(rs1v) < $signed(imm_i)) ? 32'h1 : 32'h0;
          3'b011: result = (rs1v < imm_i) ? 32'h1 : 32'h0;
          3'b100: result = rs1v ^ imm_i;
          3'b110: result = rs1v | imm_i;
          3'b111: result = rs1v & imm_i;
          3'b001: result = rs1v << imm_i[4:0];
          3'b101: result = funct7[5] ?
                  ($signed(rs1v) >>> imm_i[4:0]) :
                  (rs1v >> imm_i[4:0]);
          default: result = 32'h0;
        endcase
        if (rd != 0) regs[rd] = result;
      end

      7'b0110111: begin // LUI
        result = imm_u;
        if (rd != 0) regs[rd] = result;
      end

      7'b0010111: begin // AUIPC
        result = pc + imm_u;
        if (rd != 0) regs[rd] = result;
      end

      7'b1101111: begin // JAL
        if (rd != 0) regs[rd] = pc + 4;
        next_pc = pc + imm_j;
      end

      7'b1100111: begin // JALR
        if (rd != 0) regs[rd] = pc + 4;
        next_pc = (rs1v + imm_i) & ~32'h1;
      end

      7'b1100011: begin // Branch
        case (funct3)
          3'b000: branch_taken = (rs1v == rs2v);
          3'b001: branch_taken = (rs1v != rs2v);
          3'b100: branch_taken = ($signed(rs1v) < $signed(rs2v));
          3'b101: branch_taken = ($signed(rs1v) >= $signed(rs2v));
          3'b110: branch_taken = (rs1v < rs2v);
          3'b111: branch_taken = (rs1v >= rs2v);
          default: branch_taken = 1'b0;
        endcase
        if (branch_taken) next_pc = pc + imm_b;
      end

      7'b0000011: begin // Load
        ea = rs1v + imm_i;
        result = dmem[ea[9:2]];
        case (funct3)
          3'b000: result = {{24{result[7]}},  result[7:0]};
          3'b001: result = {{16{result[15]}}, result[15:0]};
          3'b010: ; // LW — already full word
          3'b100: result = {24'h0, result[7:0]};
          3'b101: result = {16'h0, result[15:0]};
          default: ;
        endcase
        if (rd != 0) regs[rd] = result;
      end

      7'b0100011: begin // Store
        ea = rs1v + imm_s;
        dmem[ea[9:2]] = rs2v;
      end

      default: ; // NOP
    endcase

    pc = next_pc;
    instr_count++;
  endfunction

  function automatic int compare(logic [31:0] dut_regs [0:31]);
    int ok;
    ok = 1;
    for (int i = 1; i < 32; i++) begin
      if (regs[i] !== dut_regs[i]) begin
        $display("ISS MISMATCH x%0d: ISS=0x%08x DUT=0x%08x",
                 i, regs[i], dut_regs[i]);
        ok = 0;
      end
    end
    return ok;
  endfunction

endclass
`endif
