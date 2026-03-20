/**********************************************************************************
 *
 * Zorro III autoconfig
 *
 **********************************************************************************/
module autoconfig (
    input clk,
    input Z_FCS_n,
    input DOE,
    input DS3_n,
    input [1:0] FC,
    input READ,
    input [31:24] DIN,
    output reg [3:0] data_out = 4'hF,
    input [31:24] addrh,
    input [8:2] addrl,
    input IORST_n,
    input BERR_n,
    input SENSEZ3,
    input CFGIN_n,
    output reg cfgout = 0,
    output reg config_cycle = 0,
    output reg dtack = 0,
    output reg card_cycle = 0,
    input [15:0] mfg_id,
    input [7:0] prod_id,
    input [31:0] serial,
    input [15:0] romvec
);

    reg configured_sig = 0;
    reg shutup_sig = 0;
    reg [31:24] card_addr = 8'hFF;
    wire [7:0] addr_sig;
    wire cycle_end;

    assign addr_sig = {addrl[7:2], addrl[8], 1'b0};
    assign cycle_end = (Z_FCS_n || !IORST_n || !BERR_n || FC[1] == FC[0] || CFGIN_n || !SENSEZ3);

    // set card or config Cycle signal at addressmatch, hold until cycle ends
    always @(posedge cycle_end, posedge clk) begin
        if (cycle_end) begin
            card_cycle <= 0;
            config_cycle <= 0;
        end else begin
            if (configured_sig && addrh == card_addr) begin
                card_cycle <= 1;
            end else if (!configured_sig && !shutup_sig && addrh == 8'hFF) begin
                config_cycle <= 1;
            end
        end
    end

    // Configure or Shutup Card
    always @(negedge IORST_n, posedge clk) begin
        if (!IORST_n) begin
            configured_sig <= 0;
            shutup_sig <= 0;
            card_addr <= 8'hFF;
            dtack <= 0;
        end else begin
            dtack <= 0;
            if (config_cycle && DOE && !DS3_n) begin
                dtack <= 1;
                if (!READ) begin
                    card_addr <= DIN;
                    configured_sig <= addr_sig == 8'h44;
                    shutup_sig <= addr_sig == 8'h4C;
                end
            end
        end
    end

    // autoconfig "ROM", data_out gated in top Module
    always @(*) begin
        case (addr_sig)
            8'h00: data_out = (romvec > 0) ? 4'b1001 : 4'b1000;
            8'h02: data_out = 4'b0000;
            8'h04: data_out = ~prod_id[7:4];
            8'h06: data_out = ~prod_id[3:0];
            8'h08: data_out = ~4'b0011;
            8'h0A: data_out = ~4'b0000;
            8'h10: data_out = ~mfg_id[15:12];
            8'h12: data_out = ~mfg_id[11:8];
            8'h14: data_out = ~mfg_id[7:4];
            8'h16: data_out = ~mfg_id[3:0];
            8'h18: data_out = ~serial[31:28];
            8'h1A: data_out = ~serial[27:24];
            8'h1C: data_out = ~serial[23:20];
            8'h1E: data_out = ~serial[19:16];
            8'h20: data_out = ~serial[15:12];
            8'h22: data_out = ~serial[11:8];
            8'h24: data_out = ~serial[7:4];
            8'h26: data_out = ~serial[3:0];
            8'h28: data_out = ~romvec[15:12];
            8'h2A: data_out = ~romvec[11:8];
            8'h2C: data_out = ~romvec[7:4];
            8'h2E: data_out = ~romvec[3:0];
            default: data_out = 4'hF;
        endcase
    end

    // Latch cfgout at rising edge of Z_FCS_n
    always @(posedge Z_FCS_n, negedge IORST_n) begin
        if (!IORST_n) begin
            cfgout = 0;
        end else begin
            cfgout = configured_sig || shutup_sig;
        end
    end

endmodule
