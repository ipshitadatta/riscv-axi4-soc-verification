// ─────────────────────────────────────────────────────
// riscv_core.sv
// Simple RV32I processor — AXI4 master
// Fetch → Decode → Execute → Memory → Writeback
// Instruction memory and data memory over AXI4
// ─────────────────────────────────────────────────────
module riscv_core #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter ID_WIDTH   = 4,
  parameter PC_RESET   = 32'h0000_0000
)(
  input  logic                    clk, rst_n,

  // ── AXI4 Instruction Fetch (read only) ──────────
  output logic [ID_WIDTH-1:0]     arid_i,
  output logic [ADDR_WIDTH-1:0]   araddr_i,
  output logic [7:0]              arlen_i,
  output logic [2:0]              arsize_i,
  output logic [1:0]              arburst_i,
  output logic                    arvalid_i,
  input  logic                    arready_i,
  input  logic [ID_WIDTH-1:0]     rid_i,
  input  logic [DATA_WIDTH-1:0]   rdata_i,
  input  logic [1:0]              rresp_i,
  input  logic                    rlast_i,
  input  logic                    rvalid_i,
  output logic                    rready_i,

  // ── AXI4 Data Memory (read/write) ───────────────
  output logic [ID_WIDTH-1:0]     awid_d,
  output logic [ADDR_WIDTH-1:0]   awaddr_d,
  output logic [7:0]              awlen_d,
  output logic [2:0]              awsize_d,
  output logic [1:0]              awburst_d,
  output logic                    awvalid_d,
  input  logic                    awready_d,
  output logic [DATA_WIDTH-1:0]   wdata_d,
  output logic [DATA_WIDTH/8-1:0] wstrb_d,
  output logic                    wlast_d,
  output logic                    wvalid_d,
  input  logic                    wready_d,
  input  logic [ID_WIDTH-1:0]     bid_d,
  input  logic [1:0]              bresp_d,
  input  logic                    bvalid_d,
  output logic                    bready_d,
  output logic [ID_WIDTH-1:0]     arid_d,
  output logic [ADDR_WIDTH-1:0]   araddr_d,
  output logic [7:0]              arlen_d,
  output logic [2:0]              arsize_d,
  output logic [1:0]              arburst_d,
  output logic                    arvalid_d,
  input  logic                    arready_d,
  input  logic [ID_WIDTH-1:0]     rid_d,
  input  logic [DATA_WIDTH-1:0]   rdata_d,
  input  logic [1:0]              rresp_d,
  input  logic                    rlast_d,
  input  logic                    rvalid_d,
  output logic                    rready_d,

  // ── Debug outputs ────────────────────────────────
  output logic [31:0]             pc_out,
  output logic [31:0]             reg_out [0:31],
  output logic                    instr_valid
);

  // ── Register file ────────────────────────────────
  logic [31:0] regs [0:31];
  logic [31:0] pc;

  // ── Pipeline registers ────────────────────────────
  // Fetch stage
  logic [31:0] fetch_pc;
  logic [31:0] fetch_instr;
  logic        fetch_valid;

  // ── Instruction fetch state ───────────────────────
  typedef enum logic [1:0] {
    FETCH_IDLE, FETCH_AR, FETCH_WAIT, FETCH_DONE
  } fetch_st_t;
  fetch_st_t fetch_st;

  // ── Data memory state ─────────────────────────────
  typedef enum logic [2:0] {
    MEM_IDLE, MEM_AW, MEM_W, MEM_B, MEM_AR, MEM_R
  } mem_st_t;
  mem_st_t mem_st;

  // ── Decode signals ────────────────────────────────
  logic [6:0]  opcode;
  logic [4:0]  rd, rs1, rs2;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
  logic [31:0] rs1_val, rs2_val;
  logic [31:0] alu_result;
  logic        mem_op_pending;
  logic [31:0] mem_addr;
  logic [31:0] mem_wdata;
  logic        mem_we;
  logic [31:0] mem_rdata;
  logic        mem_done;
  logic        branch_taken;
  logic [31:0] branch_target;

  // Instruction valid flag for debug
  assign instr_valid = fetch_valid;
  assign pc_out      = pc;

  // Register file debug output
  always_comb begin
    for (int i = 0; i < 32; i++)
      reg_out[i] = regs[i];
  end

  // ── Fixed AXI4 burst fields ───────────────────────
  // Instruction fetch: single-beat INCR
  assign arlen_i   = 8'h00;
  assign arsize_i  = 3'b010;
  assign arburst_i = 2'b01;
  assign arid_i    = 4'h0;
  // Data: single-beat INCR
  assign awlen_d   = 8'h00;
  assign awsize_d  = 3'b010;
  assign awburst_d = 2'b01;
  assign awid_d    = 4'h1;
  assign arlen_d   = 8'h00;
  assign arsize_d  = 3'b010;
  assign arburst_d = 2'b01;
  assign arid_d    = 4'h2;
  assign wlast_d   = 1'b1;

  // ── Decode (combinational) ────────────────────────
  assign opcode  = fetch_instr[6:0];
  assign rd      = fetch_instr[11:7];
  assign funct3  = fetch_instr[14:12];
  assign rs1     = fetch_instr[19:15];
  assign rs2     = fetch_instr[24:20];
  assign funct7  = fetch_instr[31:25];

  // Immediate decoding
  assign imm_i = {{20{fetch_instr[31]}}, fetch_instr[31:20]};
  assign imm_s = {{20{fetch_instr[31]}}, fetch_instr[31:25], fetch_instr[11:7]};
  assign imm_b = {{19{fetch_instr[31]}}, fetch_instr[31], fetch_instr[7],
                   fetch_instr[30:25], fetch_instr[11:8], 1'b0};
  assign imm_u = {fetch_instr[31:12], 12'h0};
  assign imm_j = {{11{fetch_instr[31]}}, fetch_instr[31], fetch_instr[19:12],
                   fetch_instr[20], fetch_instr[30:21], 1'b0};

  assign rs1_val = (rs1 == 5'h0) ? 32'h0 : regs[rs1];
  assign rs2_val = (rs2 == 5'h0) ? 32'h0 : regs[rs2];

  // ── ALU ───────────────────────────────────────────
  always_comb begin
    alu_result   = 32'h0;
    branch_taken = 1'b0;
    branch_target= pc + imm_b;
    mem_addr     = rs1_val + imm_i;
    mem_wdata    = rs2_val;
    mem_we       = 1'b0;

    if (fetch_valid) begin
      case (opcode)
        // R-type
        7'b0110011: begin
          case ({funct7, funct3})
            10'b0000000_000: alu_result = rs1_val + rs2_val;   // ADD
            10'b0100000_000: alu_result = rs1_val - rs2_val;   // SUB
            10'b0000000_001: alu_result = rs1_val << rs2_val[4:0]; // SLL
            10'b0000000_010: alu_result = ($signed(rs1_val) < $signed(rs2_val)) ? 32'h1 : 32'h0; // SLT
            10'b0000000_011: alu_result = (rs1_val < rs2_val) ? 32'h1 : 32'h0; // SLTU
            10'b0000000_100: alu_result = rs1_val ^ rs2_val;   // XOR
            10'b0000000_101: alu_result = rs1_val >> rs2_val[4:0]; // SRL
            10'b0100000_101: alu_result = $signed(rs1_val) >>> rs2_val[4:0]; // SRA
            10'b0000000_110: alu_result = rs1_val | rs2_val;   // OR
            10'b0000000_111: alu_result = rs1_val & rs2_val;   // AND
            default:         alu_result = 32'h0;
          endcase
        end
        // I-type ALU
        7'b0010011: begin
          case (funct3)
            3'b000: alu_result = rs1_val + imm_i;              // ADDI
            3'b010: alu_result = ($signed(rs1_val) < $signed(imm_i)) ? 32'h1 : 32'h0; // SLTI
            3'b011: alu_result = (rs1_val < imm_i) ? 32'h1 : 32'h0; // SLTIU
            3'b100: alu_result = rs1_val ^ imm_i;              // XORI
            3'b110: alu_result = rs1_val | imm_i;              // ORI
            3'b111: alu_result = rs1_val & imm_i;              // ANDI
            3'b001: alu_result = rs1_val << imm_i[4:0];        // SLLI
            3'b101: alu_result = (funct7[5]) ?
                    $signed(rs1_val) >>> imm_i[4:0] :
                    rs1_val >> imm_i[4:0];                     // SRLI/SRAI
            default: alu_result = 32'h0;
          endcase
        end
        // LUI
        7'b0110111: alu_result = imm_u;
        // AUIPC
        7'b0010111: alu_result = pc + imm_u;
        // JAL
        7'b1101111: begin alu_result = pc + 4; branch_taken = 1'b1;
                    branch_target = pc + imm_j; end
        // JALR
        7'b1100111: begin alu_result = pc + 4; branch_taken = 1'b1;
                    branch_target = (rs1_val + imm_i) & ~32'h1; end
        // Branch
        7'b1100011: begin
          case (funct3)
            3'b000: branch_taken = (rs1_val == rs2_val);        // BEQ
            3'b001: branch_taken = (rs1_val != rs2_val);        // BNE
            3'b100: branch_taken = ($signed(rs1_val) < $signed(rs2_val)); // BLT
            3'b101: branch_taken = ($signed(rs1_val) >= $signed(rs2_val)); // BGE
            3'b110: branch_taken = (rs1_val < rs2_val);         // BLTU
            3'b111: branch_taken = (rs1_val >= rs2_val);        // BGEU
            default: branch_taken = 1'b0;
          endcase
        end
        // Load
        7'b0000011: begin mem_addr = rs1_val + imm_i; end
        // Store
        7'b0100011: begin
          mem_addr  = rs1_val + imm_s;
          mem_wdata = rs2_val;
          mem_we    = 1'b1;
        end
        default: ;
      endcase
    end
  end

  // ── Main pipeline ─────────────────────────────────
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc           <= PC_RESET;
      fetch_st     <= FETCH_IDLE;
      fetch_valid  <= 1'b0;
      fetch_instr  <= 32'h0000_0013; // NOP
      fetch_pc     <= PC_RESET;
      mem_st       <= MEM_IDLE;
      mem_op_pending <= 1'b0;
      mem_done     <= 1'b0;
      arvalid_i    <= 1'b0;
      rready_i     <= 1'b0;
      awvalid_d    <= 1'b0;
      wvalid_d     <= 1'b0;
      bready_d     <= 1'b0;
      arvalid_d    <= 1'b0;
      rready_d     <= 1'b0;
      for (int i = 0; i < 32; i++) regs[i] <= 32'h0;
    end else begin

      // ── Instruction Fetch FSM ──────────────────────
      case (fetch_st)
        FETCH_IDLE: begin
          fetch_valid <= 1'b0;
          if (!mem_op_pending) begin
            araddr_i  <= pc;
            arvalid_i <= 1'b1;
            fetch_pc  <= pc;
            fetch_st  <= FETCH_AR;
          end
        end

        FETCH_AR: begin
          if (arready_i) begin
            arvalid_i <= 1'b0;
            rready_i  <= 1'b1;
            fetch_st  <= FETCH_WAIT;
          end
        end

        FETCH_WAIT: begin
          if (rvalid_i) begin
            fetch_instr <= rdata_i;
            rready_i    <= 1'b0;
            fetch_valid <= 1'b1;
            fetch_st    <= FETCH_DONE;
          end
        end

        FETCH_DONE: begin
          fetch_valid <= 1'b0;
          // Execute instruction
          case (opcode)
            // R-type / I-type ALU / LUI / AUIPC
            7'b0110011, 7'b0010011, 7'b0110111, 7'b0010111: begin
              if (rd != 5'h0) regs[rd] <= alu_result;
              pc       <= pc + 4;
              fetch_st <= FETCH_IDLE;
            end
            // JAL / JALR
            7'b1101111, 7'b1100111: begin
              if (rd != 5'h0) regs[rd] <= alu_result;
              pc       <= branch_target;
              fetch_st <= FETCH_IDLE;
            end
            // Branch
            7'b1100011: begin
              pc       <= branch_taken ? branch_target : pc + 4;
              fetch_st <= FETCH_IDLE;
            end
            // Load
            7'b0000011: begin
              araddr_d     <= mem_addr;
              arvalid_d    <= 1'b1;
              mem_op_pending <= 1'b1;
              mem_st       <= MEM_AR;
              fetch_st     <= FETCH_IDLE;
            end
            // Store
            7'b0100011: begin
              awaddr_d     <= mem_addr;
              awvalid_d    <= 1'b1;
              wdata_d      <= mem_wdata;
              wstrb_d      <= 4'hF;
              wvalid_d     <= 1'b0;
              mem_op_pending <= 1'b1;
              mem_st       <= MEM_AW;
              fetch_st     <= FETCH_IDLE;
            end
            default: begin
              pc       <= pc + 4;
              fetch_st <= FETCH_IDLE;
            end
          endcase
        end
      endcase

      // ── Data Memory FSM ────────────────────────────
      case (mem_st)
        MEM_IDLE: ; // nothing

        // Store path
        MEM_AW: begin
          if (awready_d) begin
            awvalid_d <= 1'b0;
            wvalid_d  <= 1'b1;
            mem_st    <= MEM_W;
          end
        end
        MEM_W: begin
          if (wready_d) begin
            wvalid_d  <= 1'b0;
            bready_d  <= 1'b1;
            mem_st    <= MEM_B;
          end
        end
        MEM_B: begin
          if (bvalid_d) begin
            bready_d       <= 1'b0;
            mem_op_pending <= 1'b0;
            pc             <= pc + 4;
            mem_st         <= MEM_IDLE;
          end
        end

        // Load path
        MEM_AR: begin
          if (arready_d) begin
            arvalid_d <= 1'b0;
            rready_d  <= 1'b1;
            mem_st    <= MEM_R;
          end
        end
        MEM_R: begin
          if (rvalid_d) begin
            rready_d       <= 1'b0;
            mem_op_pending <= 1'b0;
            // Write loaded data to register
            if (rd != 5'h0) begin
              case (funct3)
                3'b000: regs[rd] <= {{24{rdata_d[7]}},  rdata_d[7:0]};  // LB
                3'b001: regs[rd] <= {{16{rdata_d[15]}}, rdata_d[15:0]}; // LH
                3'b010: regs[rd] <= rdata_d;                             // LW
                3'b100: regs[rd] <= {24'h0, rdata_d[7:0]};              // LBU
                3'b101: regs[rd] <= {16'h0, rdata_d[15:0]};             // LHU
                default: regs[rd] <= rdata_d;
              endcase
            end
            pc     <= pc + 4;
            mem_st <= MEM_IDLE;
          end
        end
      endcase

    end
  end

endmodule
