// File:        s1.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Checks the FIFO with SIZE=1 and DEPTH=2.

module s1;
  logic CLK = 0, nRST = 0, WEN = 0, REN = 0, clear = 0;
  logic [0:0] wdata = 0, rdata; logic full, empty, underrun, overrun; logic [1:0] count;
  int fails = 0; bit pat [6] = '{1,0,1,1,0,0};
  socetlib_fifo #(.SIZE(1), .DEPTH(2)) dut (.*);
  always #5 CLK = ~CLK;
  initial begin
    #7 nRST = 1;
    foreach (pat[i]) begin
      @(negedge CLK) WEN = 1; wdata = pat[i]; @(negedge CLK) WEN = 0;
      if (rdata !== pat[i]) fails++;
      REN = 1; @(negedge CLK) REN = 0;
    end
    $display("SIZE=1 DEPTH=2 fails=%0d", fails); $finish;
  end
endmodule
