// File:        fifo_obs.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: One observation of the FIFO ports, used for actual and expected values.

class fifo_obs extends uvm_object;
    `uvm_object_utils(fifo_obs)

    typedef enum {EDGE, RESET} kind_e;
    kind_e            kind;
    longint unsigned  cycle;

    logic             nRST, WEN, REN, clear;
    logic [SIZE-1:0]  wdata;

    logic             full, empty, underrun, overrun;
    logic [CW-1:0]    count;
    logic [SIZE-1:0]  rdata;
    bit               rdata_valid = 1;   // rdata is defined (FIFO not empty)

    function new(string name = "fifo_obs");
        super.new(name);
    endfunction

    function string outputs2string();
        return $sformatf("count=%0d full=%b empty=%b overrun=%b underrun=%b rdata=%h",
                         count, full, empty, overrun, underrun, rdata);
    endfunction

    function string inputs2string();
        return $sformatf("nRST=%b WEN=%b REN=%b clear=%b wdata=%h", nRST, WEN, REN, clear, wdata);
    endfunction
endclass
