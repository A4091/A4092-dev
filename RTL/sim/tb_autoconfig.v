`timescale 1ns/1ps
// autoconfig: Zorro III autoconfig ROM + base-address assignment
module tb_autoconfig;
`include "check.vh"
    reg clk=0, Z_FCS_n=1, DOE=0, DS3_n=1, READ=1, IORST_n=0, BERR_n=1, SENSEZ3=1, CFGIN_n=1;
    reg [1:0] FC=2'b10;
    reg [31:24] DIN=8'h00;
    reg [31:24] addrh=8'hFF;
    reg [8:2] addrl=0;
    wire [3:0] data_out; wire cfgout, config_cycle, dtack, card_cycle;

    localparam [15:0] MFG = 16'hC0DE;
    localparam [7:0]  PROD= 8'd2;
    localparam [31:0] SER = 32'h01041500;
    localparam [15:0] RV  = 16'd512;

    autoconfig dut(.clk(clk),.Z_FCS_n(Z_FCS_n),.DOE(DOE),.DS3_n(DS3_n),.FC(FC),.READ(READ),
        .DIN(DIN),.data_out(data_out),.addrh(addrh),.addrl(addrl),.IORST_n(IORST_n),
        .BERR_n(BERR_n),.SENSEZ3(SENSEZ3),.CFGIN_n(CFGIN_n),.cfgout(cfgout),
        .config_cycle(config_cycle),.dtack(dtack),.card_cycle(card_cycle),
        .mfg_id(MFG),.prod_id(PROD),.serial(SER),.romvec(RV));
    always #10 clk=~clk;

    // select autoconfig register 'sig' (byte offset) via the addrl mapping
    task sel(input [7:0] s); begin addrl = {s[1], s[7:2]}; end endtask

    initial begin
        repeat(2) @(posedge clk); IORST_n=1; @(posedge clk);

        // ---- ROM nibble checks (combinational on addr_sig) ----
        sel(8'h00); #1; chk(data_out===4'b1001, "off 0x00: type = ZIII+ROM (romvec>0)");
        sel(8'h04); #1; chk(data_out===(~PROD[7:4]), "off 0x04: ~prod_id hi nibble");
        sel(8'h06); #1; chk(data_out===(~PROD[3:0]), "off 0x06: ~prod_id lo nibble");
        sel(8'h10); #1; chk(data_out===(~MFG[15:12]),"off 0x10: ~mfg_id[15:12]");
        sel(8'h16); #1; chk(data_out===(~MFG[3:0]),  "off 0x16: ~mfg_id[3:0]");
        sel(8'h28); #1; chk(data_out===(~RV[15:12]), "off 0x28: ~romvec[15:12]");
        sel(8'h2A); #1; chk(data_out===(~RV[11:8]),  "off 0x2A: ~romvec[11:8]");

        // ---- enter config space ----
        CFGIN_n=0; SENSEZ3=1; BERR_n=1; FC=2'b10; addrh=8'hFF; sel(8'h00);
        @(negedge clk); Z_FCS_n=0;
        @(posedge clk); #1; chk(config_cycle===1'b1, "addrh=0xFF -> config_cycle");
        chk(card_cycle===1'b0, "not yet a card cycle");

        // ---- write base address 0x40 to offset 0x44 ----
        @(negedge clk); sel(8'h44); DIN=8'h40; DOE=1; DS3_n=0; READ=0;
        @(posedge clk); #1; chk(dtack===1'b1, "config write asserts dtack");
        @(negedge clk); DOE=0; DS3_n=1; READ=1;
        // end the cycle: cfgout latches on Z_FCS_n rising
        @(negedge clk); Z_FCS_n=1; #1;
        chk(cfgout===1'b1, "cfgout asserts after configuration");

        // ---- now a normal access at the assigned base 0x40 ----
        @(negedge clk); addrh=8'h40; CFGIN_n=0; Z_FCS_n=0;
        @(posedge clk); #1; chk(card_cycle===1'b1, "access at assigned base -> card_cycle");
        chk(config_cycle===1'b0, "no longer config_cycle once configured");
        @(negedge clk); Z_FCS_n=1;
        repeat(2) @(posedge clk);

        summary("tb_autoconfig");
        $finish;
    end
    initial begin #80000; $display("tb_autoconfig: GLOBAL TIMEOUT"); $finish; end
endmodule
