`timescale 1ns / 1ps
/**********************************************************************************
 *
 * DMA arbiter
 *
 **********************************************************************************/
module dmaarbiter (
    input clk7m,
    input clk,
    input IORST_n,
    input MASTER_n,
    input SBR_n,
    input SC0,
    input EBG_n,
    input FCS_n,
    input DTACK_n,
    output reg mybus = 0,
    output reg SBG_n = 1,
    output EBR_n,
    input buster09,            // aktivate workaroud for Buster09 DMA hang bug
    input quickint_cycle,
    output reg fakeint = 0
);

    // ###########################################################
    // ZIII Spec state min. three 7MHz Clock between BR pulse, A4091 use two, one wont work stable!
    localparam recyclecnt = 3;
    // ###########################################################

    wire false_br;
    wire valid_br;
    reg rchng = 0;              // change of registration necessary (sync to 25MHz)
    reg rchng7 = 0;             // rchng sync to 7MHz
    reg reged = 0;              // the actual registration indicator (sync to 7MHz)
    reg reged25 = 0;            // reged sync to 25MHz
    reg ebr25_n = 1;            // EBR_n sync to 25MHz
    reg quickint_cycle25 = 0;   // quickint cycle sync to 25MHz
    reg [1:0] reregcnt = 0;     // Counter for recycle EBR_n

    // Workaround for System Engineering Notes No. 840
    // SYM53C710, SYM53C720 False Bus Request
    assign false_br = !(SBR_n || SC0);
    assign valid_br = (!SBR_n && SC0);

    // ZIII Spec states 5..25ns Delay between C7M High and EBR_n low, but even with -10 CPLD
    // the timing is at the lower limit so force some extra inverter and delay EBR_n some ns
    reg ebr_delay_n = 1;
    (* KEEP = "TRUE" *) wire ebr_delay1;
    (* KEEP = "TRUE" *) wire ebr_delay2_n;
    assign ebr_delay1 = !ebr_delay_n;
    assign ebr_delay2_n = !ebr_delay1;
    assign EBR_n = ebr_delay2_n;

    // generate one SBG_n per SBR_n
    always @(*) begin
        if (!IORST_n) begin
            SBG_n = 1;
        end else begin
            if (false_br || (valid_br && MASTER_n && !EBG_n && reged && !rchng7)) begin
                SBG_n = 0;
            end else begin
                SBG_n = 1;
            end
        end
    end

    // Sync Signals to 7MHz
    always @(negedge IORST_n, negedge clk7m) begin
        if (!IORST_n) begin
            rchng7 <= 0;
        end else begin
            rchng7 <= rchng;
        end
    end

    // The Zorro III bus request is driven out on C7M high, for one C7M cycle, to
    // register for bus mastership.  When done, the same sequence relinquishes
    // registration.  The RCHNG signal indicated when a change is necessary.
    always @(negedge IORST_n, posedge clk7m) begin
        if (!IORST_n) begin
            ebr_delay_n <= 1;
            reged <= 0;
            reregcnt <= 0;
        end else begin
            ebr_delay_n <= 1;

            if (reregcnt > 0 ) begin
                reregcnt <= reregcnt -1;
            end else if (rchng7 && ebr_delay_n) begin
                ebr_delay_n <= 0;
                reregcnt <= recyclecnt;
                reged <= !reged;
            end
        end
    end

    // Sync Signals to 25MHz
    always @(negedge IORST_n, negedge clk) begin
        if (!IORST_n) begin
            reged25 <= 0;
            quickint_cycle25 <= 0;
            ebr25_n <= 0;
        end else begin
            reged25 <= reged;
            quickint_cycle25 <= quickint_cycle; // quickint_cycle ist async -> sync to 25MHz
            ebr25_n <= ebr_delay_n;             // ebr_delay_n ist async -> sync to 25MHz
        end
    end

    // generate regchange sync to 25MHz BCLK
    // use SC0 as SNOOP bit to start Busrequest 2 BCLK early
    // use SC0 also to hold Bus if FIFO ist not empty when SBR_n get inactive
    // In Buster09 Mode DMA unregister work as in Buster11 Mode, but DMA register work differently:
    // DMA Arbiter in Buster may lock up when FCS goes low while register puls is active, so first
    // generate a fake INT2 und delay the register pulse until Quick interrupt cycle runs so FCS
    // is already low when register pulse start...
    always @(negedge IORST_n, posedge clk) begin
        if (!IORST_n) begin
            rchng <= 0;
            fakeint <= 0;
        end else begin
            if (!ebr25_n) begin
                fakeint <= 0;
                rchng <= 0;
            end else if (!reged25 && (valid_br || SC0)) begin
                if (!buster09 || (quickint_cycle25 && fakeint)) begin
                    fakeint <= 0;
                    rchng <= 1;
                end else begin
                    fakeint <= 1;
                    rchng <= 0;
                end
            end else if (reged25 && MASTER_n && !valid_br && !SC0) begin
                fakeint <= 0;
                rchng <= 1;
            end
        end
    end

    always @(*) begin
        if (!IORST_n) begin
            mybus = 0;
        end else if (reged25 && !EBG_n) begin
            mybus = 1;
		end else if (FCS_n && DTACK_n) begin
            mybus = 0;
        end
    end

endmodule
