`timescale 1ns/1ps
// parallelrom: parallel flash ROM strobe generator (CE/OE/WE + waitstates)
module tb_parallelrom;
`include "check.vh"
    reg clk=0, IORST_n=0, romcycle=0, DOE=0, READ=1, FC2=0;
    reg [3:0] DS_n=4'b1111;
    wire dtack, ROM_CE_n, ROM_OE_n, ROM_WE_n;

    parallelrom dut(.clk(clk),.IORST_n(IORST_n),.romcycle(romcycle),.DOE(DOE),
        .DS_n(DS_n),.READ(READ),.FC2(FC2),.dtack(dtack),
        .ROM_CE_n(ROM_CE_n),.ROM_OE_n(ROM_OE_n),.ROM_WE_n(ROM_WE_n));
    always #10 clk=~clk;

    integer i, tcnt;
    initial begin
        repeat(2) @(posedge clk); IORST_n=1; @(posedge clk);
        chk(ROM_CE_n===1'b1 && ROM_OE_n===1'b1 && ROM_WE_n===1'b1, "idle: CE/OE/WE high");

        // ---- READ cycle ----
        @(negedge clk); romcycle=1; READ=1; DOE=1; DS_n=4'b0000;
        // wait for dtack, bounded
        tcnt=0; while (dtack!==1'b1 && tcnt<20) begin @(posedge clk); tcnt=tcnt+1; end
        chk(dtack===1'b1,     "read: dtack eventually asserts");
        chk(ROM_CE_n===1'b0,  "read: ROM_CE_n asserted");
        chk(ROM_OE_n===1'b0,  "read: ROM_OE_n asserted");
        chk(ROM_WE_n===1'b1,  "read: ROM_WE_n stays high");
        chk(tcnt>=3,          "read: waitstates inserted before dtack");
        @(negedge clk); romcycle=0; DOE=0; DS_n=4'b1111;
        repeat(3) @(posedge clk);
        chk(ROM_CE_n===1'b1,  "after cycle: CE deasserts");

        // ---- WRITE cycle ----
        @(negedge clk); romcycle=1; READ=0; DOE=1; DS_n=4'b0000;
        tcnt=0; while (dtack!==1'b1 && tcnt<20) begin @(posedge clk); tcnt=tcnt+1; end
        chk(dtack===1'b1,     "write: dtack eventually asserts");
        chk(ROM_WE_n===1'b0,  "write: ROM_WE_n asserted (DOE & DS)");
        chk(ROM_OE_n===1'b1,  "write: ROM_OE_n stays high");
        @(negedge clk); romcycle=0; DOE=0; DS_n=4'b1111;
        repeat(3) @(posedge clk);

        summary("tb_parallelrom");
        $finish;
    end
    initial begin #50000; $display("tb_parallelrom: GLOBAL TIMEOUT"); $finish; end
endmodule
