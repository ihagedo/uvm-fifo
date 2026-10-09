// File:        tb_top.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Top level: clock, interface, the FIFO under test and run_test.

`timescale 1ns/1ps
module tb_top;
    import uvm_pkg::*;
    import fifo_tb_pkg::*;

    logic CLK = 1'b0;
    always #(PERIOD / 2) CLK = ~CLK;

    fifo_if #(.SIZE(SIZE), .DEPTH(DEPTH)) vif (CLK);

    socetlib_fifo #(.SIZE(SIZE), .DEPTH(DEPTH)) dut (
        .CLK      (CLK),
        .nRST     (vif.nRST),
        .WEN      (vif.WEN),
        .REN      (vif.REN),
        .clear    (vif.clear),
        .wdata    (vif.wdata),
        .full     (vif.full),
        .empty    (vif.empty),
        .underrun (vif.underrun),
        .overrun  (vif.overrun),
        .count    (vif.count),
        .rdata    (vif.rdata)
    );

    bind socetlib_fifo fifo_sva #(.SIZE(SIZE), .DEPTH(DEPTH)) u_sva (
        .CLK(CLK), .nRST(nRST), .WEN(WEN), .REN(REN), .clear(clear),
        .wdata(wdata), .rdata(rdata), .full(full), .empty(empty),
        .underrun(underrun), .overrun(overrun), .count(count), .write_ptr(write_ptr)
    );

`ifdef WAVES
    // make WAVES=1: FST on Verilator, VCD elsewhere
    initial begin
`ifdef VERILATOR
        $dumpfile("waves.fst");
`else
        $dumpfile("waves.vcd");
`endif
        $dumpvars(0, tb_top);
    end
`endif

    initial begin
        vif.nRST  = 1'b1;
        vif.WEN   = 1'b0;
        vif.REN   = 1'b0;
        vif.clear = 1'b0;
        vif.wdata = '0;
        uvm_config_db #(fifo_vif)::set(null, "uvm_test_top.env.agt.*", "vif", vif);
        run_test();
    end
endmodule
