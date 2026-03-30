`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    18:20:37 07/21/2025
// Design Name:
// Module Name:    dmamaster
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
module dmamaster(
    input sclk,
    input bclk,
    input IORST_n,
    input SLAVE_n,
    input mybus,
    input SCSI_AS_n,
    output reg SCSI_STERM_n = 1,
    input READ,
    input Z_FCS_n,
    input DTACK_n,
    input [1:0] ADDRL,
    input [1:0] SIZ,
    (* LOC = "FB7" *) output reg efcs = 0,
    (* LOC = "FB8" *) output dma_aboel,
    (* LOC = "FB8" *) output reg dma_aboeh = 0,
    (* LOC = "FB3" *) output reg dma_doe = 0,
    (* LOC = "FB7" *) output reg [3:0] ds_n = 4'b1111
);

    wire busfree;
    wire cycz3;

    assign busfree = Z_FCS_n && DTACK_n && SLAVE_n && &ds_n;
    assign cycz3 = SCSI_STERM_n && mybus && !SCSI_AS_n && IORST_n; //use SCSI_STERM_n to wait until actual cycle ends...

     // always drive dma_aboel when ZIII Master
    assign dma_aboel = mybus;

    // Start cycle if bus if free, and SCSI_AS_n active
    always @ (negedge cycz3, posedge bclk) begin
        if (!cycz3) begin
            dma_aboeh <= 0;
        end else begin
            if (busfree) begin
                dma_aboeh <= 1;
            end else begin
                dma_aboeh <= 0;
            end
        end
    end

    // set efcs active 1 sclk after ABOEH (20ns) (Tafs >= 15ns)
    always @ (negedge cycz3, posedge sclk) begin
        if (!cycz3) begin
            efcs <= 0;
        end else begin
            if (dma_aboeh) begin            // LATCH!
                efcs <= 1;
            end
        end
    end

    // set doe active 1/2 sclk after dma_aboeh inactive (10ns)
    always @ (negedge cycz3, negedge sclk) begin
        if (!cycz3) begin
            dma_doe <= 0;
        end else begin
            if (!dma_aboeh) begin
                dma_doe <= 1;
            end
        end
    end

    // set ds active 1/2 sclk after doe (10ns) (tds 10...30ns)
    always @ (negedge cycz3, posedge sclk) begin
        if (!cycz3) begin
            ds_n <= 4'b1111;
        end else begin
            if (dma_doe) begin
                // ds_n based on A1,A0 and SIZ from NCR
                ds_n[0] <= !(READ || (ADDRL[0] && SIZ == 2'b11) || SIZ == 2'b00 || ADDRL == 2'b11 || (ADDRL[1] && SIZ[1]));
                ds_n[1] <= !(READ || (!ADDRL[1] && SIZ == 2'b00) || (!ADDRL[1] && SIZ == 2'b11) || (ADDRL == 2'b01 && !SIZ[0]) || ADDRL == 2'b10);
                ds_n[2] <= !(READ || (!ADDRL[1] && !SIZ[0]) || ADDRL == 2'b01 || (!ADDRL[1] && SIZ[1]));
                ds_n[3] <= !(READ || ADDRL == 2'b00);
            end
        end
    end

    /* The SCSI termination is based on a synchronized DTACK.  I
    synchronize DTACK for either slave or master cycle, since the
    NCR 53C710 wants the effect of SLACK (which makes a DTACK on slave
    to SCSI cycles) reflected on STERM to actually end the cycle. */
    always @ (negedge IORST_n, negedge bclk) begin
        if (!IORST_n) begin
            SCSI_STERM_n <= 1;
        end else begin
            if (!SCSI_AS_n && !Z_FCS_n && !DTACK_n) begin
                SCSI_STERM_n <= 0;
            end else begin
                SCSI_STERM_n <= 1;
            end
        end
    end

endmodule
