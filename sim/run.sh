#!/bin/bash
set -e
BASE=/mnt/ncsudrive/i/idatta2/riscv_axi4_soc
UVM=/mnt/apps/public/COE/mg_apps/questa2026.1/questasim/verilog_src/uvm-1.1d/src
SIM=$BASE/sim
INI=$SIM/modelsim.ini
SYSINI=/mnt/apps/public/COE/mg_apps/questa2026.1/questasim/modelsim.ini

cd $SIM
rm -rf work
cp $SYSINI $INI
chmod u+w $INI
vlib work
vmap -ini $INI work $SIM/work

echo "=== Compiling RTL ==="
vlog -ini $INI -sv \
  $BASE/rtl/axi4_slave.sv \
  $BASE/rtl/riscv_core.sv \
  $BASE/rtl/soc_top.sv || { echo "RTL FAILED"; exit 1; }

echo "=== Compiling TB ==="
vlog -ini $INI -sv \
  +incdir+$BASE/tb +incdir+$UVM \
  $BASE/tb/soc_tb_top.sv || { echo "TB FAILED"; exit 1; }

echo "=== Running Simulation ==="
vsim -ini $INI -c -L mtiUvm work.soc_tb_top \
  -do "run -all; quit" 2>&1 | tee sim.log

echo "=== Results ==="
grep -E "MATCH|MISMATCH|UVM_ERROR|UVM_FATAL|ALL REGISTERS" sim.log
