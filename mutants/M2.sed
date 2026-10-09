# M2 (R11): overrun is not sticky; it drops again on the next cycle
s/overrun_next = overrun;/overrun_next = 1'b0;/
