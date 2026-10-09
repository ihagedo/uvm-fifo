// File:        probe.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Edge-case checks of the FIFO for one DEPTH.

`ifndef D
  `define D 4
`endif
module probe;
  localparam int SIZE = 8, DEPTH = `D;
  logic CLK = 0, nRST = 1, WEN = 0, REN = 0, clear = 0;
  logic [SIZE-1:0] wdata = 0, rdata;
  logic full, empty, underrun, overrun;
  logic [$clog2(DEPTH+1)-1:0] count;
  int fails = 0;
  socetlib_fifo #(.SIZE(SIZE), .DEPTH(DEPTH)) dut (.*);
  always #5 CLK = ~CLK;

  task automatic chk(string what, logic cond);
    if (cond) $display("PASS  D=%0d  %s", DEPTH, what);
    else begin $display("FAIL  D=%0d  %s  (count=%0d full=%b empty=%b ovr=%b udr=%b rdata=%h)", DEPTH, what, count, full, empty, overrun, underrun, rdata); fails++; end
  endtask
  task automatic cyc(logic w, logic r, logic c = 0, logic [SIZE-1:0] d = 0);
    @(negedge CLK); WEN = w; REN = r; clear = c; wdata = d;
    @(posedge CLK); #1; WEN = 0; REN = 0; clear = 0;
  endtask
  task automatic do_reset();
    @(negedge CLK); nRST = 0; #2;
    chk("async reset: flags/count clear while nRST low, before any clock edge", count == 0 && empty && !full && !overrun && !underrun);
    @(negedge CLK); nRST = 1;
  endtask

  initial begin
    do_reset();
    chk("after reset rdata == 0", rdata == 0);
    for (int i = 0; i < DEPTH; i++) cyc(1, 0, 0, 8'h10 + i);
    chk("full after DEPTH writes", full && !empty && count == DEPTH);
    chk("rdata shows head without REN (peek)", rdata == 8'h10);
    cyc(1, 1, 0, 8'hEE);
    chk("full & WEN & REN: read suppressed (count stays DEPTH, head unchanged)", count == DEPTH && rdata == 8'h10);
    chk("full & WEN & REN: overrun set, underrun clear", overrun && !underrun);
    cyc(0, 1);
    chk("overrun sticky after a good read", overrun && count == DEPTH-1 && rdata == (DEPTH > 1 ? 8'h11 : rdata));
    cyc(1, 0, 1, 8'hAA);
    chk("clear with WEN: clear wins, empty, flags cleared", empty && count == 0 && !overrun && !underrun);
    cyc(1, 1, 0, 8'h55);
    chk("empty & WEN & REN: write suppressed (still empty)", empty && count == 0);
    chk("empty & WEN & REN: underrun set, overrun clear", underrun && !overrun);
    cyc(1, 0, 0, 8'h66);
    chk("write after underrun accepted; underrun sticky", count == 1 && rdata == 8'h66 && underrun);
    cyc(0, 0, 1);
    if (DEPTH >= 2) begin
      cyc(1, 0, 0, 8'h01); cyc(1, 1, 0, 8'h02);
      chk("mid occupancy WEN & REN: count unchanged, head advanced", count == 1 && rdata == 8'h02 && !overrun && !underrun);
      cyc(0, 1);
    end
    begin
      bit ok; ok = 1;
      for (int i = 0; i < 3*DEPTH; i++) begin
        cyc(1, 0, 0, 8'hC0 + i);
        if (rdata !== 8'hC0 + i) ok = 0;
        cyc(0, 1);
        if (empty !== 1) ok = 0;
      end
      chk("pointer wraparound keeps FIFO order (3*DEPTH push/pop pairs)", ok);
    end
    cyc(1, 0, 0, 8'h77); cyc(0, 0, 1);
    chk("after clear: empty, rdata shows stale storage (not 0)", empty && rdata != 0);
    $display("DONE D=%0d fails=%0d", DEPTH, fails);
    $finish;
  end
endmodule
