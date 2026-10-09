# M5 (R09): an empty FIFO stores the word when WEN and REN are both high
s/if(WEN \&\& !full \&\& !(empty \&\& REN)) begin/if(WEN \&\& !full) begin/
