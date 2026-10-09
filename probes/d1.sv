// File:        d1.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Shows how the FIFO pointers behave when DEPTH is 1.

module d1;
  logic CLK = 0, nRST = 0, WEN = 0, REN = 0, clear = 0;
  logic [7:0] wdata = 0, rdata; logic full, empty, underrun, overrun; logic [0:0] count;
  socetlib_fifo #(.SIZE(8), .DEPTH(1)) dut (.*);
  always #5 CLK = ~CLK;
  initial begin
    #12 nRST = 1;
    $display("ptr width=%0d", $bits(dut.write_ptr));
    for (int i = 0; i < 5; i++) begin
      @(negedge CLK) WEN = 1; wdata = 8'hA0 + i; @(negedge CLK) WEN = 0;
      $display("after push %0d: wptr=%0d rptr=%0d rdata=%h count=%0d", i, dut.write_ptr, dut.read_ptr, rdata, count);
      REN = 1; @(negedge CLK) REN = 0;
      $display("after pop  %0d: wptr=%0d rptr=%0d count=%0d", i, dut.write_ptr, dut.read_ptr, count);
    end
    $finish;
  end
endmodule
