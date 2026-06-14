`timescale 1ns/1ps
// scsiaccess: CPU(slave) access to 53C7xx registers - AS/DS/SREG + SLACK->dtack
module tb_scsiaccess;
`include "check.vh"
    reg bclk=0, DOE=0, READ=1, scsi_cycle=0, mybus=0, SLACK_n=1;
    reg [3:0] DS_n=4'b1111;
    wire SCSI_SREG_n, RAMCS_n, scsi_as_sig, scsi_ds_sig, dtack;

    scsiaccess dut(.bclk(bclk),.DOE(DOE),.DS_n(DS_n),.READ(READ),.scsi_cycle(scsi_cycle),
        .mybus(mybus),.SCSI_SREG_n(SCSI_SREG_n),.RAMCS_n(RAMCS_n),.scsi_as_sig(scsi_as_sig),
        .scsi_ds_sig(scsi_ds_sig),.SLACK_n(SLACK_n),.dtack(dtack));
    always #20 bclk=~bclk;  // 25 MHz

    initial begin
        // idle
        scsi_cycle=0; @(negedge bclk); @(negedge bclk); #1;
        chk(scsi_as_sig===1'b0 && SCSI_SREG_n===1'b1, "idle: AS low, SREG high");
        chk(dtack===1'b0, "idle: no dtack");

        // ---- start a slave READ register access ----
        @(negedge bclk); scsi_cycle=1; mybus=0; DOE=1; READ=1; DS_n=4'b0000; SLACK_n=1;
        @(negedge bclk); #1;           // IDLE->AS
        chk(scsi_as_sig===1'b1, "AS asserted to NCR after 1st bclk");
        @(negedge bclk); #1;           // AS->CS
        chk(SCSI_SREG_n===1'b0, "register select (CS/SREG) asserted in CS state");
        chk(scsi_ds_sig===1'b1, "DS asserted to NCR");

        // ---- NCR acknowledges via SLACK -> dtack to Zorro ----
        SLACK_n=0; #2;
        chk(dtack===1'b1, "SLACK low -> dtack to Zorro");
        SLACK_n=1; #2;
        chk(dtack===1'b0, "SLACK high -> dtack deasserts");

        // ---- end cycle ----
        @(negedge bclk); scsi_cycle=0; DOE=0; DS_n=4'b1111;
        #1; chk(scsi_as_sig===1'b0 && SCSI_SREG_n===1'b1, "cycle end: AS/SREG released (async)");

        // ---- slave WRITE: DS delayed one clock vs read ----
        @(negedge bclk); scsi_cycle=1; DOE=1; READ=0; DS_n=4'b0000;
        @(negedge bclk); #1;
        chk(scsi_as_sig===1'b1, "write: AS asserted");
        chk(scsi_ds_sig===1'b0, "write: DS still low in AS state (1 clk delayed like 030)");
        @(negedge bclk); #1;
        chk(scsi_ds_sig===1'b1, "write: DS asserted in CS state");
        @(negedge bclk); scsi_cycle=0; DOE=0; DS_n=4'b1111;
        repeat(2) @(negedge bclk);

        summary("tb_scsiaccess");
        $finish;
    end
    initial begin #100000; $display("tb_scsiaccess: GLOBAL TIMEOUT"); $finish; end
endmodule
