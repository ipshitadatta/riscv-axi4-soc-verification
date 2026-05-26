// axi4_sva.sv — AXI4 Protocol Assertions
module axi4_sva (
  input logic       clk, rst_n,
  input logic       awvalid, awready,
  input logic [3:0] awid,
  input logic [7:0] awlen,
  input logic       wvalid, wready, wlast,
  input logic       bvalid, bready,
  input logic [3:0]  bid,
  input logic [1:0]  bresp,
  input logic       arvalid, arready,
  input logic [3:0] arid,
  input logic [7:0] arlen,
  input logic       rvalid, rready, rlast,
  input logic [3:0]  rid,
  input logic [1:0]  rresp
);

  // ── 1. AWVALID must hold until AWREADY ──────────
  property p_awvalid_stable;
    @(posedge clk) disable iff (!rst_n)
    (awvalid && !awready) |=> awvalid;
  endproperty
  A_AWVALID_STABLE: assert property (p_awvalid_stable)
    else $error("SVA FAIL: AWVALID dropped before AWREADY");

  // ── 2. WVALID must hold until WREADY ────────────
  property p_wvalid_stable;
    @(posedge clk) disable iff (!rst_n)
    (wvalid && !wready) |=> wvalid;
  endproperty
  A_WVALID_STABLE: assert property (p_wvalid_stable)
    else $error("SVA FAIL: WVALID dropped before WREADY");

  // ── 3. ARVALID must hold until ARREADY ──────────
  property p_arvalid_stable;
    @(posedge clk) disable iff (!rst_n)
    (arvalid && !arready) |=> arvalid;
  endproperty
  A_ARVALID_STABLE: assert property (p_arvalid_stable)
    else $error("SVA FAIL: ARVALID dropped before ARREADY");

  // ── 4. BVALID must hold until BREADY ────────────
  property p_bvalid_stable;
    @(posedge clk) disable iff (!rst_n)
    (bvalid && !bready) |=> bvalid;
  endproperty
  A_BVALID_STABLE: assert property (p_bvalid_stable)
    else $error("SVA FAIL: BVALID dropped before BREADY");

  // ── 5. RVALID must hold until RREADY ────────────
  property p_rvalid_stable;
    @(posedge clk) disable iff (!rst_n)
    (rvalid && !rready) |=> rvalid;
  endproperty
  A_RVALID_STABLE: assert property (p_rvalid_stable)
    else $error("SVA FAIL: RVALID dropped before RREADY");

  // ── 6. BRESP must be OKAY ────────────────────────
  property p_bresp_okay;
    @(posedge clk) disable iff (!rst_n)
    (bvalid && bready) |-> (bresp == 2'b00);
  endproperty
  A_BRESP_OKAY: assert property (p_bresp_okay)
    else $error("SVA FAIL: BRESP not OKAY");

  // ── 7. RRESP must be OKAY ────────────────────────
  property p_rresp_okay;
    @(posedge clk) disable iff (!rst_n)
    (rvalid && rready) |-> (rresp == 2'b00);
  endproperty
  A_RRESP_OKAY: assert property (p_rresp_okay)
    else $error("SVA FAIL: RRESP not OKAY");

  // ── Cover points ─────────────────────────────────
  C_AW: cover property (@(posedge clk) (awvalid && awready));
  C_W:  cover property (@(posedge clk) (wvalid  && wready && wlast));
  C_B:  cover property (@(posedge clk) (bvalid  && bready));
  C_AR: cover property (@(posedge clk) (arvalid && arready));
  C_R:  cover property (@(posedge clk) (rvalid  && rready && rlast));

endmodule
