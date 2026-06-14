`timescale 1ns/1ps
// sidregister: virtual SCSI-ID / config register (replaces DIP switch)
module tb_sidregister;
`include "check.vh"
    reg clk=0, sid_cycle=0, IORST_n=0, DOE=0, DS0_n=1, READ=1;
    reg [7:0] DIN=0;
    wire [7:0] DOUT; wire sid_read, dtack;

    sidregister dut(.clk(clk),.sid_cycle(sid_cycle),.IORST_n(IORST_n),.DOE(DOE),
        .DS0_n(DS0_n),.READ(READ),.DIN(DIN),.DOUT(DOUT),.sid_read(sid_read),.dtack(dtack));
    always #10 clk=~clk;   // 50 MHz

    integer i;
    initial begin
        repeat(2) @(posedge clk); IORST_n=1; @(posedge clk);
        chk(DOUT===8'hFF, "reset default DOUT=0xFF");

        // ---- write 0x5A ----
        @(negedge clk); sid_cycle=1; DOE=1; READ=0; DS0_n=0; DIN=8'h5A;
        @(posedge clk); #1;
        chk(dtack===1'b1, "write cycle asserts dtack");
        @(negedge clk); sid_cycle=0; DOE=0; DS0_n=1; READ=1;
        repeat(2) @(posedge clk); #1;
        chk(DOUT===8'h5A, "written value latched into DOUT");

        // ---- read back ----
        @(negedge clk); sid_cycle=1; DOE=1; READ=1; DS0_n=1;
        @(posedge clk); #1;
        chk(sid_read===1'b1, "read cycle pulses sid_read (data enable)");
        @(posedge clk); #1;
        chk(dtack===1'b1,  "read cycle asserts dtack (after sid_read)");
        @(negedge clk); sid_cycle=0; DOE=0;
        repeat(3) @(posedge clk);

        summary("tb_sidregister");
        $finish;
    end
    initial begin #50000; $display("tb_sidregister: GLOBAL TIMEOUT"); $finish; end
endmodule
