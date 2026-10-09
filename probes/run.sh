#!/bin/bash
# File:        run.sh
# Author:      Isaac Hagedorn
# Date:        2026-10-08
# Description: Reruns the probe simulations behind the FIFO spec. Build files go to ./build.

set -u
cd "$(dirname "$0")"
RTL=${RTL:-$(cd ../rtl && pwd)/socetlib_fifo.sv}
B=build; rm -rf $B; mkdir -p $B
VFLAGS="--binary --timing -Wno-fatal -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC"
vl() { verilator $VFLAGS --top-module $1 -Mdir $B/v_$1$2 $3 "$RTL" $1.sv >$B/v_$1$2.log 2>&1 && $B/v_$1$2/V$1; }
iv() { iverilog -g2012 $3 -o $B/i_$1$2 "$RTL" $1.sv 2>/dev/null && vvp -n $B/i_$1$2; }
echo "== RTL: $RTL"
echo "== $(verilator --version); $(iverilog -V 2>&1 | head -1)"
echo; echo "== probe.sv: 14 edge-case checks per DEPTH (spec R02-R15)"
for d in 1 2 4 8; do
  echo "verilator: $(vl probe _$d -DD=$d | grep -E 'FAIL|DONE' | tr '\n' ' ')"
  echo "iverilog:  $(iv probe _$d -DD=$d | grep -E 'FAIL|DONE' | tr '\n' ' ')"
done
echo; echo "== wave.sv: cycle table in fifo-spec.md section 7.3 (DEPTH=2)"
vl wave "" "" | grep '^|'
if diff <(vl wave "" "" | grep "^|") <(iv wave "" "" | grep "^|") >/dev/null; then
  echo "iverilog: identical signal values"; else echo "iverilog: DIFFERS"; fi
echo; echo "== d1.sv: DEPTH=1 (spec Q1, fixed in 1.1)"
echo "-- verilator"; vl d1 "" "" | grep -v '^-'
echo "-- iverilog";  iv d1 "" "" | grep -v -e '^-' -e finish
echo; echo "== s1.sv: SIZE=1 DEPTH=2 (spec Q3)"
echo "verilator: $(vl s1 "" "" | grep SIZE)"; echo "iverilog:  $(iv s1 "" "" | grep SIZE)"
