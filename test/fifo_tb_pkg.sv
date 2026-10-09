// File:        fifo_tb_pkg.sv
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Package holding every FIFO bench class. FIFO_SIZE and FIFO_DEPTH select the configuration.

`ifndef FIFO_SIZE
    `define FIFO_SIZE 8
`endif
`ifndef FIFO_DEPTH
    `define FIFO_DEPTH 8
`endif

`include "uvm_macros.svh"
package fifo_tb_pkg;
    import uvm_pkg::*;

    localparam int SIZE  = `FIFO_SIZE;
    localparam int DEPTH = `FIFO_DEPTH;
    localparam int CW    = $clog2(DEPTH + 1);   // width of count
    localparam realtime PERIOD = 10ns;

    typedef virtual fifo_if #(SIZE, DEPTH) fifo_vif;

    `include "fifo_item.svh"
    `include "fifo_obs.svh"
    `include "fifo_driver.svh"
    `include "fifo_monitor.svh"
    `include "fifo_agent.svh"
    `include "fifo_predictor.svh"
    `include "fifo_scoreboard.svh"
    `include "fifo_coverage.svh"
    `include "fifo_env.svh"
    `include "fifo_seqs.svh"
    `include "fifo_tests.svh"
endpackage
