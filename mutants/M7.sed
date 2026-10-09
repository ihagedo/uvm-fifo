# M7 (R13): reset is synchronous instead of asynchronous
s/always_ff @(posedge CLK, negedge nRST) begin/always_ff @(posedge CLK) begin/
