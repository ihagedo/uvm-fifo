// File:        fifo_predictor.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Reference model of the FIFO, written from the spec.

class fifo_predictor extends uvm_subscriber #(fifo_obs);
    `uvm_component_utils(fifo_predictor)

    uvm_analysis_port #(fifo_obs) ap;

    bit [SIZE-1:0] q[$];
    bit            ovr, udr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void reset_model();
        q.delete();
        ovr = 0;
        udr = 0;
    endfunction

    function void write(fifo_obs t);
        fifo_obs exp = fifo_obs::type_id::create("exp");
        exp.kind  = t.kind;
        exp.cycle = t.cycle;

        if (t.kind == fifo_obs::RESET) begin
            reset_model();
            predict(exp);
            exp.rdata       = '0;
            exp.rdata_valid = 1;
            ap.write(exp);
            return;
        end

        predict(exp);
        ap.write(exp);

        if (!t.nRST) reset_model();
        else         apply(t);
    endfunction

    function void predict(fifo_obs exp);
        exp.count       = CW'(q.size());
        exp.full        = (q.size() == DEPTH);
        exp.empty       = (q.size() == 0);
        exp.overrun     = ovr;
        exp.underrun    = udr;
        exp.rdata_valid = (q.size() != 0);
        exp.rdata       = exp.rdata_valid ? q[0] : 'x;
    endfunction

    function void apply(fifo_obs t);
        bit do_rd, do_wr;
        if (t.clear) begin
            reset_model();
            return;
        end
        do_rd = t.REN && q.size() > 0     && !(q.size() == DEPTH && t.WEN);
        do_wr = t.WEN && q.size() < DEPTH && !(q.size() == 0 && t.REN);
        if (t.WEN && q.size() == DEPTH) ovr = 1;
        if (t.REN && q.size() == 0)     udr = 1;
        if (do_rd) void'(q.pop_front());
        if (do_wr) q.push_back(t.wdata);
    endfunction
endclass
