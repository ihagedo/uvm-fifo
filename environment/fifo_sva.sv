// File:        fifo_sva.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Assertions on the FIFO ports, bound into the DUT.

`include "uvm_macros.svh"
module fifo_sva
    import uvm_pkg::*;
#(
    parameter int SIZE = 8,
    parameter int DEPTH = 8
)(
    input logic                       CLK, nRST, WEN, REN, clear,
    input logic [SIZE-1:0]            wdata, rdata,
    input logic                       full, empty, underrun, overrun,
    input logic [$clog2(DEPTH+1)-1:0] count,
    input logic [$clog2(DEPTH)-1:0]   write_ptr
);
    default clocking @(posedge CLK); endclocking
    default disable iff (!nRST);

    SVA01: assert property (count <= DEPTH)
        else `uvm_error("SVA01", $sformatf("R05: count %0d > DEPTH %0d", count, DEPTH))
    SVA02: assert property (full == (count == DEPTH) && empty == (count == 0))
        else `uvm_error("SVA02", $sformatf("R05: full=%b empty=%b but count=%0d", full, empty, count))
    SVA03: assert property (!WEN && !REN && !clear && !empty |=> $stable(rdata) && $stable(count))
        else `uvm_error("SVA03", "R04: rdata or count changed on an idle cycle (peek)")
    SVA04: assert property ($rose(overrun) |-> $past(WEN && full && !clear))
        else `uvm_error("SVA04", "R06: overrun rose without a write to a full FIFO")
    SVA05: assert property ($rose(underrun) |-> $past(REN && empty && !clear))
        else `uvm_error("SVA05", "R07: underrun rose without a read from an empty FIFO")
    SVA06a: assert property (overrun && !clear |=> overrun)
        else `uvm_error("SVA06", "R11: overrun dropped without clear or nRST")
    SVA06b: assert property (underrun && !clear |=> underrun)
        else `uvm_error("SVA06", "R11: underrun dropped without clear or nRST")
    SVA07: assert property (clear |=> empty && !full && count == 0 && !overrun && !underrun)
        else `uvm_error("SVA07", "R12: FIFO not empty with flags clear after clear")
    SVA08: assert property (full && WEN && REN && !clear |=> full && $stable(rdata) && overrun)
        else `uvm_error("SVA08", "R08: full + WEN + REN must do neither operation and set overrun")
    SVA09: assert property (empty && WEN && REN && !clear |=> empty && underrun)
        else `uvm_error("SVA09", "R09: empty + WEN + REN must do neither operation and set underrun")
    SVA10a: assert property (!$isunknown({WEN, REN, clear}))
        else `uvm_error("SVA10", "AS3: WEN/REN/clear unknown while out of reset")
    SVA10b: assert property (WEN |-> !$isunknown(wdata))
        else `uvm_error("SVA10", "AS3: wdata unknown during a write")

    C_WRAP: cover property (WEN && !clear && !full && !(empty && REN) && write_ptr == DEPTH - 1);
endmodule
