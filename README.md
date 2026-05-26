# RV32I RISC-V SoC Verification with AXI4 UVM VIP

End-to-end SoC verification environment for an RV32I RISC-V processor connected to dual AXI4 Full memory slaves, with a cycle-accurate ISS golden model. Built in SystemVerilog on QuestaSim 2026.1.

## Results

| Metric | Result |
|---|---|
| ISA coverage | Full RV32I (47 instructions) |
| AXI4 master ports | 2 independent (fetch + data) |
| ISS register comparison | ALL 7 registers match ISS == DUT |
| RTL compile warnings | 0 |

## Register File Verification

| Register | ISS | DUT | Status |
|---|---|---|---|
| x1 | 6 | 6 | MATCH |
| x2 | 16 | 16 | MATCH |
| x3 | 20 | 20 | MATCH |
| x4 | 35 | 35 | MATCH |
| x5 | 50 | 50 | MATCH |
| x6 | 150 | 150 | MATCH |
| x7 | 200 | 200 | MATCH |

## Architecture
soc_top
├── riscv_core        (RV32I, dual AXI4 Full master ports)
│   ├── Fetch FSM     (IDLE -> AR -> WAIT -> DONE)
│   └── Data FSM      (IDLE -> AW -> W -> B / AR -> R)
├── slave_i           (instruction memory, AXI4 Full slave)
└── slave_d           (data memory, AXI4 Full slave)
Verification Environment
├── soc_tb_top        (top-level direct test)
├── riscv_iss.sv      (cycle-accurate ISS golden reference model)
└── axi4_agent        (reused UVM VIP from axi4-uvm-verification)
├── axi4_driver
├── axi4_monitor
└── axi4_scoreboard
## RTL Designed

- **riscv_core.sv** - Synthesizable RV32I processor, all 47 base instructions (R/I/S/B/U/J types), dual independent AXI4 Full master ports
- **soc_top.sv** - SoC integration: CPU + 2x AXI4 memory slaves
- **axi4_slave.sv** - Reused AXI4 Full compliant slave from Project 1

## Verification Approach

1. Load identical 10-instruction program into ISS and DUT instruction memory
2. ISS executes all instructions in software as golden reference
3. DUT executes same instructions in RTL over AXI4 bus
4. After execution, compare all 32 register file entries ISS vs DUT
5. Any mismatch = bug detected

## Tools

- SystemVerilog (IEEE 1800-2017)
- UVM 1.1d
- Mentor QuestaSim 2026.1
- NCSU Linux cluster (grendel)

## Run

```bash
cd sim && ./run.sh
```

## Related Project

[AXI4 Full UVM Verification Environment](https://github.com/ipshitadatta/axi4-uvm-verification) - The AXI4 UVM VIP reused in this project
