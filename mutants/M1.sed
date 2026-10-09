# M1 (R08): a full FIFO pops when WEN and REN are both high
s/if(REN \&\& !empty \&\& !(full \&\& WEN)) begin/if(REN \&\& !empty) begin/
