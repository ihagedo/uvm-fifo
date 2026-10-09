// File:        socetlib_fifo.sv
// Author:      digital-lib contributors
// Date:        2026-10-08
// Description: Synchronous FIFO with count, full/empty and sticky overrun/underrun flags. Fixed for DEPTH = 1.

module socetlib_fifo #(
    parameter SIZE = 8,     // entry width, >= 1
    parameter DEPTH = 8     // number of entries, power of 2 >= 1
)(
    input CLK,
    input nRST,
    input WEN,
    input REN,
    input clear,
    input logic [(SIZE-1):0] wdata,
    output logic full,
    output logic empty,
    output logic underrun,
    output logic overrun,
    output logic [$clog2(DEPTH+1)-1:0] count,
    output logic [(SIZE-1):0] rdata
);

    // Parameter checking
    generate
`ifndef QUARTUS
        if(DEPTH == 0 || (DEPTH & (DEPTH - 1)) != 0) begin : g_bad_depth
            $error("%m: DEPTH must be a power of 2 >= 1!");
        end
`endif
    endgenerate

    localparam int ADDR_BITS = (DEPTH > 1) ? $clog2(DEPTH) : 1;   // pointer width
    localparam int FULL = DEPTH;                                   // count when full

    logic overrun_next, underrun_next;
    logic [ADDR_BITS-1:0] write_ptr, write_ptr_next, read_ptr, read_ptr_next;
    logic [ADDR_BITS-1:0] waddr, raddr;                            // storage index (0 when DEPTH = 1)
    logic [$clog2(DEPTH+1)-1:0] count_next;
    logic [DEPTH-1:0] [SIZE-1:0] fifo, fifo_next;

    if (DEPTH > 1) begin : g_index
        assign waddr = write_ptr;
        assign raddr = read_ptr;
    end else begin : g_single
        assign waddr = '0;
        assign raddr = '0;
    end

    always_ff @(posedge CLK, negedge nRST) begin
        if(!nRST) begin
            fifo <= '0;
            write_ptr <= '0;
            read_ptr <= '0;
            overrun <= 1'b0;
            underrun <= 1'b0;
            count <= '0;
        end else begin
            fifo <= fifo_next;
            write_ptr <= write_ptr_next;
            read_ptr <= read_ptr_next;
            overrun <= overrun_next;
            underrun <= underrun_next;
            count <= count_next;
        end
    end

    always_comb begin
        fifo_next = fifo;
        write_ptr_next = write_ptr;
        read_ptr_next = read_ptr;
        overrun_next = overrun;
        underrun_next = underrun;
        count_next = count;

        if(clear) begin
            write_ptr_next = '0;
            read_ptr_next = '0;
            overrun_next = 1'b0;
            underrun_next = 1'b0;
            count_next = '0;
        end else begin
            if(REN && !empty && !(full && WEN)) begin
                read_ptr_next = read_ptr + 1;
            end else if(REN && empty) begin
                underrun_next = 1'b1;
            end

            if(WEN && !full && !(empty && REN)) begin
                write_ptr_next = write_ptr + 1;
                fifo_next[waddr] = wdata;
            end else if(WEN && full) begin
                overrun_next = 1'b1;
            end

            if (int'(count) == FULL) begin
                count_next = count - REN + (REN && WEN);
            end else if (count == 0) begin
                count_next = count + WEN - (REN && WEN);
            end else begin
                count_next = count + WEN - REN;
            end
        end
    end

    assign full = int'(count) == FULL;
    assign empty = count == 0;
    assign rdata = fifo[raddr];
endmodule
