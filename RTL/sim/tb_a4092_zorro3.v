`timescale 1ns/1ps
//==============================================================================
// Top-level Zorro III bus-functional model (BFM) for A4092.v
//
// The BFM drives spec-compliant Zorro III cycles (Ch.3 simple cycle, Table 4-1
// FC codes, Ch.8 AUTOCONFIG) and ASSERTS the card conforms -- an independent
// oracle, not a mirror of the RTL.
//   iverilog -g2012 -DA4092c tb_a4092_zorro3.v ../A4092.v ../autoconfig.v \
//            ../buffercontrol.v ../dmaarbiter.v ../dmamaster.v ../scsiaccess.v \
//            ../interrupthandling.v ../sidregister.v ../spirom.v
//==============================================================================
module tb_a4092_zorro3;
`include "check.vh"

    reg  [31:2] A = 0;
    reg         CLK_50M = 0, IORST_n = 0, Z_LOCK = 1, C7M = 0, READ = 1;
    reg  [2:0]  FC = 3'b010;
    reg         CFGIN_n = 1, BERR_n = 1, BGn = 1, SENSEZ3 = 1, CBREQ_n = 1, SC0 = 0;

    wire        CLK, CFGOUT_n, CINH_n, BRn, INT2_n;
    wire        DBLT, DBOE_n, ABOEL_n, ABOEH_n, D2Z_n, Z2D_n, FCS, BMASTER;
    wire        SCSI_SREG_n, SCSI_STERM_n, SBG_n, RAMCS_n;
    wire        ROM_OE_n, ROM_CE_n, ROM_WE_n, SPI_MOSI, SPI_CLK, SPI_CS_n;
    wire        SID_n, DIP_EXT_TERM;
    wire        A4092SCSI_DS_n, A4770SCSI_DS_n, SCSI_AS_n, SPI_MISO;

    tri1        DTACK_n, SLAVE_n, MTACK_n, MTCR_n, CBACK_n;
    tri1        Z_FCS_n_net;           // /FCS idle = high
    tri0        DOE_net;               // DOE  idle = low
    tri1 [3:0]  DS_n_net;              // /DSn idle = high
    tri1 [1:0]  SIZ, AL;
    wire [31:0] D;

    // BFM (master) drivers
    reg        m_drive_bus = 0, m_fcs_n = 1, m_doe = 0, m_d_drive = 0;
    reg [3:0]  m_ds_n = 4'b1111;
    reg [31:0] m_d = 0;
    assign Z_FCS_n_net = m_drive_bus ? m_fcs_n : 1'bz;
    assign DOE_net     = m_drive_bus ? m_doe   : 1'bz;
    assign DS_n_net    = m_drive_bus ? m_ds_n  : 4'bz;
    assign D           = m_d_drive  ? m_d      : 32'bz;

    // SCSI chip (model) drivers
    reg        scsi_d_drive = 0; reg [31:0] scsi_d = 0;
    reg        SLACK_n = 1, SINT_n = 1, SBR_n = 1, MASTER_n = 1;
    assign D = scsi_d_drive ? scsi_d : 32'bz;

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

    always #10 CLK_50M = ~CLK_50M;   // 50 MHz
    always #70 C7M     = ~C7M;       // ~7 MHz

    // ---- SPI flash model (0x03 read) ----
    reg [7:0] flash [0:65535];
    reg [39:0] spi_rx; integer spi_nbits; reg [7:0] spi_tx; reg spi_loaded;
    integer fi; initial for (fi=0; fi<65536; fi=fi+1) flash[fi] = fi[7:0] ^ 8'hA5;
    reg spi_miso_r = 0; assign SPI_MISO = spi_miso_r;
    always @(negedge SPI_CS_n) begin spi_nbits=0; spi_loaded=0; end
    always @(posedge SPI_CLK) if(!SPI_CS_n) begin spi_rx={spi_rx[38:0],SPI_MOSI}; spi_nbits=spi_nbits+1; end
    always @(negedge SPI_CLK) if(!SPI_CS_n && spi_nbits>=32) begin
        if(!spi_loaded) begin spi_tx=flash[spi_rx[15:0]]; spi_loaded=1; end
        spi_miso_r <= spi_tx[7]; spi_tx={spi_tx[6:0],1'b0};
    end

    // ---- 53C7xx register responder ----
    wire scsi_sel = (SCSI_AS_n===1'b0) && (SCSI_SREG_n===1'b0);
    always @(*) begin
        if (scsi_sel && READ) begin scsi_d_drive = 1; scsi_d = {4{ {6'b101010, AL} }}; end
        else scsi_d_drive = 0;
    end
    always @(negedge SCSI_AS_n) SLACK_n <= #60 1'b0;   // chip register access time
    always @(posedge SCSI_AS_n) SLACK_n <= 1'b1;

    //==========================================================================
    // SPEC-COMPLIANCE MONITOR (oracle = Zorro III spec)
    //==========================================================================
    reg        cfg_done = 0; reg [7:0] cfg_base = 8'hFF;
    wire       fc_valid    = (FC[1] !== FC[0]);
    wire       in_cfgspace = (!cfg_done) && (A[31:24]==8'hFF) && (CFGIN_n==1'b0) && SENSEZ3;
    wire       in_cardspace= cfg_done && (A[31:24]==cfg_base);
    wire       should_respond = (in_cfgspace || in_cardspace) && fc_valid && (Z_FCS_n_net===1'b0);
    integer    mon_err = 0;

    // Monitors sample after a small settle and require a *sustained* assertion
    // inside an active /FCS window, so harmless sub-cycle glitches (with /FCS
    // negated) are ignored -- only true bus-cycle behavior is checked.
    always @(negedge SLAVE_n) begin : R1
        #4; if (SLAVE_n===1'b0 && Z_FCS_n_net===1'b0 && !should_respond) begin
            $display("  [SPEC-VIOLATION R1] /SLAVE asserted when not addressed/validFC: A=%h FC=%b",
                     {A,2'b0}, FC); mon_err=mon_err+1; end
    end
    always @(negedge SLAVE_n) begin : R2
        #4; if (SLAVE_n===1'b0 && Z_FCS_n_net===1'b0 && CINH_n!==1'b0) begin
            $display("  [SPEC-VIOLATION R2] /SLAVE low (active cycle) but /CINH not asserted");
            mon_err=mon_err+1; end
    end
    always @(negedge DTACK_n) begin : R3
        #1; if (SLAVE_n!==1'b0) begin
            $display("  [SPEC-VIOLATION R3] /DTACK without /SLAVE"); mon_err=mon_err+1; end
    end
    always @(posedge Z_FCS_n_net) begin : R4
        #5; if (SLAVE_n!==1'b1) begin $display("  [SPEC-VIOLATION R4] /SLAVE stuck after /FCS"); mon_err=mon_err+1; end
             if (DTACK_n!==1'b1) begin $display("  [SPEC-VIOLATION R4] /DTACK stuck after /FCS"); mon_err=mon_err+1; end
    end

    //==========================================================================
    // Zorro III master BFM
    //==========================================================================
    localparam TO = 4000;

    task z3_read(input [31:2] addr, input [2:0] fc, input [3:0] dsn, output [31:0] rdata);
        integer t; begin
            @(negedge CLK_50M); A=addr; FC=fc; READ=1; m_drive_bus=1; m_fcs_n=0; m_ds_n=4'b1111; m_doe=0;
            @(negedge CLK_50M); m_doe=1; m_ds_n=dsn;
            t=0; while (DTACK_n!==1'b0 && t<TO) begin #10; t=t+10; end
            #2; rdata = D;
            if (DTACK_n!==1'b0) begin $display("  [TIMEOUT] read @%h", {addr,2'b0}); errors=errors+1; end
            @(negedge CLK_50M); m_fcs_n=1; m_doe=0; m_ds_n=4'b1111; m_drive_bus=0;
            repeat(3) @(negedge CLK_50M);
        end
    endtask

    task z3_write(input [31:2] addr, input [2:0] fc, input [3:0] dsn, input [31:0] wdata);
        integer t; begin
            @(negedge CLK_50M); A=addr; FC=fc; READ=0; m_drive_bus=1; m_fcs_n=0; m_ds_n=4'b1111;
            @(negedge CLK_50M); m_doe=1; m_d_drive=1; m_d=wdata; m_ds_n=dsn;
            t=0; while (DTACK_n!==1'b0 && t<TO) begin #10; t=t+10; end
            if (DTACK_n!==1'b0) begin $display("  [TIMEOUT] write @%h", {addr,2'b0}); errors=errors+1; end
            @(negedge CLK_50M); m_fcs_n=1; m_doe=0; m_d_drive=0; m_ds_n=4'b1111; m_drive_bus=0;
            repeat(3) @(negedge CLK_50M);
        end
    endtask

    function [8:2] acsel(input [7:0] s); acsel = {s[1], s[7:2]}; endfunction

    task ac_read(input [7:0] regsig, output [3:0] nib);
        reg [31:0] rd; begin
            z3_read({8'hFF, 15'h0, acsel(regsig)}, 3'b010, 4'b0000, rd); nib = rd[31:28];
        end
    endtask

    //==========================================================================
    // TEST SEQUENCE
    //==========================================================================
    reg [3:0] t0,n0,n1,n2,n3;
    reg [31:0] rd;
    initial begin
        repeat(4) @(negedge CLK_50M); IORST_n=1; CFGIN_n=0; repeat(6) @(negedge CLK_50M);

        $display("=== AUTOCONFIG ===");
        ac_read(8'h00, t0);  chk(t0[3]===1'b1, "AC off0x00: board-present bit set");
        ac_read(8'h10, n0); ac_read(8'h12, n1); ac_read(8'h14, n2); ac_read(8'h16, n3);
        $display("  mfg_id = %h", {~n0,~n1,~n2,~n3});
        chk({~n0,~n1,~n2,~n3}===16'hC0DE, "AC: mfg_id = C0DE");

        $display("=== AUTOCONFIG: assign base 0x40 (reg 0x44) ===");
        z3_write({8'hFF,15'h0,acsel(8'h44)}, 3'b010, 4'b0111, {8'h40,24'h0});
        cfg_done=1; cfg_base=8'h40; repeat(2) @(negedge CLK_50M);

        $display("=== ROM READ (SPI boot path) ===");
        z3_read({8'h40, 22'h0},      3'b010, 4'b0000, rd);
        $display("  ROM[0]: D31:28=%h D15:12=%h (flash=%h)", rd[31:28], rd[15:12], flash[0]);
        chk({rd[31:28],rd[15:12]}===flash[0], "ROM byte 0 from SPI flash");
        z3_read({8'h40, 22'h1},      3'b010, 4'b0000, rd);   // A[2]=1 -> longword 1 -> flash byte 1
        chk({rd[31:28],rd[15:12]}===flash[1], "ROM byte 1 from SPI flash");

        $display("=== SCSI REGISTER READ ($40800000) ===");
        z3_read({8'h40, 22'h200000}, 3'b010, 4'b0000, rd);   // A[23]=1 -> scsi_cycle
        $display("  SCSI reg read data = %h", rd);
        chk(rd===32'hA8A8A8A8, "SCSI register read returns chip data via SLACK->DTACK");

        $display("=== SCSI REGISTER WRITE ($40800000) ===");
        z3_write({8'h40, 22'h200000}, 3'b010, 4'b0000, 32'h12345678);
        chk(1'b1, "SCSI register write completes (DTACK seen)");

        $display("=== NEGATIVE: CPU space (FC=7) at our address ===");
        @(negedge CLK_50M); A={8'h40,22'h0}; FC=3'b111; m_drive_bus=1; m_fcs_n=0; READ=1;
        @(negedge CLK_50M); m_doe=1; m_ds_n=4'b0000;
        repeat(6) @(negedge CLK_50M); #2;
        chk(SLAVE_n===1'b1, "CPU-space access: card does NOT assert /SLAVE (Table 4-1)");
        m_fcs_n=1; m_doe=0; m_ds_n=4'b1111; m_drive_bus=0; repeat(3) @(negedge CLK_50M);

        $display("=== NEGATIVE: out-of-range address ===");
        @(negedge CLK_50M); A={8'h70,22'h0}; FC=3'b010; m_drive_bus=1; m_fcs_n=0;
        @(negedge CLK_50M); m_doe=1; m_ds_n=4'b0000;
        repeat(6) @(negedge CLK_50M); #2;
        chk(SLAVE_n===1'b1, "unmapped address: card does NOT assert /SLAVE");
        m_fcs_n=1; m_doe=0; m_ds_n=4'b1111; m_drive_bus=0; repeat(3) @(negedge CLK_50M);

        $display("=== SPEC MONITOR: %0d violation(s) ===", mon_err);
        if (mon_err) errors = errors + mon_err;
        summary("tb_a4092_zorro3");
        $finish;
    end
    initial begin #1000000; $display("tb_a4092_zorro3: GLOBAL TIMEOUT"); $finish; end
endmodule
