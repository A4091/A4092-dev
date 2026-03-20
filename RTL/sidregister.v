`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    20:51:42 07/27/2025
// Design Name:
// Module Name:    sidregister
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
module sidregister(
    input clk,
    input sid_cycle,
    input IORST_n,
    input DOE,
    input DS0_n,
    input READ,
    input [7:0] DIN,
    output reg [7:0] DOUT = 8'hFF,      //no LUNS, EXT_TERM, SYNC, Short Spinup, FAST SCSI, ADDR 7
    output reg sid_read = 1,
    output reg dtack = 0
    );

    always @(negedge IORST_n, posedge clk) begin
        if (!IORST_n) begin
            DOUT <= 8'hFF;      //no LUNS, EXT_TERM, SYNC, Short Spinup, FAST SCSI, ADDR 7
            sid_read <= 0;
            dtack <= 0;
        end else begin
            sid_read <= 0;
            dtack <= 0;

            if (sid_read) begin
                dtack <= 1;
            end

            if (sid_cycle && DOE && READ) begin
                sid_read <= 1;
            end else if (sid_cycle && DOE && !DS0_n) begin
                DOUT <= DIN;
                dtack <= 1;
            end
        end
    end

endmodule
