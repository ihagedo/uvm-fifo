// File:        fifo_tests.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: FIFO tests: reset, sequences, then a PASSED or FAILED banner.

class fifo_base_test extends uvm_test;
    `uvm_component_utils(fifo_base_test)

    fifo_env env;
    bit      glitch;   // scramble inputs mid-cycle

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if ($test$plusargs("GLITCH")) glitch = 1;
        uvm_config_db #(bit)::set(this, "env.agt.drv", "glitch", glitch);
        env = fifo_env::type_id::create("env", this);
        uvm_top.set_report_max_quit_count(20);
    endfunction

    virtual task body();
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        run_seq(power_on_reset_seq::type_id::create("por"));
        body();
        run_seq(tail_seq::type_id::create("tail"));
        phase.drop_objection(this);
    endtask

    task run_seq(fifo_base_seq s);
        `uvm_info("TEST", $sformatf("running %s", s.get_type_name()), UVM_LOW)
        s.start(env.agt.sqr);
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server rs = uvm_report_server::get_server();
        int errs = rs.get_severity_count(UVM_ERROR) + rs.get_severity_count(UVM_FATAL);
        `uvm_info("TEST", $sformatf("config SIZE=%0d DEPTH=%0d%s", SIZE, DEPTH, glitch ? " glitch" : ""), UVM_NONE)
        if (errs == 0) `uvm_info("TEST", "*** TEST PASSED ***", UVM_NONE)
        else           `uvm_info("TEST", $sformatf("*** TEST FAILED *** (%0d errors)", errs), UVM_NONE)
    endfunction
endclass

class fifo_smoke_test extends fifo_base_test;
    `uvm_component_utils(fifo_smoke_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task body();
        run_seq(write_read_seq::type_id::create("s1"));
        run_seq(peek_seq::type_id::create("s2"));
    endtask
endclass

class fifo_fill_drain_test extends fifo_base_test;
    `uvm_component_utils(fifo_fill_drain_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task body();
        run_seq(fill_drain_seq::type_id::create("s1"));
        run_seq(wrap_seq::type_id::create("s2"));
        run_seq(pattern_seq::type_id::create("s5"));
    endtask
endclass

class fifo_glitch_test extends fifo_fill_drain_test;
    `uvm_component_utils(fifo_glitch_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        glitch = 1;
        super.build_phase(phase);
    endfunction
    task body();
        super.body();
        run_seq(write_read_seq::type_id::create("s3"));
        run_seq(rw_same_cycle_seq::type_id::create("s4"));
    endtask
endclass

class fifo_boundary_test extends fifo_base_test;
    `uvm_component_utils(fifo_boundary_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task body();
        run_seq(rw_same_cycle_seq::type_id::create("s1"));
        run_seq(full_rw_seq::type_id::create("s2"));
        run_seq(empty_rw_seq::type_id::create("s3"));
        run_seq(edge_seq::type_id::create("s4"));
    endtask
endclass

class fifo_flags_test extends fifo_base_test;
    `uvm_component_utils(fifo_flags_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task body();
        run_seq(overrun_seq::type_id::create("s1"));
        run_seq(underrun_seq::type_id::create("s2"));
        run_seq(flags_both_seq::type_id::create("s3"));
    endtask
endclass

class fifo_clear_reset_test extends fifo_base_test;
    `uvm_component_utils(fifo_clear_reset_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task body();
        run_seq(clear_seq::type_id::create("s1"));
        run_seq(flags_both_seq::type_id::create("s2"));
        run_seq(async_reset_seq::type_id::create("s3"));
    endtask
endclass

class fifo_random_test extends fifo_base_test;
    `uvm_component_utils(fifo_random_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task body();
        int unsigned cycles = 10000;
        void'($value$plusargs("CYCLES=%d", cycles));
        for (int m = 0; m < 3; m++) begin
            random_seq s = random_seq::type_id::create($sformatf("rand%0d", m));
            s.mode   = random_seq::mode_e'(m);
            s.cycles = cycles;
            `uvm_info("TEST", $sformatf("random mode %s, %0d cycles", s.mode.name(), cycles), UVM_LOW)
            run_seq(s);
        end
    endtask
endclass
