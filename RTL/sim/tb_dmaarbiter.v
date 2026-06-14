`timescale 1ns/1ps
// dmaarbiter: NCR<->ZorroIII bus arbitration. Exercises SC0 real-vs-fake grant paths.
module tb_dmaarbiter;
`include "check.vh"
    reg clk7m=0, clk=0, IORST_n=0, MASTER_n=1, SBR_n=1, SC0=0;
    reg EBG_n=1, FCS_n=1, DTACK_n=1, buster09=0, quickint_cycle=0;
    wire mybus, SBG_n, EBR_n, fakeint;

    dmaarbiter dut(.clk7m(clk7m),.clk(clk),.IORST_n(IORST_n),.MASTER_n(MASTER_n),.SBR_n(SBR_n),
        .SC0(SC0),.EBG_n(EBG_n),.FCS_n(FCS_n),.DTACK_n(DTACK_n),.mybus(mybus),.SBG_n(SBG_n),
        .EBR_n(EBR_n),.buster09(buster09),.quickint_cycle(quickint_cycle),.fakeint(fakeint));

    always #20  clk   = ~clk;     // 25 MHz
    always #70  clk7m = ~clk7m;   // ~7 MHz

    task do_reset; begin
        IORST_n=0; SBR_n=1; SC0=0; EBG_n=1; MASTER_n=1; DTACK_n=1; FCS_n=1;
        repeat(3) @(posedge clk); IORST_n=1; @(posedge clk);
    end endtask

    integer tcnt;
    initial begin
        // =========================================================
        // CASE A: false bus request path (SC0 = 0)
        //   -> grant must come from fake_bg, real_bg must stay 0
        // =========================================================
        do_reset;
        SC0=0; MASTER_n=1; SBR_n=0;            // NCR requests, snoop=0 => "false"
        repeat(4) @(posedge clk); #1;
        chk(dut.fake_bg===1'b1, "SC0=0: fake_bg grants the request");
        chk(SBG_n===1'b0,       "SC0=0: SBG_n asserted (NCR granted)");
        chk(dut.real_bg===1'b0, "SC0=0: real_bg NEVER asserts (proper path disabled)");
        SBR_n=1; repeat(2) @(posedge clk); #1;
        chk(dut.fake_bg===1'b0, "SC0=0: fake_bg releases when SBR_n high");

        // =========================================================
        // CASE B: real bus request path (SC0 = 1), bus granted (EBG_n=0)
        //   -> card registers (reged), mybus asserts, real_bg grants
        // =========================================================
        do_reset;
        EBG_n=0;                 // Zorro III bus is available to us
        SC0=1; MASTER_n=1; SBR_n=0;
        tcnt=0;
        while (dut.reged!==1'b1 && tcnt<400) begin @(posedge clk7m); tcnt=tcnt+1; end
        chk(dut.reged===1'b1, "SC0=1: card registers for ZIII bus (reged)");
        tcnt=0;
        while (mybus!==1'b1 && tcnt<400) begin @(posedge clk); tcnt=tcnt+1; end
        chk(mybus===1'b1,       "SC0=1: mybus asserts (we own ZIII bus)");
        // real_bg should grant the NCR now
        repeat(2) @(posedge clk); #1;
        $display("  [info] real_bg=%b fake_bg=%b SBG_n=%b mybus=%b reged=%b",
                 dut.real_bg, dut.fake_bg, SBG_n, mybus, dut.reged);
        chk(dut.real_bg===1'b1, "SC0=1: real_bg grants the NCR (proper path)");
        chk(SBG_n===1'b0,       "SC0=1: SBG_n asserted via real_bg");

        // NCR takes the bus, finishes, releases
        MASTER_n=0; repeat(2) @(posedge clk);
        SBR_n=1; SC0=0; MASTER_n=1; FCS_n=1; DTACK_n=1;  // SC0=0 lets the card de-register/release
        tcnt=0; while (mybus!==1'b0 && tcnt<400) begin @(posedge clk); tcnt=tcnt+1; end
        chk(mybus===1'b0, "bus released after request ends");

        summary("tb_dmaarbiter");
        $finish;
    end
    initial begin #500000; $display("tb_dmaarbiter: GLOBAL TIMEOUT"); $finish; end
endmodule
