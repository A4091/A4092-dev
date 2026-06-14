`timescale 1ns/1ps
// buffercontrol: external data/address buffer direction + OE control (combinational)
module tb_buffercontrol;
`include "check.vh"
    reg MASTER_n=1, Z_FCS_n=1, mybus=0, slave=0, READ=1, DOE=0, DTACK_n=1;
    reg dma_aboel=0, dma_aboeh=0;
    reg [3:0] DS_n=4'b1111;
    wire BMASTER, DBOE_n, D2Z_n, Z2D_n, DBLT, FCS, ABOEL_n, ABOEH_n;
    wire [1:0] addrl, siz;

    buffercontrol dut(.MASTER_n(MASTER_n),.Z_FCS_n(Z_FCS_n),.mybus(mybus),.slave(slave),
        .READ(READ),.DOE(DOE),.DTACK_n(DTACK_n),.dma_aboel(dma_aboel),.dma_aboeh(dma_aboeh),
        .DS_n(DS_n),.BMASTER(BMASTER),.DBOE_n(DBOE_n),.D2Z_n(D2Z_n),.Z2D_n(Z2D_n),
        .DBLT(DBLT),.FCS(FCS),.ABOEL_n(ABOEL_n),.ABOEH_n(ABOEH_n),.addrl(addrl),.siz(siz));

    initial begin
        // ---------- SLAVE READ ----------
        MASTER_n=1; mybus=0; slave=1; Z_FCS_n=0; READ=1; DOE=1; dma_aboel=0; dma_aboeh=0; #1;
        chk(FCS===1'b1,    "slave: FCS = !Z_FCS_n");
        chk(BMASTER===1'b0,"slave: BMASTER low");
        chk(ABOEL_n===1'b0,"slave: addr buffers enabled (ABOEL_n=0)");
        chk(D2Z_n===1'b0,  "slave read: data->Zorro (D2Z_n=0)");
        chk(Z2D_n===1'b1,  "slave read: Z2D off");
        chk(DBOE_n===1'b0, "slave read: DBOE on (DOE asserted)");

        // ---------- SLAVE WRITE ----------
        READ=0; #1;
        chk(Z2D_n===1'b0,  "slave write: Zorro->data (Z2D_n=0)");
        chk(D2Z_n===1'b1,  "slave write: D2Z off");
        chk(DBOE_n===1'b0, "slave write: DBOE on");

        // ---------- MASTER (DMA) READ ----------
        MASTER_n=0; mybus=1; slave=0; Z_FCS_n=0; READ=1; DOE=1; dma_aboel=1; dma_aboeh=1; #1;
        chk(BMASTER===1'b1,"master: BMASTER high");
        chk(Z2D_n===1'b0,  "DMA read: Zorro->data (Z2D_n=0)");
        chk(D2Z_n===1'b1,  "DMA read: D2Z off");
        chk(ABOEL_n===1'b0,"DMA: addr low buffer enabled (dma_aboel)");
        chk(ABOEH_n===1'b0,"DMA: addr high buffer enabled (dma_aboeh)");

        // ---------- MASTER (DMA) WRITE ----------
        READ=0; #1;
        chk(D2Z_n===1'b0,  "DMA write: data->Zorro (D2Z_n=0)");
        chk(Z2D_n===1'b1,  "DMA write: Z2D off");

        // ---------- DBLT latch ----------
        MASTER_n=1; mybus=0; slave=1; Z_FCS_n=0; READ=1; DOE=1; DTACK_n=0; #1;
        chk(DBLT===1'b1,   "DBLT latches when DOE & DTACK in data phase");
        Z_FCS_n=1; #1;
        chk(DBLT===1'b0,   "DBLT clears when Z_FCS_n deasserts");

        // ---------- SIZ / ADDRL decode (big-endian byte lanes) ----------
        // longword: all 4 DS active
        DS_n=4'b0000; #1; chk(siz===2'b00 && addrl===2'b00, "DS=0000 -> SIZ=00(long) ADDRL=00");
        // single byte on D[7:0] (lowest lane = offset 3 big-endian)
        DS_n=4'b1110; #1; chk(siz===2'b01 && addrl===2'b11, "DS=1110 -> SIZ=01(byte) ADDRL=11");
        // word on upper half
        DS_n=4'b0011; #1; chk(siz===2'b10 && addrl===2'b00, "DS=0011 -> SIZ=10(word) ADDRL=00");

        summary("tb_buffercontrol");
        $finish;
    end
endmodule
