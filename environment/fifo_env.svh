// File:        fifo_env.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: FIFO environment: agent, predictor, scoreboard and coverage.

class fifo_env extends uvm_env;
    `uvm_component_utils(fifo_env)

    fifo_agent      agt;
    fifo_predictor  pred;
    fifo_scoreboard scb;
    fifo_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt  = fifo_agent::type_id::create("agt", this);
        pred = fifo_predictor::type_id::create("pred", this);
        scb  = fifo_scoreboard::type_id::create("scb", this);
        cov  = fifo_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agt.mon.ap.connect(pred.analysis_export);
        pred.ap.connect(scb.exp_imp);
        agt.mon.ap.connect(scb.act_imp);
        agt.mon.ap.connect(cov.analysis_export);
    endfunction
endclass
