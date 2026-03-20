`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    12:11:44 07/20/2025
// Design Name:
// Module Name:    interrupthandling
// Project Name:
// Target Devices:
// Tool versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module interrupthandling(
    input clk,
    input intreg_cycle,
    input IORST_n,
    input DOE,
    input DS0_n,
    input READ,
    input set_reset,
    input [7:0] din,
    output reg [7:0] dout = 8'd24,  // Spurious interrupt Vector
    output reg vector_read = 0,
    output reg dtack = 0,
    input SINT_n,                   // real interrupt from NCR
    output int_sig,                 // interrupt out tu ZIII Bus
    input FCS_n,
    input SLAVE_n,
    input quickint_cycle,
    output reg slave = 0
);

    // interrupt signal ti ZIII Bus, can only change is FCS_n is inactive
    reg int_sync = 0;

    reg vector_assigned = 0;
    wire real_quickint_cycle;

    assign real_quickint_cycle = quickint_cycle && vector_assigned && int_sync && !SINT_n;

    assign poll_phase = real_quickint_cycle && !DOE && DS0_n;
    assign vector_phase = real_quickint_cycle && DOE && !DS0_n && !SLAVE_n;

    // With assigned Vector Interrupt use synced int, else simply pass through NCR Interrupt
    assign int_sig = (vector_assigned) ? int_sync : !SINT_n;

    // Sync interrupt process line to Zorro III cycles.
    always @(*) begin
        if (!IORST_n) begin
            int_sync = 0;
        end else if (FCS_n) begin
            int_sync = !SINT_n;
        end
    end

    // generate dtack and slave signal
    always @(negedge IORST_n, posedge clk) begin
        if (!IORST_n) begin
            dout <= 8'd24;          // Spurious interrupt Vector
            vector_assigned <= 0;
            slave <= 0;
            dtack <= 0;
            vector_read <= 0;
        end else begin
            slave <= 0;
            dtack <= 0;
            vector_read <= 0;

            if (vector_read) begin
                dtack <= 1;
            end

            if (intreg_cycle && DOE && READ) begin
                vector_read <= 1;
            end else if (intreg_cycle && DOE && !DS0_n) begin
                dout <= din;
                vector_assigned <= set_reset;
                dtack <= 1;
            end else if (poll_phase) begin
                slave <= 1;
            end else if (vector_phase) begin
                vector_read <= 1;
            end
        end
    end

endmodule
