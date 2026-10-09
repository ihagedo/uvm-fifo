// File:        fifo_coverage.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Functional coverage for the FIFO test plan.

class fifo_coverage extends uvm_subscriber #(fifo_obs);
    `uvm_component_utils(fifo_coverage)

    int unsigned occ;   // count before the edge
    bit [1:0]    op;   // {REN, WEN}
    int unsigned pat;   // wdata pattern class
    int unsigned evt;   // flag event for cg_flags

    fifo_obs prev;

    covergroup cg_ops;
        cp_occ: coverpoint occ {
            bins EMPTY       = {0};
            bins ONE         = {1};
            bins MID         = {[2 : DEPTH - 2]};
            bins ALMOST_FULL = {DEPTH - 1};
            bins FULL        = {DEPTH};
        }
        cp_op: coverpoint op {
            bins IDLE  = {2'b00};
            bins WRITE = {2'b01};
            bins READ  = {2'b10};
            bins BOTH  = {2'b11};
        }
        occ_x_op: cross cp_occ, cp_op;
    endgroup

    covergroup cg_clear;
        cp_occ: coverpoint occ {
            bins EMPTY = {0};
            bins MID   = {[1 : DEPTH - 1]};
            bins FULL  = {DEPTH};
        }
        cp_op: coverpoint op {
            bins IDLE  = {2'b00};
            bins WRITE = {2'b01};
            bins READ  = {2'b10};
            bins BOTH  = {2'b11};
        }
        clear_x_occ_x_op: cross cp_occ, cp_op;
    endgroup

    covergroup cg_flags;
        cp_evt: coverpoint evt {
            bins OVERRUN_RISE      = {1};
            bins UNDERRUN_RISE     = {2};
            bins BOTH_SET          = {3};
            bins CLEARED_BY_CLEAR  = {4};
            bins CLEARED_BY_RESET  = {5};
        }
    endgroup

    covergroup cg_data;
        cp_wdata: coverpoint pat {
            bins ZEROS = {0};
            bins ONES  = {1};
            bins H55   = {2};   // 0101...
            bins HAA   = {3};   // 1010...
            bins OTHER = {4};
        }
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg_ops   = new();
        cg_clear = new();
        cg_flags = new();
        cg_data  = new();
    endfunction

    function void flag_event(int unsigned e);
        evt = e;
        cg_flags.sample();
    endfunction

    function void write(fifo_obs t);
        if (t.kind == fifo_obs::RESET) begin
            if (prev != null && (prev.overrun || prev.underrun)) flag_event(5);
            prev = null;
            return;
        end
        if (!t.nRST) begin
            prev = null;
            return;
        end

        occ = t.count;
        op  = {t.REN, t.WEN};
        if (t.clear) cg_clear.sample();
        else         cg_ops.sample();

        if (t.WEN) begin
            bit [SIZE-1:0] h55 = {(SIZE + 1) / 2 {2'b01}};
            if      (t.wdata == '0)          pat = 0;
            else if (t.wdata == '1)          pat = 1;
            else if (t.wdata == h55)         pat = 2;
            else if (t.wdata == ~h55)        pat = 3;
            else                             pat = 4;
            cg_data.sample();
        end

        if (prev != null) begin
            if (!prev.overrun  && t.overrun)  flag_event(1);
            if (!prev.underrun && t.underrun) flag_event(2);
            if (t.overrun && t.underrun && !(prev.overrun && prev.underrun)) flag_event(3);
            if (prev.clear && (prev.overrun || prev.underrun)) flag_event(4);
        end
        prev = t;
    endfunction
endclass
