// File:        fifo_agent.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: FIFO agent: sequencer, driver and monitor.

class fifo_agent extends uvm_agent;
    `uvm_component_utils(fifo_agent)

    uvm_sequencer #(fifo_item) sqr;
    fifo_driver                drv;
    fifo_monitor               mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sqr = uvm_sequencer #(fifo_item)::type_id::create("sqr", this);
        drv = fifo_driver::type_id::create("drv", this);
        mon = fifo_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
