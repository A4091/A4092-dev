`timescale 1ns/1ps
//==============================================================================
// U6 address-low buffer direction control: '245 (A4092) vs '543 as-built (A4770)
// vs the A4770_DIRFIX rework (the REAL registered break-before-make logic from
// A4092.v).  Injects the MASTER(chip) vs BMASTER(CPLD) skew and measures the
// "both directions ON" window at the slave->master edge.
//==============================================================================
module u6dut #(parameter TPD=7) (input MASTER_n, input CLK, input integer MODE, output overlap);
    wire BMASTER;  assign #TPD BMASTER = ~MASTER_n;   // CPLD output, lags raw 770 pin
    wire ABOEL_n = 1'b0;

    // MODE 2 = the actual rework logic (copy of A4092.v A4770_DIRFIX block)
    reg       dir_ab_en = 1'b0;
    reg [1:0] dir_guard = 2'b00;
    always @(posedge CLK or posedge MASTER_n) begin
        if (MASTER_n) begin dir_ab_en <= 1'b0; dir_guard <= 2'b00; end
        else begin
            if (dir_guard[1]) dir_ab_en <= 1'b1;
            else              dir_guard <= dir_guard + 1'b1;
        end
    end
    wire SCSI_DIR_AB_n = ~dir_ab_en;   // = CEAB for the address buffers in the fix

    reg drvA, drvB;
    always @(*) case (MODE)
        0: begin drvB = ~MASTER_n      & ~ABOEL_n; drvA = ~BMASTER & ~ABOEL_n; end // '543 as-built
        1: begin drvB =  BMASTER       & ~ABOEL_n; drvA = ~BMASTER & ~ABOEL_n; end // '245 single DIR
        2: begin drvB = ~SCSI_DIR_AB_n & ~ABOEL_n; drvA = ~BMASTER & ~ABOEL_n; end // A4770_DIRFIX
        default: begin drvB = 1'b0; drvA = 1'b0; end
    endcase
    assign overlap = drvA & drvB;
endmodule

module tb_u6_contention;
    reg MASTER_n; integer MODE; reg CLK = 0;
    always #10 CLK = ~CLK;   // 50 MHz CLK_50M
    wire ov3, ov7, ov12;
    u6dut #(.TPD(3))  d3 (.MASTER_n(MASTER_n), .CLK(CLK), .MODE(MODE), .overlap(ov3));
    u6dut #(.TPD(7))  d7 (.MASTER_n(MASTER_n), .CLK(CLK), .MODE(MODE), .overlap(ov7));
    u6dut #(.TPD(12)) d12(.MASTER_n(MASTER_n), .CLK(CLK), .MODE(MODE), .overlap(ov12));
    time s3,s7,s12; real w3,w7,w12;
    always @(posedge ov3)  s3=$time;  always @(negedge ov3)  w3 =$time-s3;
    always @(posedge ov7)  s7=$time;  always @(negedge ov7)  w7 =$time-s7;
    always @(posedge ov12) s12=$time; always @(negedge ov12) w12=$time-s12;

    task do_edge; begin MASTER_n=1; #80; w3=0; w7=0; w12=0; MASTER_n=0; #120; MASTER_n=1; #40; end endtask

    real w245, w543, wfix;
    initial begin
        $dumpfile("u6_contention.vcd"); $dumpvars(0, tb_u6_contention);
        $display("=== U6: 'both directions ON' window at slave->master vs CPLD skew Tpd ===");
        MODE=1; do_edge; w245=w7; $display("  245 transceiver (A4092, single DIR)     : Tpd3=%0.1f  Tpd7=%0.1f  Tpd12=%0.1f ns", w3,w7,w12);
        MODE=0; do_edge; w543=w7; $display("  543 as-built    (A4770, CEAB=MASTER)    : Tpd3=%0.1f  Tpd7=%0.1f  Tpd12=%0.1f ns", w3,w7,w12);
        MODE=2; do_edge; wfix=w7; $display("  A4770_DIRFIX rework (registered B-b-M)   : Tpd3=%0.1f  Tpd7=%0.1f  Tpd12=%0.1f ns", w3,w7,w12);
        $display("=== window>0 => buffer drives A->B and B->A at once (out-of-spec; '245 cannot) ===");
        if (w245==0.0 && w543>0.0 && wfix==0.0)
            $display("tb_u6_contention: PASS ('543-only overlap=%0.1fns; '245 clean; DIRFIX rework closes it)", w543);
        else
            $display("tb_u6_contention: FAIL (245=%0.1f 543=%0.1f fix=%0.1f)", w245,w543,wfix);
        $finish;
    end
endmodule
