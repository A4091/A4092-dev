`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    20:21:44 08/03/2025
// Design Name:
// Module Name:    spirom
// Project Name:
// Target Devices:
// Tool versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////
module spirom(
    input clk,
    input IORST_n,
    input romcycle,
    input [22:2] addr,
    input DOE,
    input [3:0] DS_n,
    input READ,
    input FC2,
    output reg dtack = 0,
    output reg spi_read = 0,
    output reg [7:0] spi_dataout = 0,
    input [7:0] spi_datain,
    output reg SPI_CLK = 0,
    output reg SPI_CS_n = 1,
    output reg SPI_MOSI = 0,
    input SPI_MISO
    );

    localparam  SPI_IDLE    =  2'b00,
                SPI_N       =  2'b01,
                SPI_P       =  2'b10,
                SPI_DTACK   =  2'b11;

    (* fsm_encoding = "user" *)reg [1:0] spi_state = SPI_IDLE;

    reg [7:0] shiftreg = 0;
    reg [5:0] cnt = 6'd40;
    reg close = 1'b1;

    reg romcycle_sync = 0;
    reg doe_sync = 0;
    reg DS_sync = 0;

    wire SPI_ROM;
    wire SPI_PORT_WRITE_HOLD;
    wire SPI_PORT_WRITE_END;
    wire SPI_PORT_READ_HOLD;
    wire SPI_PORT_READ_END;

    assign SPI_ROM = &addr[22:6] ? 0 : 1;                                         // $000000 -$7fffbf
    assign SPI_PORT_WRITE_HOLD = (!READ && ({addr[7:2],2'b00} == 8'hc0)) ? 1 : 0; // $7fffc0
    assign SPI_PORT_WRITE_END = (!READ && ({addr[7:2],2'b00} == 8'hd0)) ? 1 : 0;  // $7fffd0
    assign SPI_PORT_READ_HOLD = (READ && ({addr[7:2],2'b00} == 8'he0)) ? 1 : 0;   // $7fffe0
    assign SPI_PORT_READ_END = (READ && ({addr[7:2],2'b00} == 8'hf0)) ? 1 : 0;    // $7ffff0

    always @ (negedge IORST_n, negedge clk) begin
        if (!IORST_n) begin
            romcycle_sync <= 0;
            doe_sync <= 0;
            DS_sync <= 0;
        end else begin
            romcycle_sync <= romcycle;
            doe_sync <= DOE;
            DS_sync <= ~&DS_n;
        end
    end

    always @ (negedge IORST_n, posedge clk) begin
        if (!IORST_n) begin
            cnt <= 6'd40;
            spi_read <= 0;
            dtack <= 0;
            SPI_CLK <= 0;
            SPI_CS_n <= 1;
            SPI_MOSI <= 0;
            close <= 1;
            spi_dataout <= 0;
            spi_state <= SPI_IDLE;
        end else begin
            spi_read <= 0;
            dtack <= 0;
            SPI_CLK <= 0;
            case (spi_state)
            SPI_IDLE : begin
                spi_state <= SPI_IDLE;
                close <= 1;
                cnt <= 8;
                shiftreg <= spi_datain;
                if (romcycle_sync) begin
                    if (SPI_ROM) begin                      // $000000 - $7fffbf
                        SPI_CS_n <= 1'b1;
                        shiftreg <= 8'h03;
                        cnt <= 40;
                        if (READ) begin
                            spi_state <= SPI_N;             // READ -> Start SPI read command
                        end else begin
                            spi_state <= SPI_DTACK;         // WRITE -> immediately end ZIII Cycle
                        end
                    end else if (SPI_PORT_READ_END) begin   // $7ffff0
                        spi_state <= SPI_N;
                    end else if (SPI_PORT_READ_HOLD) begin  // $7fffe0
                        close <= 0;
                        spi_state <= SPI_N;
                    end else if (SPI_PORT_WRITE_END) begin  // $7fffd0
                        if (doe_sync && DS_sync) begin      // wait for DOE and DS before start SPI cycle
                            spi_state <= SPI_N;
                        end
                    end else if (SPI_PORT_WRITE_HOLD) begin // $7fffc0
                        if (doe_sync && DS_sync) begin      // wait for DOE and DS before start SPI cycle
                            close <= 0;
                            spi_state <= SPI_N;
                        end
                    end else begin
                        spi_state <= SPI_DTACK;             // all other -> immediately end ZIII Cycle
                    end
                end
            end

            SPI_N : begin
                SPI_CS_n <= 0;
                if (cnt == 0) begin
                    SPI_MOSI <= 0;
                    spi_dataout <= shiftreg;
                    spi_read <= READ;
                    spi_state <= SPI_DTACK;
                end else begin
                    SPI_MOSI <= shiftreg[7];
                    spi_state <= SPI_P;
                end
            end

            SPI_P : begin
                SPI_CLK <= 1;
                case (cnt)
                    33 :     shiftreg <= {3'b000, addr[22:18]};
                    25 :     shiftreg <= addr[17:10];
                    17 :     shiftreg <= addr[9:2];
                     9 :     shiftreg <= 0;
                    default: shiftreg <= {shiftreg[6:0], SPI_MISO};
                endcase
                cnt <= cnt - 1;
                spi_state <= SPI_N;
            end

            SPI_DTACK : begin
                SPI_CS_n <= close;
                if (!romcycle_sync) begin
                    spi_read <= 0;
                    dtack <= 0;
                    spi_state <= SPI_IDLE;
                end else begin
                    spi_read <= READ;
                    dtack <= 1;
                    spi_state <= SPI_DTACK;
                end
            end
            endcase
        end
     end

endmodule
