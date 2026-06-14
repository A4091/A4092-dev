`timescale 1ns/1ps
// interrupthandling: INT2 passthrough + programmable vector + ZIII quick-interrupt
module tb_interrupthandling;
`include "check.vh"
    reg clk=0, intreg_cycle=0, IORST_n=0, DOE=0, DS0_n=1, READ=1, set_reset=0;
    reg [7:0] din=0;
    reg SINT_n=1, FCS_n=1, SLAVE_n=1, quickint_cycle=0;
    wire [7:0] dout; wire vector_read, dtack, int_sig, slave;

    interrupthandling dut(.clk(clk),.intreg_cycle(intreg_cycle),.IORST_n(IORST_n),.DOE(DOE),
        .DS0_n(DS0_n),.READ(READ),.set_reset(set_reset),.din(din),.dout(dout),
        .vector_read(vector_read),.dtack(dtack),.SINT_n(SINT_n),.int_sig(int_sig),
        .FCS_n(FCS_n),.SLAVE_n(SLAVE_n),.quickint_cycle(quickint_cycle),.slave(slave));
    always #10 clk=~clk;

    initial begin
        repeat(2) @(posedge clk); IORST_n=1; @(posedge clk); #1;
        chk(dout===8'd24, "reset vector = 24 (spurious)");

        // ---- INT2 passthrough (FCS_n high allows int_sig update) ----
        FCS_n=1; SINT_n=0; #2; chk(int_sig===1'b1, "SINT asserted -> int_sig high");
        SINT_n=1; #2;        chk(int_sig===1'b0, "SINT released -> int_sig low");

        // ---- program interrupt vector = 0x45, set_reset=1 (assign) ----
        @(negedge clk); intreg_cycle=1; DOE=1; READ=0; DS0_n=0; din=8'h45; set_reset=1;
        @(posedge clk); #1; chk(dtack===1'b1, "vector write asserts dtack");
        @(negedge clk); intreg_cycle=0; DOE=0; DS0_n=1; READ=1;
        repeat(2) @(posedge clk); #1; chk(dout===8'h45, "vector value latched");

        // ---- read vector back ----
        @(negedge clk); intreg_cycle=1; DOE=1; READ=1; DS0_n=1;
        @(posedge clk); #1; chk(vector_read===1'b1, "vector read pulses vector_read");
        @(posedge clk); #1; chk(dtack===1'b1, "vector read asserts dtack");
        @(negedge clk); intreg_cycle=0; DOE=0;
        repeat(2) @(posedge clk);

        // ---- ZIII quick interrupt ----
        // arm: int_sig=1 (SINT low while FCS high), vector already assigned
        FCS_n=1; SINT_n=0; #2; chk(int_sig===1'b1, "armed: int_sig high");
        FCS_n=0;  // cycle running, int_sig holds
        // poll phase: quickint & !DOE & DS0_n -> slave asserts
        @(negedge clk); quickint_cycle=1; DOE=0; DS0_n=1; SLAVE_n=1;
        @(posedge clk); #1; chk(slave===1'b1, "quick-int poll phase asserts slave");
        // vector phase: quickint & DOE & !DS0_n & !SLAVE_n -> vector_read
        @(negedge clk); DOE=1; DS0_n=0; SLAVE_n=0;
        @(posedge clk); #1; chk(vector_read===1'b1, "quick-int vector phase drives vector_read");
        @(negedge clk); quickint_cycle=0; DOE=0; DS0_n=1; SLAVE_n=1; FCS_n=1; SINT_n=1;
        repeat(2) @(posedge clk);

        summary("tb_interrupthandling");
        $finish;
    end
    initial begin #80000; $display("tb_interrupthandling: GLOBAL TIMEOUT"); $finish; end
endmodule
