`timescale 1ns/1ps
// dmamaster: ZIII master-cycle timing (FCS/DOE/DS) + SLACK->STERM reflection
module tb_dmamaster;
`include "check.vh"
    reg sclk=0, bclk=0, IORST_n=0, SLAVE_n=1, mybus=0, MASTER_n=1;
    reg SCSI_AS_n=1, READ=1, DTACK_n=1;
    reg [1:0] ADDRL=0, SIZ=0;
    wire SCSI_STERM_n, efcs, dma_aboel, dma_aboeh, dma_doe;
    wire [3:0] ds_n;

    // emulate top-level feedback: Z_FCS_n = mybus ? !efcs : 1
    wire Z_FCS_n = mybus ? ~efcs : 1'b1;

    dmamaster dut(.sclk(sclk),.bclk(bclk),.IORST_n(IORST_n),.SLAVE_n(SLAVE_n),.mybus(mybus),
        .MASTER_n(MASTER_n),.SCSI_AS_n(SCSI_AS_n),.SCSI_STERM_n(SCSI_STERM_n),.READ(READ),
        .Z_FCS_n(Z_FCS_n),.DTACK_n(DTACK_n),.ADDRL(ADDRL),.SIZ(SIZ),.efcs(efcs),
        .dma_aboel(dma_aboel),.dma_aboeh(dma_aboeh),.dma_doe(dma_doe),.ds_n(ds_n));

    always #10 sclk=~sclk;   // 50 MHz
    always #20 bclk=~bclk;   // 25 MHz

    integer tcnt;
    initial begin
        repeat(2) @(posedge sclk); IORST_n=1; @(posedge sclk); #1;
        chk(ds_n===4'b1111, "idle: ds_n tri-state pattern (all 1)");
        chk(dma_aboel===1'b0, "idle: dma_aboel low (mybus=0)");

        // ---- dma_aboel tracks mybus ----
        mybus=1; #2; chk(dma_aboel===1'b1, "dma_aboel = mybus (1)");
        mybus=0; #2; chk(dma_aboel===1'b0, "dma_aboel = mybus (0)");

        // ---- SLACK->STERM reflection (slave SCSI access path) ----
        // MASTER_n=1, mybus=0 (so MASTER_n!=mybus), AS asserted, Zorro cycle, DTACK seen
        MASTER_n=1; mybus=0; SCSI_AS_n=0; DTACK_n=0; SLAVE_n=0;
        // Z_FCS_n is 1 here (mybus=0) -> need !Z_FCS_n; drive a slave Zorro cycle:
        // emulate Z_FCS_n low during slave by temporarily forcing via mybus path is N/A;
        // instead test the master case below. For slave reflection drive directly:
        force Z_FCS_n = 1'b0;
        @(negedge bclk); #1;
        chk(SCSI_STERM_n===1'b0, "STERM asserted back to NCR when DTACK seen (tie-back)");
        DTACK_n=1; @(negedge bclk); #1;
        chk(SCSI_STERM_n===1'b1, "STERM deasserts when DTACK gone");
        release Z_FCS_n;
        SCSI_AS_n=1; SLAVE_n=1;

        // ---- attempt a DMA master cycle, observe efcs/dma_doe/ds_n ----
        @(negedge bclk);
        MASTER_n=0; mybus=1; SCSI_AS_n=0; READ=1; ADDRL=2'b00; SIZ=2'b00; DTACK_n=1; SLAVE_n=1;
        tcnt=0;
        while (efcs!==1'b1 && tcnt<40) begin @(posedge sclk); tcnt=tcnt+1; end
        chk(efcs===1'b1, "DMA master cycle starts (efcs asserts -> drives FCS)");
        // let dma_doe come up; model the Zorro slave acking the data
        tcnt=0;
        while (dma_doe!==1'b1 && tcnt<40) begin @(posedge sclk); tcnt=tcnt+1; end
        $display("  [info] dma_doe=%b ds_n=%b (READ=%b ADDRL=%b SIZ=%b)", dma_doe, ds_n, READ, ADDRL, SIZ);
        chk(dma_doe===1'b1, "DOE asserts during master cycle");
        chk(ds_n===4'b0000, "READ longword: all DS asserted (ds_n=0000)");
        // terminate
        DTACK_n=0; @(negedge bclk); @(negedge bclk);
        MASTER_n=1; mybus=0; SCSI_AS_n=1; DTACK_n=1;
        repeat(3) @(posedge sclk);

        summary("tb_dmamaster");
        $finish;
    end
    initial begin #200000; $display("tb_dmamaster: GLOBAL TIMEOUT"); $finish; end
endmodule
