// File:        fifo_driver.svh
// Author:      Isaac Hagedorn
// Date:        2026-10-08
// Description: Drives one FIFO input item per clock cycle and applies resets.

class fifo_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_driver)

    fifo_vif vif;
    bit      glitch;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(fifo_vif)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "fifo_driver: no virtual interface")
        void'(uvm_config_db #(bit)::get(this, "", "glitch", glitch));
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            `uvm_info("DRV", req.convert2string(), UVM_HIGH)
            if (req.kind == fifo_item::ASYNC_RESET) drive_reset(req);
            else                                   drive_op(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_op(fifo_item it);
        @(vif.drv_cb);
        vif.drv_cb.WEN   <= it.WEN;
        vif.drv_cb.REN   <= it.REN;
        vif.drv_cb.clear <= it.clear;
        vif.drv_cb.wdata <= it.wdata;
        if (glitch) begin
            #2ns;
            vif.WEN   <= 1'($urandom);
            vif.REN   <= 1'($urandom);
            vif.clear <= 1'($urandom);
            vif.wdata <= SIZE'($urandom);
            #4ns;
            vif.WEN   <= it.WEN;
            vif.REN   <= it.REN;
            vif.clear <= it.clear;
            vif.wdata <= it.wdata;
        end
    endtask

    task drive_reset(fifo_item it);
        @(posedge vif.CLK);
        #(PERIOD * it.rst_offset_pct / 100);
        vif.nRST  <= 1'b0;
        vif.WEN   <= 1'b0;
        vif.REN   <= 1'b0;
        vif.clear <= 1'b0;
        repeat (it.rst_edges) @(posedge vif.CLK);
        @(negedge vif.CLK);
        vif.nRST  <= 1'b1;
    endtask
endclass
