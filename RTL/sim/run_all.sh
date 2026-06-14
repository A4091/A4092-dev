#!/bin/bash
# Full A4092/A4770 RTL testbench suite (iverilog): module benches + top-level
# Zorro III slave BFM + DMA-master BFM, both variants.
cd "$(dirname "$0")"
RTL=..
TBS="tb_sidregister tb_buffercontrol tb_parallelrom tb_interrupthandling tb_autoconfig tb_scsiaccess tb_dmamaster tb_dmaarbiter tb_spirom"
declare -A SRC
SRC[tb_sidregister]=sidregister.v;        SRC[tb_buffercontrol]=buffercontrol.v
SRC[tb_parallelrom]=parallelrom.v;        SRC[tb_interrupthandling]=interrupthandling.v
SRC[tb_autoconfig]=autoconfig.v;          SRC[tb_scsiaccess]=scsiaccess.v
SRC[tb_dmamaster]=dmamaster.v;            SRC[tb_dmaarbiter]=dmaarbiter.v
SRC[tb_spirom]=spirom.v
TOPSRC="$RTL/A4092.v $RTL/autoconfig.v $RTL/buffercontrol.v $RTL/dmaarbiter.v $RTL/dmamaster.v $RTL/scsiaccess.v $RTL/interrupthandling.v $RTL/sidregister.v $RTL/spirom.v"
pass=0; fail=0
run() { out=$(timeout 150 vvp -n "$2" 2>&1)
  echo "$out" | grep -E "===|PASS|FAIL|RESULT|VIOLATION|burst:" | sed "s/^/   /"
  echo "$out" | grep -qE "FAIL|VIOLATION" && fail=$((fail+1)) || pass=$((pass+1)); }
for tb in $TBS; do echo "==================== $tb ===================="
  if iverilog -g2012 -I. -o /tmp/$tb.vvp $tb.v $RTL/${SRC[$tb]} 2>/tmp/$tb.cerr; then run $tb /tmp/$tb.vvp
  else echo "   COMPILE ERROR"; sed "s/^/   /" /tmp/$tb.cerr; fail=$((fail+1)); fi; done
for V in A4092c A4770; do
  echo "============ tb_a4092_zorro3 ($V) [slave BFM] ============"
  if iverilog -g2012 -D$V -I. -o /tmp/z3_$V.vvp tb_a4092_zorro3.v $TOPSRC 2>/tmp/z3_$V.cerr; then run z3_$V /tmp/z3_$V.vvp
  else echo "   COMPILE ERROR"; sed "s/^/   /" /tmp/z3_$V.cerr; fail=$((fail+1)); fi
  echo "============ tb_a4092_dma ($V) [DMA-master BFM] ============"
  if iverilog -g2012 -D$V -I. -o /tmp/dma_$V.vvp tb_a4092_dma.v $TOPSRC 2>/tmp/dma_$V.cerr; then run dma_$V /tmp/dma_$V.vvp
  else echo "   COMPILE ERROR"; sed "s/^/   /" /tmp/dma_$V.cerr; fail=$((fail+1)); fi; done
echo "==================== tb_u6_contention ===================="
if iverilog -g2012 -o /tmp/u6.vvp tb_u6_contention.v 2>/tmp/u6.cerr; then
  out=$(vvp -n /tmp/u6.vvp 2>&1)
  echo "$out" | grep -E "245 |543 |PASS|FAIL" | sed "s/^/   /"
  echo "$out" | grep -q PASS && pass=$((pass+1)) || fail=$((fail+1))
else echo "   COMPILE ERROR"; fail=$((fail+1)); fi

echo "============================================="
echo "SUITE TOTAL: $pass passed, $fail failed"
