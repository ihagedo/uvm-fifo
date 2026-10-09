// File:        fifo_if.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: FIFO port interface with driver and monitor clocking blocks.

interface fifo_if #(parameter int SIZE = 8, parameter int DEPTH = 8) (input logic CLK);
    logic                         nRST;
    logic                         WEN, REN, clear;
    logic [SIZE-1:0]              wdata;
    logic                         full, empty, underrun, overrun;
    logic [$clog2(DEPTH+1)-1:0]   count;
    logic [SIZE-1:0]              rdata;

    clocking drv_cb @(posedge CLK);
        default output #1;
        output WEN, REN, clear, wdata;
    endclocking

    clocking mon_cb @(posedge CLK);
        default input #1step;
        input nRST, WEN, REN, clear, wdata, full, empty, underrun, overrun, count, rdata;
    endclocking
endinterface
