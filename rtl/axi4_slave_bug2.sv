module axi4_slave #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,
  parameter ID_WIDTH   = 4,
  parameter NUM_REGS   = 16
)(
  input  logic                    clk, rst_n,
  input  logic [ID_WIDTH-1:0]     awid,
  input  logic [ADDR_WIDTH-1:0]   awaddr,
  input  logic [7:0]              awlen,
  input  logic [2:0]              awsize,
  input  logic [1:0]              awburst,
  input  logic                    awvalid,
  output logic                    awready,
  input  logic [DATA_WIDTH-1:0]   wdata,
  input  logic [DATA_WIDTH/8-1:0] wstrb,
  input  logic                    wlast,
  input  logic                    wvalid,
  output logic                    wready,
  output logic [ID_WIDTH-1:0]     bid,
  output logic [1:0]              bresp,
  output logic                    bvalid,
  input  logic                    bready,
  input  logic [ID_WIDTH-1:0]     arid,
  input  logic [ADDR_WIDTH-1:0]   araddr,
  input  logic [7:0]              arlen,
  input  logic [2:0]              arsize,
  input  logic [1:0]              arburst,
  input  logic                    arvalid,
  output logic                    arready,
  output logic [ID_WIDTH-1:0]     rid,
  output logic [DATA_WIDTH-1:0]   rdata,
  output logic [1:0]              rresp,
  output logic                    rlast,
  output logic                    rvalid,
  input  logic                    rready
);

  // ── Declarations first — before any assign ──────
  logic [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];

  typedef enum logic [1:0] {WR_IDLE, WR_DATA, WR_RESP} wr_st_t;
  typedef enum logic [1:0] {RD_IDLE, RD_DATA}          rd_st_t;

  wr_st_t wr_st;
  rd_st_t rd_st;

  logic [ID_WIDTH-1:0]   wr_id,   rd_id;
  logic [ADDR_WIDTH-1:0] wr_addr, rd_addr;
  logic [7:0]            wr_len,  rd_len;
  logic [1:0]            wr_burst,rd_burst;

  // ── Combinational read data ──────────────────────
  // rd_addr is declared above so this is now legal
  assign rdata = regs[((rd_addr+4) >> 2) & (NUM_REGS-1)];

  function automatic int idx(input logic [ADDR_WIDTH-1:0] a);
    return (a >> 2) & (NUM_REGS - 1);
  endfunction

  // ── Write path ───────────────────────────────────
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i=0;i<NUM_REGS;i++) regs[i] <= 32'hDEAD_0000 + i;
      wr_st   <= WR_IDLE;
      awready <= 0; wready <= 0; bvalid <= 0;
      bid     <= 0; bresp  <= 0;
      wr_id   <= 0; wr_addr <= 0; wr_len <= 0; wr_burst <= 0;
    end else begin
      case (wr_st)
        WR_IDLE: begin
          awready <= 1; wready <= 0; bvalid <= 0;
          if (awvalid && awready) begin
            wr_id    <= awid;  wr_addr <= awaddr;
            wr_len   <= awlen; wr_burst <= awburst;
            awready  <= 0;     wready  <= 1;
            wr_st    <= WR_DATA;
          end
        end
        WR_DATA: begin
          if (wvalid && wready) begin
            for (int i=0;i<DATA_WIDTH/8;i++)
              if (wstrb[i]) regs[idx(wr_addr)][i*8+:8] <= wdata[i*8+:8];
            if (wr_burst == 2'b01) wr_addr <= wr_addr + 4;
            if (wlast) begin
              wready <= 0; bvalid <= 1;
              bid    <= wr_id; bresp <= 0;
              wr_st  <= WR_RESP;
            end
          end
        end
        WR_RESP: begin
          if (bvalid && bready) begin
            bvalid <= 0; wr_st <= WR_IDLE;
          end
        end
        default: wr_st <= WR_IDLE;
      endcase
    end
  end

  // ── Read path ────────────────────────────────────
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_st   <= RD_IDLE;
      arready <= 0; rvalid <= 0; rlast <= 0;
      rid     <= 0; rresp  <= 0;
      rd_id   <= 0; rd_addr <= 0; rd_len <= 0; rd_burst <= 0;
    end else begin
      case (rd_st)
        RD_IDLE: begin
          arready <= 1; rvalid <= 0; rlast <= 0;
          if (arvalid && arready) begin
            rd_id    <= arid;  rd_addr <= araddr;
            rd_len   <= arlen; rd_burst <= arburst;
            arready  <= 0;     rd_st <= RD_DATA;
          end
        end
        RD_DATA: begin
          rvalid <= 1;
          rid    <= rd_id;
          rresp  <= 0;
          rlast  <= (rd_len == 0);
          if (rvalid && rready) begin
            if (rd_len == 0) begin
              rvalid <= 0; rlast <= 0; rd_st <= RD_IDLE;
            end else begin
              rd_len <= rd_len - 1;
              if (rd_burst == 2'b01) rd_addr <= rd_addr + 4;
            end
          end
        end
        default: rd_st <= RD_IDLE;
      endcase
    end
  end

endmodule
