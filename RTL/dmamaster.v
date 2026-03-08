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
    output reg efcs = 0,
    output dma_aboel,
    output reg dma_aboeh = 0,
    output reg dma_doe = 0,
    output reg [3:0] ds_n = 4'b1111
);

    reg dma_ds = 0;
    wire busfree;
    wire cycz3;

    assign busfree = Z_FCS_n && DTACK_n && SLAVE_n && &ds_n && IORST_n;
    assign cycz3 = DTACK_n && mybus && !SCSI_AS_n && IORST_n;

    // ds_n based on A1,A0 and SIZ from NCR
    always @ (*) begin
        if (dma_ds) begin
            ds_n[0] = !(READ || (ADDRL[0] && SIZ == 2'b11) || SIZ == 2'b00 || ADDRL == 2'b11 || (ADDRL[1] && SIZ[1]));
            ds_n[1] = !(READ || (!ADDRL[1] && SIZ == 2'b00) || (!ADDRL[1] && SIZ == 2'b11) || (ADDRL == 2'b01 && !SIZ[0]) || ADDRL == 2'b10);
            ds_n[2] = !(READ || (!ADDRL[1] && !SIZ[0]) || ADDRL == 2'b01 || (!ADDRL[1] && SIZ[1]));
            ds_n[3] = !(READ || ADDRL == 2'b00);
        end else begin
            ds_n = 4'b1111;
        end
    end

    // always drive dma_aboel when ZIII Master
    assign dma_aboel = mybus;

    // Start cycle if bus if free, and SCSI_AS_n active
    always @ (negedge cycz3, posedge bclk) begin
        if (!cycz3) begin
            dma_aboeh <= 0;
        end else begin
            if (busfree) begin
                dma_aboeh <= 1;
            end else if (efcs) begin
                dma_aboeh <= 0;
            end
        end
    end

    // set efcs active 1/2 bclk after ABOEH
    always @ (negedge IORST_n, negedge bclk) begin
        if (!IORST_n) begin
            efcs <= 0;
        end else begin
            if (dma_aboeh) begin
                efcs <= 1;
            end else if (!cycz3) begin
                efcs <= 0;
            end
        end
    end

    // set doe active 1 bclk after efcs
    always @ (negedge efcs, negedge bclk) begin
        if (!efcs) begin
            dma_doe <= 0;
        end else begin
            dma_doe <= 0;
            if (efcs) begin
                dma_doe <= 1;
            end
        end
    end

    // set ds active 1/2 bclk after doe
    always @ (negedge efcs, posedge bclk) begin
        if (!efcs) begin
            dma_ds <= 0;
        end else begin
            dma_ds <= 0;
            if (dma_doe) begin
                dma_ds <= 1;
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
            SCSI_STERM_n <= 1;
            if (!SCSI_AS_n && !Z_FCS_n && !DTACK_n) begin
                SCSI_STERM_n <= 0;
            end
        end
    end

endmodule
