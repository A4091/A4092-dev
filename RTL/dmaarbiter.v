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
    output SBG_n,
    output reg EBR_n = 1,
    input  buster09,            // aktivate workaroud for Buster09 DMA hang bug
    input  quickint_cycle,      // detect quitint cycle, needed for Buster09 workaroud
    output reg fakeint = 0      // fake int, needed for Buster09 workaroud
);

    // ###########################################################
    // ZIII Spec state min. three 7MHz Clock between BR pulse, A4091 use two, one wont work stable!
    localparam recyclecnt = 3;
    // ###########################################################

    reg real_bg = 0;            // real Bus Grant
    reg fake_bg = 0;            // fake Bus Grant for SYM53C7x0 False Bus Request
    reg rchng = 0;              // change of registration necessary (sync to 25MHz)
    reg rchng7 = 0;             // rchng sync to 7MHz
    reg reged = 0;              // the actual registration indicator (sync to 7MHz)
    reg reged25 = 0;            // reged sync to 25MHz
    reg ebr25_n = 1;            // EBR_n sync to 25MHz
    reg quickint_cycle7 = 0;    // quickint cycle sync to 25MHz
    reg [1:0] reregcnt = 0;     // Counter for recycle EBR_n
    reg int_sig = 0;            // fake interrupt from dmaarbiter, needed for Buster09 compatibility

    assign SBG_n = !(real_bg || fake_bg);

    // fake interrupt signal to ZIII Bus, can only change if FCS_n is inactive
    always @(*) begin
        if (!IORST_n) begin
            fakeint <= 0;
        end else if (FCS_n) begin
            fakeint <= int_sig;
        end
    end

    // Generate Busgrant for NCR, only one grant impulse per request
    always @(*) begin
        if (!IORST_n) begin
            real_bg <= 0;
        end else begin
            if (SBR_n && !MASTER_n) begin
                real_bg <= 0;
            end else if (!SBR_n && SC0 && MASTER_n && !EBG_n && reged && !rchng7) begin
                real_bg <= 1;
            end
        end
    end

    // Workaround for System Engineering Notes No. 840
    // SYM53C710, SYM53C720 False Bus Request
    always @(negedge IORST_n, negedge clk) begin
        if (!IORST_n) begin
            fake_bg <= 0;
        end else begin
            if (SBR_n) begin
                fake_bg <= 0;
            end else if (!SBR_n && !SC0) begin
                fake_bg <= 1;
            end
        end
    end

    // Sync Signals to 7MHz
    always @(negedge IORST_n, negedge clk7m) begin
        if (!IORST_n) begin
            rchng7 <= 0;
            quickint_cycle7 <= 0;
        end else begin
            rchng7 <= rchng;                    // rchng is sync ti 25MHz -> sync to 7MHz
            quickint_cycle7 <= quickint_cycle;  // quickint_cycle ist async -> sync to 7MHz
        end
    end

    // The Zorro III bus request is driven out on C7M high, for one C7M cycle, to
    // register for bus mastership.  When done, the same sequence relinquishes
    // registration.  The RCHNG signal indicated when a change is necessary.
    // In Buster09 Mode DMA register is special, since Buster may lock up when
    // FCS goes low while register puls is active first generate a fake INT2
    // und delay the register pulse until Quick interrupt cycle runs so FCS
    // is already low when register pulse start...
    always @(negedge IORST_n, posedge clk7m) begin
        if (!IORST_n) begin
            EBR_n <= 1;
            reged <= 0;
            int_sig <= 0;
            reregcnt <= 0;
        end else begin
            EBR_n <= 1;
            int_sig <= 0;

            if (reregcnt > 0) begin
                reregcnt <= reregcnt -1;
            end

            if (rchng7 && EBR_n) begin
                if (reged ||!buster09 || (quickint_cycle7 && fakeint)) begin
                    if (reregcnt == 0) begin
                        EBR_n <= 0;
                        reged <= !reged;
                        reregcnt <= recyclecnt;
                    end
                end else begin
                    int_sig <= 1;
                end
            end
        end
    end

    // Sync Signals to 25MHz
    always @(negedge IORST_n, negedge clk) begin
        if (!IORST_n) begin
            reged25 <= 0;
            ebr25_n <= 0;
        end else begin
            reged25 <= reged;
            ebr25_n <= EBR_n;             // ebr_delay_n ist async -> sync to 25MHz
        end
    end

    // generate regchange sync to 25MHz BCLK
    // use SC0 as SNOOP bit to start Busrequest 2 BCLK early
    // use SC0 also to hold Bus if FIFO ist not empty when SBR_n get inactive
    always @(negedge IORST_n, posedge clk) begin
        if (!IORST_n) begin
            rchng <= 0;
        end else begin
            if (!ebr25_n) begin
                rchng <= 0;
            end else if (!reged25 && (!SBR_n || SC0)) begin
                rchng <= 1;
            end else if (reged25 && MASTER_n && SBR_n && !SC0) begin
                rchng <= 1;
            end
        end
    end

    always @(*) begin
        if (!IORST_n) begin
            mybus = 0;
        end else if (reged && !EBG_n && !rchng) begin
            mybus = 1;
		end else if (FCS_n && DTACK_n) begin
            mybus = 0;
        end
    end

endmodule
