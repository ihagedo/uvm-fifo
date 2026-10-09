// File:        fifo_scoreboard.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Compares predicted and observed FIFO outputs every cycle.

`uvm_analysis_imp_decl(_exp)
`uvm_analysis_imp_decl(_act)

class fifo_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(fifo_scoreboard)

    uvm_analysis_imp_exp #(fifo_obs, fifo_scoreboard) exp_imp;
    uvm_analysis_imp_act #(fifo_obs, fifo_scoreboard) act_imp;

    fifo_obs exp_q[$], act_q[$];
    fifo_obs last_edge;   // edge whose inputs produced this state
    int unsigned n_compares, n_mismatches, n_act;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        exp_imp = new("exp_imp", this);
        act_imp = new("act_imp", this);
    endfunction

    function void write_exp(fifo_obs t);
        exp_q.push_back(t);
        drain();
    endfunction

    function void write_act(fifo_obs t);
        n_act++;
        act_q.push_back(t);
        drain();
    endfunction

    function void drain();
        while (exp_q.size() && act_q.size()) begin
            fifo_obs e = exp_q.pop_front();
            fifo_obs a = act_q.pop_front();
            compare(e, a);
            if (a.kind == fifo_obs::EDGE) last_edge = a;
        end
    endfunction

    function void compare(fifo_obs e, fifo_obs a);
        string diffs, hint, cause;
        bit    r05, r_ovr, r_udr, r_data;   // requirement groups that differ
        if (e.kind != a.kind || e.cycle != a.cycle)
            `uvm_fatal("SCB", $sformatf("expected and actual streams out of step (%s/%0d vs %s/%0d)",
                                        e.kind.name(), e.cycle, a.kind.name(), a.cycle))
        n_compares++;
        if (a.count    !== e.count)    begin diffs = {diffs, $sformatf(" count %0d (expected %0d)", a.count, e.count)};       r05 = 1;    end
        if (a.full     !== e.full)     begin diffs = {diffs, $sformatf(" full %b (expected %b)", a.full, e.full)};             r05 = 1;    end
        if (a.empty    !== e.empty)    begin diffs = {diffs, $sformatf(" empty %b (expected %b)", a.empty, e.empty)};          r05 = 1;    end
        if (a.overrun  !== e.overrun)  begin diffs = {diffs, $sformatf(" overrun %b (expected %b)", a.overrun, e.overrun)};    r_ovr = 1;  end
        if (a.underrun !== e.underrun) begin diffs = {diffs, $sformatf(" underrun %b (expected %b)", a.underrun, e.underrun)}; r_udr = 1;  end
        if (e.rdata_valid && a.rdata !== e.rdata)
                                       begin diffs = {diffs, $sformatf(" rdata %h (expected %h)", a.rdata, e.rdata)};          r_data = 1; end
        if (diffs == "") return;

        if (a.kind == fifo_obs::RESET) hint = " R13";
        if (r05)    hint = {hint, " R05"};
        if (r_ovr)  hint = {hint, " R06/R08/R11/R12"};
        if (r_udr)  hint = {hint, " R07/R09/R11/R12"};
        if (r_data) hint = {hint, " R01/R04"};

        n_mismatches++;
        if (a.kind == fifo_obs::RESET)
            cause = "1 ns after nRST fell";
        else if (last_edge != null)
            cause = $sformatf("after the edge that sampled %s", last_edge.inputs2string());
        `uvm_error("SCB", $sformatf("cycle %0d, %s:%s  [see%s]", a.cycle, cause, diffs, hint))
    endfunction

    function void check_phase(uvm_phase phase);
        if (n_compares == 0)
            `uvm_error("SCB", "no compares were made: the test checked nothing")
        if (n_compares != n_act)
            `uvm_error("SCB", $sformatf("%0d observations but only %0d compares", n_act, n_compares))
        if (exp_q.size() || act_q.size())
            `uvm_error("SCB", $sformatf("%0d expected / %0d actual left uncompared", exp_q.size(), act_q.size()))
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("SCB", $sformatf("compares: %0d   mismatches: %0d", n_compares, n_mismatches), UVM_LOW)
    endfunction
endclass
