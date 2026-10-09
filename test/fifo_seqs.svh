// File:        fifo_seqs.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Sequences for the FIFO test plan rows.

class fifo_base_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_base_seq)

    function new(string name = "fifo_base_seq");
        super.new(name);
    endfunction

    function bit [SIZE-1:0] rand_word();
        return SIZE'({$urandom, $urandom});
    endfunction

    task op(bit w, bit r, bit c = 0, bit [SIZE-1:0] d = rand_word());
        fifo_item it = fifo_item::type_id::create("it");
        start_item(it);
        it.kind  = fifo_item::OP;
        it.WEN   = w;
        it.REN   = r;
        it.clear = c;
        it.wdata = d;
        finish_item(it);
    endtask

    task write(bit [SIZE-1:0] d = rand_word()); op(1, 0, 0, d); endtask
    task read();                                 op(0, 1);       endtask
    task clr();                                  op(0, 0, 1);    endtask
    task idle(int unsigned n = 1);  repeat (n) op(0, 0);         endtask
    task fill(int unsigned n);      repeat (n) write();          endtask
    task drain(int unsigned n);     repeat (n) read();           endtask

    task async_reset(int unsigned pct = 30, int unsigned edges = 1);
        fifo_item it = fifo_item::type_id::create("it");
        start_item(it);
        it.kind           = fifo_item::ASYNC_RESET;
        it.rst_offset_pct = pct;
        it.rst_edges      = edges;
        finish_item(it);
    endtask

    function void boundary_occs(ref int unsigned occs[$], input bit with_mid = 1);
        int unsigned cand[$] = '{0, 1, DEPTH / 2, DEPTH - 1, DEPTH};
        occs.delete();
        foreach (cand[i])
            if (!(cand[i] inside {occs}) && (with_mid || cand[i] != DEPTH / 2 || DEPTH <= 2))
                occs.push_back(cand[i]);
    endfunction
endclass

class power_on_reset_seq extends fifo_base_seq;
    `uvm_object_utils(power_on_reset_seq)
    function new(string name = "power_on_reset_seq"); super.new(name); endfunction
    task body();
        async_reset(50, 2);
    endtask
endclass

class tail_seq extends fifo_base_seq;
    `uvm_object_utils(tail_seq)
    function new(string name = "tail_seq"); super.new(name); endfunction
    task body();
        idle(5);
    endtask
endclass

class write_read_seq extends fifo_base_seq;
    `uvm_object_utils(write_read_seq)
    function new(string name = "write_read_seq"); super.new(name); endfunction
    task body();
        clr();
        write();
        idle();
        read();
        idle();
    endtask
endclass

class peek_seq extends fifo_base_seq;
    `uvm_object_utils(peek_seq)
    function new(string name = "peek_seq"); super.new(name); endfunction
    task body();
        int unsigned ks[$] = '{1, DEPTH / 2, DEPTH};
        foreach (ks[i]) begin
            if (ks[i] == 0) continue;
            clr();
            fill(ks[i]);
            idle(3);
        end
        clr();
    endtask
endclass

