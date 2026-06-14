`timescale 1ns/1ps
//==============================================================================
// DMA-master Zorro III BFM for A4092.v
//
// Here the card is the BUS MASTER. The BFM plays:
//   (a) the Zorro III bus controller  -> grants /BGn when the card registers (/BRn)
//   (b) the Zorro III target memory   -> answers the card's master cycle with /DTACK
//   (c) the 53C7xx DMA initiator      -> raises SBR, becomes local master, drives
//                                        address/SIZ/AS, consumes STERM.
// Spec oracle (Ch.3.4 arbitration, Ch.3.1.2 cycle): the card must not drive /FCS
// before it is granted the bus, must run a proper master cycle, and must reflect
// the memory's /DTACK back to the chip as STERM.
//==============================================================================
module tb_a4092_dma;
`include "check.vh"

    reg  [31:2] A = 0;
    reg         CLK_50M = 0, IORST_n = 0, Z_LOCK = 1, C7M = 0;
    reg  [2:0]  FC = 3'b010;
    reg         CFGIN_n = 1, BERR_n = 1, SENSEZ3 = 1, CBREQ_n = 1;
    reg         READ = 1;
    reg         BGn = 1;                      // bus grant (BFM controller -> card)

    wire        CLK, CFGOUT_n, CINH_n, BRn, INT2_n;
    wire        DBLT, DBOE_n, ABOEL_n, ABOEH_n, D2Z_n, Z2D_n, FCS, BMASTER;
    wire        SCSI_SREG_n, SCSI_STERM_n, SBG_n, RAMCS_n;
    wire        ROM_OE_n, ROM_CE_n, ROM_WE_n, SPI_MOSI, SPI_CLK, SPI_CS_n;
    wire        SID_n, DIP_EXT_TERM, A4092SCSI_DS_n, A4770SCSI_DS_n, SPI_MISO;

    tri1        DTACK_n, SLAVE_n, MTACK_n, MTCR_n, CBACK_n;
    tri1        Z_FCS_n_net;   tri0 DOE_net;   tri1 [3:0] DS_n_net;
    tri1 [1:0]  SIZ, AL;
    tri1        SCSI_AS_n;
    wire [31:0] D;

    // ---- 53C7xx initiator drivers ----
    reg         SBR_n = 1, SC0 = 0, MASTER_n = 1, SINT_n = 1;
    reg         chip_as_n = 1, chip_drive_as = 0;
    reg  [1:0]  chip_al = 0, chip_siz = 0;
    reg         chip_d_drive = 0; reg [31:0] chip_d = 0;
    assign SCSI_AS_n = chip_drive_as ? chip_as_n : 1'bz;
    assign AL  = (!MASTER_n) ? chip_al  : 2'bz;
    assign SIZ = (!MASTER_n) ? chip_siz : 2'bz;
    assign D   = chip_d_drive ? chip_d  : 32'bz;
    // STERM is driven by the CPLD to the chip; SLACK unused here
    reg SLACK_n = 1;

    // ---- target memory drivers ----
    reg  mem_d_drive = 0; reg [31:0] mem_d = 0; reg mem_dtack_n = 1;
    assign D       = mem_d_drive ? mem_d : 32'bz;
    assign DTACK_n = mem_dtack_n ? 1'bz : 1'b0;

    A4092 dut(
        .A(A), .AL(AL), .D(D), .CLK_50M(CLK_50M), .CLK(CLK),
        .IORST_n(IORST_n), .DS_n(DS_n_net), .FC(FC), .Z_LOCK(Z_LOCK), .C7M(C7M),
        .Z_FCS_n(Z_FCS_n_net), .DOE(DOE_net), .READ(READ), .DTACK_n(DTACK_n),
        .INT2_n(INT2_n), .CFGIN_n(CFGIN_n), .CFGOUT_n(CFGOUT_n), .SLAVE_n(SLAVE_n),
        .CINH_n(CINH_n), .MTCR_n(MTCR_n), .MTACK_n(MTACK_n), .BERR_n(BERR_n),
        .BGn(BGn), .BRn(BRn), .SENSEZ3(SENSEZ3),
        .DBLT(DBLT), .DBOE_n(DBOE_n), .ABOEL_n(ABOEL_n), .ABOEH_n(ABOEH_n),
        .D2Z_n(D2Z_n), .Z2D_n(Z2D_n), .FCS(FCS), .BMASTER(BMASTER),
        .SLACK_n(SLACK_n), .SINT_n(SINT_n), .SBR_n(SBR_n), .SIZ(SIZ), .SBG_n(SBG_n),
        .MASTER_n(MASTER_n), .SCSI_AS_n(SCSI_AS_n), .A4092SCSI_DS_n(A4092SCSI_DS_n),
        .A4770SCSI_DS_n(A4770SCSI_DS_n), .SCSI_SREG_n(SCSI_SREG_n),
        .SCSI_STERM_n(SCSI_STERM_n), .CBREQ_n(CBREQ_n), .CBACK_n(CBACK_n),
        .SC0(SC0), .RAMCS_n(RAMCS_n), .ROM_OE_n(ROM_OE_n), .ROM_CE_n(ROM_CE_n),
        .ROM_WE_n(ROM_WE_n), .SPI_MISO(SPI_MISO), .SPI_MOSI(SPI_MOSI),
        .SPI_CLK(SPI_CLK), .SPI_CS_n(SPI_CS_n), .SID_n(SID_n), .DIP_EXT_TERM(DIP_EXT_TERM)
    );
    assign SPI_MISO = 1'b0;

    always #10 CLK_50M = ~CLK_50M;   // 50 MHz
    always #70 C7M     = ~C7M;       // ~7 MHz

    //--------------------------------------------------------------------------
    // (a) Zorro III bus controller: card registers/unregisters via /BRn pulses.
    //     Grant /BGn while registered. (Spec Fig 3-3.)
    //--------------------------------------------------------------------------
    reg registered = 0;
    always @(negedge BRn) registered <= ~registered;
    always @(*) BGn = registered ? 1'b0 : 1'b1;

    //--------------------------------------------------------------------------
    // (b) Target memory: answer the card's master cycle with data + /DTACK.
    //--------------------------------------------------------------------------
    wire card_cycle_active = (Z_FCS_n_net===1'b0) && (BMASTER===1'b1);
    wire data_phase = card_cycle_active && (DOE_net===1'b1) && (DS_n_net!==4'b1111);
    function [31:0] memval(input [31:2] a); memval = {a[9:2], a[9:2], a[9:2], a[9:2]}; endfunction
    always @(*) begin
        if (data_phase && READ) begin mem_d_drive = 1; mem_d = memval(A); end
        else mem_d_drive = 0;
    end
    always @(posedge data_phase) mem_dtack_n <= #50 1'b0;   // memory access time
    always @(negedge card_cycle_active) mem_dtack_n <= 1'b1;

    // external data-buffer latch, controlled by the CPLD's DBLT (transparent latch).
    // Read data is captured here when DBLT is high and held through cycle teardown,
    // exactly as the on-board '16543 latches do -- this also verifies DBLT itself.
    reg [31:0] dbuf = 0;
    always @(*) if (DBLT===1'b1) dbuf = D;
    // memory captures write data during the master write data phase
    reg [31:0] mem_captured = 0;
    always @(*) if (data_phase && !READ) mem_captured = D;

    //==========================================================================
    // SPEC MONITOR (master side)
    //==========================================================================
    integer mon_err = 0;
    // MM1: card must not drive /FCS low until it has the grant (/BGn asserted)
    always @(negedge Z_FCS_n_net) begin
        #1; if (BGn!==1'b0) begin
            $display("  [SPEC-VIOLATION MM1] card drove /FCS before /BGn grant"); mon_err=mon_err+1; end
    end
    // MM3: during a master cycle the address buffers face out and data direction is correct
    always @(posedge data_phase) begin
        #1;
        if (BMASTER!==1'b1)  begin $display("  [SPEC-VIOLATION MM3] master cycle but BMASTER not set"); mon_err=mon_err+1; end
        if (ABOEL_n!==1'b0)  begin $display("  [SPEC-VIOLATION MM3] master cycle but addr buffers off"); mon_err=mon_err+1; end
        if (READ && Z2D_n!==1'b0) begin $display("  [SPEC-VIOLATION MM3] DMA read but Z2D not enabled"); mon_err=mon_err+1; end
        if (!READ && D2Z_n!==1'b0) begin $display("  [SPEC-VIOLATION MM3] DMA write but D2Z not enabled"); mon_err=mon_err+1; end
    end

    //==========================================================================
    // (c) 53C7xx DMA initiator: one transfer
    //==========================================================================
    localparam TO = 6000;
    task dma_xfer(input [31:2] addr, input do_read, input [31:0] wdata, output [31:0] rdata);
        integer t; begin
            rdata = 32'hx;
            // request the bus
            @(posedge C7M); SBR_n=0; SC0=1;
            // wait for the CPLD to grant the local bus to the chip
            t=0; while (SBG_n!==1'b0 && t<TO) begin #10; t=t+10; end
            if (SBG_n!==1'b0) begin $display("  [TIMEOUT] no SBG (chip grant)"); errors=errors+1; disable dma_xfer; end
            // become local master, drive address phase
            @(negedge CLK_50M); MASTER_n=0; A=addr; chip_al=addr[3:2]; chip_siz=2'b00; READ=do_read;
            chip_drive_as=1;
            if (!do_read) begin chip_d_drive=1; chip_d=wdata; end
            @(negedge CLK_50M); chip_as_n=0;          // assert chip address strobe
            // wait for the CPLD to terminate the chip cycle (STERM <- memory DTACK)
            t=0; while (SCSI_STERM_n!==1'b0 && t<TO) begin #10; t=t+10; end
            if (SCSI_STERM_n!==1'b0) begin $display("  [TIMEOUT] no STERM to chip"); errors=errors+1; end
            // finish
            @(negedge CLK_50M); chip_as_n=1; chip_drive_as=0; chip_d_drive=0; MASTER_n=1;
            if (do_read) rdata = dbuf;    // data latched by DBLT during the cycle
            // unregister
            @(posedge C7M); SBR_n=1; SC0=0;
            repeat(6) @(posedge CLK_50M);
        end
    endtask

    // Burst: keep SBR asserted and run N transfers within one bus ownership.
    // This exercises the SC0 "hold the bus while FIFO not empty" path (the only
    // place A4092 (real SC0) and A4770 (SC0 forced 0) should differ).
    task dma_burst(input [31:2] base, input integer n);
        integer i, t, done; begin
            done=0;
            @(posedge C7M); SBR_n=0; SC0=1;
            t=0; while (SBG_n!==1'b0 && t<TO) begin #10; t=t+10; end
            if (SBG_n!==1'b0) begin $display("  burst: no grant"); errors=errors+1; disable dma_burst; end
            @(negedge CLK_50M); MASTER_n=0; READ=1; chip_drive_as=1;
            for (i=0;i<n;i=i+1) begin
                @(negedge CLK_50M); A=base+i; chip_al=(base+i)&2'b11; chip_siz=2'b00; chip_as_n=0;
                t=0; while (SCSI_STERM_n!==1'b0 && t<TO) begin #10; t=t+10; end
                if (SCSI_STERM_n===1'b0) done=done+1; else $display("  burst xfer %0d: NO STERM", i);
                @(negedge CLK_50M); chip_as_n=1;
                t=0; while (SCSI_STERM_n!==1'b1 && t<1000) begin #10; t=t+10; end
            end
            chip_drive_as=0; MASTER_n=1;
            @(posedge C7M); SBR_n=1; SC0=0; repeat(6) @(posedge CLK_50M);
            $display("  burst: %0d/%0d transfers completed", done, n);
            chk(done===n, "DMA burst: all transfers completed within one bus ownership");
        end
    endtask

    reg [31:0] rd;
    initial begin
        repeat(6) @(negedge CLK_50M); IORST_n=1; repeat(6) @(negedge CLK_50M);

        $display("=== DMA READ (card masters ZIII, reads system memory) ===");
        dma_xfer(30'h0000_1000, 1'b1, 32'h0, rd);
        $display("  DMA read got %h (memval=%h)", rd, memval(30'h0000_1000));
        chk(SCSI_STERM_n===1'b1, "DMA read: STERM released after cycle");
        chk(rd===memval(30'h0000_1000), "DMA read: data path memory->chip correct");

        $display("=== DMA WRITE (card masters ZIII, writes system memory) ===");
        dma_xfer(30'h0000_2000, 1'b0, 32'hCAFEF00D, rd);
        $display("  memory captured %h (wrote CAFEF00D)", mem_captured);
        chk(mem_captured===32'hCAFEF00D, "DMA write: data path chip->memory correct");

        $display("=== second DMA read (re-arbitration) ===");
        dma_xfer(30'h0000_3000, 1'b1, 32'h0, rd);
        chk(rd===memval(30'h0000_3000), "DMA read #2: re-arbitrated and transferred");

        $display("=== DMA BURST (4 longwords, one bus ownership) ===");
        dma_burst(30'h0000_4000, 4);

        $display("=== SPEC MONITOR: %0d violation(s) ===", mon_err);
        if (mon_err) errors = errors + mon_err;
        summary("tb_a4092_dma");
        $finish;
    end
    initial begin #2000000; $display("tb_a4092_dma: GLOBAL TIMEOUT (likely DMA hang)"); $finish; end
endmodule
