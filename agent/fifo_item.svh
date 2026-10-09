// File:        fifo_item.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: One cycle of FIFO inputs, or a reset request.

class fifo_item extends uvm_sequence_item;
    `uvm_object_utils(fifo_item)

    typedef enum {OP, ASYNC_RESET} kind_e;
    kind_e kind = OP;

    rand bit            WEN, REN, clear;
    rand bit [SIZE-1:0] wdata;

    int unsigned pct_wen = 50, pct_ren = 50, pct_clear = 1;
    constraint c_weights {
        WEN   dist {1 := pct_wen,   0 := 100 - pct_wen};
        REN   dist {1 := pct_ren,   0 := 100 - pct_ren};
        clear dist {1 := pct_clear, 0 := 100 - pct_clear};
    }

    int unsigned rst_offset_pct = 30;
    int unsigned rst_edges      = 1;

    function new(string name = "fifo_item");
        super.new(name);
    endfunction

    function string convert2string();
        if (kind == ASYNC_RESET)
            return $sformatf("ASYNC_RESET at %0d%% of the cycle for %0d edge(s)", rst_offset_pct, rst_edges);
        return $sformatf("WEN=%b REN=%b clear=%b wdata=%h", WEN, REN, clear, wdata);
    endfunction
endclass
