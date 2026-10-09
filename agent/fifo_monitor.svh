// File:        fifo_monitor.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Samples the FIFO ports at every edge and publishes an observation. Also checks that outputs only change on clock edges.

class fifo_monitor extends uvm_monitor;
    `uvm_component_utils(fifo_monitor)

    uvm_analysis_port #(fifo_obs) ap;
    fifo_vif vif;

    longint unsigned cycle;
    int unsigned     n_edges, n_resets, n_r16_checks;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(fifo_vif)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "fifo_monitor: no virtual interface")
    endfunction

    task run_phase(uvm_phase phase);
        fork
            watch_edges();
            watch_reset();
        join
    endtask

    task watch_edges();
        logic [CW+SIZE+3:0] snap;
        int unsigned        snap_resets;
        bit                 snap_valid = 0;
        forever begin
            fifo_obs o;
            @(vif.mon_cb);
            cycle++;
            if (n_resets == 0) continue;

            o = fifo_obs::type_id::create("o");
            o.kind     = fifo_obs::EDGE;
            o.cycle    = cycle;
            o.nRST     = vif.mon_cb.nRST;
            o.WEN      = vif.mon_cb.WEN;
            o.REN      = vif.mon_cb.REN;
            o.clear    = vif.mon_cb.clear;
            o.wdata    = vif.mon_cb.wdata;
            o.full     = vif.mon_cb.full;
            o.empty    = vif.mon_cb.empty;
            o.underrun = vif.mon_cb.underrun;
            o.overrun  = vif.mon_cb.overrun;
            o.count    = vif.mon_cb.count;
            o.rdata    = vif.mon_cb.rdata;

            if (snap_valid && snap_resets == n_resets && o.nRST) begin
                n_r16_checks++;
                if ({o.full, o.empty, o.underrun, o.overrun, o.count, o.rdata} !== snap)
                    `uvm_error("R16", $sformatf("cycle %0d: an output changed between clock edges (3 ns after the edge vs just before the next one): was %h, now %h",
                                                cycle, snap, {o.full, o.empty, o.underrun, o.overrun, o.count, o.rdata}))
            end

            n_edges++;
            ap.write(o);

            #3ns;
            snap        = {vif.full, vif.empty, vif.underrun, vif.overrun, vif.count, vif.rdata};
            snap_resets = n_resets;
            snap_valid  = vif.nRST;
        end
    endtask

    task watch_reset();
        forever begin
            fifo_obs o;
            @(negedge vif.nRST);
            n_resets++;
            #1ns;
            o = fifo_obs::type_id::create("o");
            o.kind     = fifo_obs::RESET;
            o.cycle    = cycle;
            o.full     = vif.full;
            o.empty    = vif.empty;
            o.underrun = vif.underrun;
            o.overrun  = vif.overrun;
            o.count    = vif.count;
            o.rdata    = vif.rdata;
            ap.write(o);
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("MON", $sformatf("observed %0d edges, %0d resets; %0d R16 checks", n_edges, n_resets, n_r16_checks), UVM_LOW)
    endfunction
endclass
