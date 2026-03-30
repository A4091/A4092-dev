/**********************************************************************************
 *
 * Parallel flash ROM support
 *
 **********************************************************************************/
module parallelrom (
    input clk,
    input IORST_n,
    input romcycle,
    input DOE,
    input [3:0] DS_n,
    input READ,
    input FC2,
    output reg dtack = 0,
    output reg ROM_CE_n = 1,
    output reg ROM_OE_n = 1,
    output reg ROM_WE_n = 1
);

    // ############################################################################
    localparam waitstates = 4;      // 4x20ns = 80ns...
    // ############################################################################

    reg [2:0] delay = waitstates;
    reg romcycle_sync = 0;
    reg doe_sync = 0;
    reg DS_sync = 0;

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

    always @(negedge IORST_n, posedge clk) begin
        if (!IORST_n) begin
            ROM_CE_n <= 1;
            ROM_OE_n <= 1;
            ROM_WE_n <= 1;
            delay <= waitstates;
            dtack <= 0;
        end else begin
            ROM_CE_n <= 1;
            ROM_OE_n <= 1;
            ROM_WE_n <= 1;
            delay <= waitstates;
            dtack <= 0;

            if (romcycle_sync) begin
                ROM_CE_n <= 0;

                if (delay > 0) begin
                    delay <= delay - 1;
                end else begin
                    dtack <= 1;
                end

                if (READ) begin
                    ROM_OE_n <= 0;
                end else if (doe_sync && DS_sync) begin
                // For supervisor-only write control, you would use this line instead:
                // end else if (doe_sync && DS_sync && FC2) begin
                    ROM_WE_n <= 0;
                end else begin
                    delay <= waitstates;
                end
            end
        end
   end

endmodule
