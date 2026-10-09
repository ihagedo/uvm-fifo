// File:        wave.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Prints the cycle table used in the FIFO spec.

module wave;
  logic CLK = 0, nRST = 0, WEN = 0, REN = 0, clear = 0;
  logic [7:0] wdata = 0, rdata; logic full, empty, underrun, overrun; logic [1:0] count;
  socetlib_fifo #(.SIZE(8), .DEPTH(2)) dut (.*);
  always #5 CLK = ~CLK;
  task automatic row(int n, logic w, logic r, logic c, logic [7:0] d);
    string ws, rs;
    WEN = w; REN = r; clear = c; wdata = d; #4;
    if (w) ws = $sformatf("`%h`", d); else ws = "-";
    if (empty) rs = $sformatf("(`%h`)", rdata); else rs = $sformatf("`%h`", rdata);
    $display("| %0d | %b | %b | %b | %s | %b | %b | %0d | %b | %b | %s |", n, w, r, c, ws,
             full, empty, count, overrun, underrun, rs);
    @(posedge CLK); #1;
  endtask
  initial begin
    #7 nRST = 1; @(posedge CLK); #1;
    row(0, 0, 0, 0, 0);
    row(1, 1, 0, 0, 8'hA1);
    row(2, 1, 0, 0, 8'hB2);
    row(3, 1, 1, 0, 8'hC3);
    row(4, 0, 1, 0, 0);
    row(5, 0, 1, 0, 0);
    row(6, 0, 1, 0, 0);
    row(7, 1, 0, 1, 8'hD4);
    row(8, 1, 0, 0, 8'hE5);
    row(9, 0, 0, 0, 0);
    $finish;
  end
endmodule