class fill_drain_seq extends fifo_base_seq;
    `uvm_object_utils(fill_drain_seq)
    function new(string name = "fill_drain_seq"); super.new(name); endfunction
    task body();
        clr();
        fill(DEPTH);
        idle();
        drain(DEPTH);
        idle();
    endtask
endclass

class pattern_seq extends fifo_base_seq;
    `uvm_object_utils(pattern_seq)
    function new(string name = "pattern_seq"); super.new(name); endfunction
    task body();
        bit [SIZE-1:0] h55 = {(SIZE + 1) / 2 {2'b01}};
        bit [SIZE-1:0] pats[$];
        pats.push_back('0);
        pats.push_back('1);
        pats.push_back(h55);
        pats.push_back(~h55);
        for (int b = 0; b < SIZE; b++) pats.push_back(SIZE'(1) << b);
        clr();
        foreach (pats[i]) begin
            write(pats[i]);
            read();
        end
        foreach (pats[i]) begin
            write(pats[i]);
            if (i % DEPTH == DEPTH - 1) drain(DEPTH);
        end
        drain(pats.size() % DEPTH);
        idle();
    endtask
endclass

class wrap_seq extends fifo_base_seq;
    `uvm_object_utils(wrap_seq)
    function new(string name = "wrap_seq"); super.new(name); endfunction
    task body();
        clr();
        repeat (4 * DEPTH) begin
            write();
            read();
        end
        repeat (4) begin
            fill(DEPTH);
            drain(DEPTH);
        end
    endtask
endclass

class rw_same_cycle_seq extends fifo_base_seq;
    `uvm_object_utils(rw_same_cycle_seq)
    function new(string name = "rw_same_cycle_seq"); super.new(name); endfunction
    task body();
        for (int unsigned k = 1; k < DEPTH; k++) begin
            clr();
            fill(k);
            repeat (2 * DEPTH) op(1, 1);
        end
        clr();
    endtask
endclass

class full_rw_seq extends fifo_base_seq;
    `uvm_object_utils(full_rw_seq)
    function new(string name = "full_rw_seq"); super.new(name); endfunction
    task body();
        clr();
        fill(DEPTH);
        op(1, 1);
        drain(DEPTH);
        idle();
    endtask
endclass

class empty_rw_seq extends fifo_base_seq;
    `uvm_object_utils(empty_rw_seq)
    function new(string name = "empty_rw_seq"); super.new(name); endfunction
    task body();
        clr();
        op(1, 1);
        write();
        read();
        idle();
    endtask
endclass

class edge_seq extends fifo_base_seq;
    `uvm_object_utils(edge_seq)
    function new(string name = "edge_seq"); super.new(name); endfunction
    task body();
        int unsigned occs[$];
        boundary_occs(occs, 0);
        foreach (occs[i])
            for (int o = 0; o < 4; o++) begin
                clr();
                fill(occs[i]);
                op(o[0], o[1]);
                idle();
            end
        clr();
    endtask
endclass

class overrun_seq extends fifo_base_seq;
    `uvm_object_utils(overrun_seq)
    function new(string name = "overrun_seq"); super.new(name); endfunction
    task body();
        clr();
        fill(DEPTH);
        write();
        idle();
        repeat (5) write();
        repeat (2 * DEPTH) begin
            read();
            write();
        end
        drain(DEPTH);
        idle();
    endtask
endclass

class underrun_seq extends fifo_base_seq;
    `uvm_object_utils(underrun_seq)
    function new(string name = "underrun_seq"); super.new(name); endfunction
    task body();
        clr();
        read();
        idle();
        repeat (5) read();
        repeat (DEPTH) begin
            write();
            read();
        end
        idle();
    endtask
endclass

class flags_both_seq extends fifo_base_seq;
    `uvm_object_utils(flags_both_seq)
    function new(string name = "flags_both_seq"); super.new(name); endfunction
    task body();
        clr();
        read();
        fill(DEPTH);
        write();
        drain(DEPTH);
        fill(DEPTH / 2 + 1);
        idle(2);
        clr();
        idle();
    endtask
endclass

class clear_seq extends fifo_base_seq;
    `uvm_object_utils(clear_seq)
    function new(string name = "clear_seq"); super.new(name); endfunction
    task body();
        int unsigned occs[$] = '{0, DEPTH / 2, DEPTH};
        foreach (occs[i])
            for (int o = 0; o < 4; o++) begin
                clr();
                fill(occs[i]);
                op(o[0], o[1], 1);
                write();
                read();
                idle();
            end
    endtask
endclass

class async_reset_seq extends fifo_base_seq;
    `uvm_object_utils(async_reset_seq)
    function new(string name = "async_reset_seq"); super.new(name); endfunction
    task body();
        repeat (8) begin
            fill($urandom_range(1, DEPTH));
            write();
            async_reset($urandom_range(10, 90), $urandom_range(1, 3));
            write();
            idle();
            read();
            idle();
        end
    endtask
endclass

class random_seq extends fifo_base_seq;
    `uvm_object_utils(random_seq)
    typedef enum {PRODUCER_HEAVY, CONSUMER_HEAVY, BALANCED} mode_e;
    mode_e       mode   = BALANCED;
    int unsigned cycles = 10000;

    function new(string name = "random_seq"); super.new(name); endfunction

    task body();
        int unsigned pw = (mode == PRODUCER_HEAVY) ? 70 : (mode == CONSUMER_HEAVY) ? 30 : 50;
        int unsigned pr = 100 - pw;
        repeat (cycles) begin
            fifo_item it = fifo_item::type_id::create("it");
            if ($urandom_range(0, 1999) == 0) begin
                async_reset($urandom_range(10, 90), $urandom_range(1, 2));
                continue;
            end
            start_item(it);
            it.pct_wen   = pw;
            it.pct_ren   = pr;
            it.pct_clear = 1;
            if (!it.randomize())
                `uvm_fatal("RAND", "randomize() failed")
            finish_item(it);
        end
    endtask
endclass
