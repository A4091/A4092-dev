`timescale 1ns/1ps
// Testbench: verify spirom.v reconstructs parallel-ROM bytes from an SPI flash.
// Models a W25X-style flash (0x03 READ, mode 0): sample MOSI on rising SCLK,
// shift MISO out on falling SCLK after the 8-bit cmd + 24-bit address.
module tb_spirom;
    reg clk=0, IORST_n=0, romcycle=0, DOE=0, READ=1, FC2=0;
    reg [22:2] addr=0;
    reg [3:0] DS_n=4'b1111;
    wire dtack, spi_read;
    wire [7:0] spi_dataout;
    wire SPI_CLK, SPI_CS_n, SPI_MOSI;
    reg  SPI_MISO=0;
    reg [7:0] spi_datain=0;

    integer errors=0;

    spirom dut(.clk(clk), .IORST_n(IORST_n), .romcycle(romcycle), .addr(addr),
        .DOE(DOE), .DS_n(DS_n), .READ(READ), .FC2(FC2),
        .dtack(dtack), .spi_read(spi_read), .spi_dataout(spi_dataout),
        .spi_datain(spi_datain), .SPI_CLK(SPI_CLK), .SPI_CS_n(SPI_CS_n),
        .SPI_MOSI(SPI_MOSI), .SPI_MISO(SPI_MISO));

    always #10 clk = ~clk;   // 50 MHz

    // ---------------- SPI flash model ----------------
    reg [7:0] flash [0:65535];
    reg [39:0] rx;
    integer nbits;
    reg [7:0] dbyte;
    reg loaded;
    integer k;
    initial for (k=0;k<65536;k=k+1) flash[k] = (k[7:0] ^ 8'hA5);

    always @(negedge SPI_CS_n) begin nbits=0; loaded=0; end
    always @(posedge SPI_CLK) if(!SPI_CS_n) begin rx={rx[38:0],SPI_MOSI}; nbits=nbits+1; end
    always @(negedge SPI_CLK) if(!SPI_CS_n && nbits>=32) begin
        if(!loaded) begin dbyte=flash[rx[15:0]]; loaded=1; end
        SPI_MISO <= dbyte[7];
        dbyte={dbyte[6:0],1'b0};
    end

    // ---------------- one ROM read ----------------
    task rom_read(input [20:0] a);
        reg [7:0] expb;
        integer to;
        begin
            expb = (a[5:0] ^ 8'hA5) ^ 8'h00; // byteaddr low 8 bits = a[7:0]
            expb = (a[7:0] ^ 8'hA5);
            @(negedge clk); addr=a; READ=1; DOE=1; DS_n=4'b0000; romcycle=1;
            to=0;
            while (dtack!==1'b1 && to<400) begin @(posedge clk); to=to+1; end
            if (dtack!==1'b1) begin
                $display("  addr[22:2]=%05h  TIMEOUT (no dtack)", a); errors=errors+1;
            end else begin
                if (spi_dataout===expb)
                    $display("  addr[22:2]=%05h  byteaddr=%06h  got=%02h  exp=%02h  OK   (D31:28=%h D15:12=%h)",
                             a, {3'b000,a}, spi_dataout, expb, spi_dataout[7:4], spi_dataout[3:0]);
                else begin
                    $display("  addr[22:2]=%05h  byteaddr=%06h  got=%02h  exp=%02h  ** MISMATCH **",
                             a, {3'b000,a}, spi_dataout, expb); errors=errors+1;
                end
            end
            romcycle=0; addr=0; DS_n=4'b1111; DOE=0;
            @(negedge clk); while (dtack!==1'b0) @(posedge clk);
            repeat(3) @(posedge clk);
        end
    endtask

    initial begin
        repeat(4) @(posedge clk);
        IORST_n=1;
        repeat(4) @(posedge clk);
        $display("=== spirom SPI->parallel ROM read test ===");
        rom_read(21'h00000);
        rom_read(21'h00012);
        rom_read(21'h00100);
        rom_read(21'h001ff);
        rom_read(21'h00055);
        rom_read(21'h000aa);
        if (errors==0) $display("RESULT: PASS (all reads correct)");
        else           $display("RESULT: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin #200000; $display("GLOBAL TIMEOUT"); $finish; end
endmodule
