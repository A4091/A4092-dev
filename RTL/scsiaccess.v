/**********************************************************************************
 *
 * SCSI register access
 *
 **********************************************************************************/
module scsiaccess (
    input bclk,
    input DOE,
    input [3:0] DS_n,
    input READ,
    input scsi_cycle,
    input mybus,
    output reg SCSI_SREG_n = 1,
    output reg scsi_as_sig = 0,
    output reg scsi_ds_sig = 0,
    input SLACK_n,
    output reg dtack = 0
);

    localparam STATE_IDLE  = 2'b00,
               STATE_AS    = 2'b01,
               STATE_CS    = 2'b11;

    (* fsm_encoding = "User" *)reg [1:0] scsi_state = STATE_IDLE, scsi_state_next = STATE_IDLE;

    // state register
    always @ (negedge scsi_cycle, negedge bclk) begin
        if (!scsi_cycle) begin
            scsi_state <= STATE_IDLE;
        end else begin
            scsi_state <= scsi_state_next;
        end
    end

    // input signal processing
    always @(*) begin
        if (!scsi_cycle || mybus) begin
            scsi_state_next = STATE_IDLE;
        end else begin
            scsi_state_next = scsi_state;
            case (scsi_state)
                STATE_IDLE : begin
                    if (DOE && ~&DS_n) begin
                        scsi_state_next = STATE_AS;
                    end
                end
                STATE_AS : begin
                    // set as and at read also ds
                    scsi_state_next = STATE_CS;
                end
                STATE_CS : begin
                    // set as, ds, cs and stay here until cycle end
                end
                default: begin
                    scsi_state_next = STATE_IDLE;
                end
            endcase
        end
    end

    // Async output signal to ZIII
    always @(*) begin
        if (!scsi_cycle) begin
            dtack = 0;
        end else begin
            if (!SLACK_n) begin
                dtack = 1;
            end else begin
                dtack = 0;
            end
        end
    end

    // Sync output signal to NCR
    always @(negedge scsi_cycle, negedge bclk) begin
        if (!scsi_cycle) begin
            SCSI_SREG_n <= 1;
        end else begin
            SCSI_SREG_n <= 1;
            if ((scsi_state_next == STATE_CS) || (mybus && scsi_cycle)) begin
                SCSI_SREG_n <= 0;
            end
        end
    end

    always @(negedge scsi_cycle, negedge bclk) begin
        if (!scsi_cycle) begin
            scsi_as_sig <= 0;
        end else begin
            case (scsi_state_next)
            STATE_AS,
            STATE_CS: begin
                scsi_as_sig <= 1;
            end
            default: scsi_as_sig <= 0;
            endcase
        end
    end

    always @(negedge scsi_cycle, negedge bclk) begin
        if (!scsi_cycle) begin
            scsi_ds_sig <= 0;
        end else begin
            case (scsi_state_next)
            STATE_AS: begin
                scsi_ds_sig <= READ;				// at write DS is 1 clk delayed like 68030
            end
            STATE_CS: begin
                scsi_ds_sig <= 1;
            end
            default: scsi_ds_sig <= 0;
            endcase
        end
    end

endmodule
