/**********************************************************************************
 *
 * buffer control
 *
 **********************************************************************************/
module buffercontrol (
    input MASTER_n,
    input Z_FCS_n,
    input mybus,
    input slave,
    input READ,
    input DOE,
    input DTACK_n,
    input dma_aboel,
    input dma_aboeh,
    input [3:0] DS_n,
    output BMASTER,
    output DBOE_n,
    output D2Z_n,
    output Z2D_n,
    output reg DBLT = 0,
    output FCS,
    output ABOEL_n,
    output ABOEH_n,
    output [1:0] addrl,
    output [1:0] siz
);

    wire slavecycle;
    wire mastercycle;

    // FCS is Latch Enable of U1 and U4
    assign FCS = !Z_FCS_n;

    // BMASTER is simply a inverted MASTER_n
    // MASTER_n and BMASTER used for direction control of Addressbuffer
    assign BMASTER = !MASTER_n;

    // Slavecycle when Card is not Zorro Master and no DMA from NCR pending
    assign slavecycle = !mybus && MASTER_n;
    // Mastercycle when Card is Zorro Master and DMA active
    assign mastercycle = mybus && !MASTER_n;

    // The address buffer controls.  I want addresses going in unless the SCSI
    // device has been granted the A4091 bus.  If so, addresses only go out when
    // the A4091 has been granted the Zorro III bus.  High order addresses also
    // go off quickly after FCS is asserted.
    assign ABOEL_n = !(slavecycle || (mastercycle && dma_aboel));
    assign ABOEH_n = !(slavecycle || (mastercycle && dma_aboeh));

    // This is the data output enable control.  When data buffers are
    // pointed toward the board, they can turn on early in the cycle.
    // This is a write for slave access, a read for DMA access.  When
    // the data buffers are pointed out toward the bus, the have to
    // wait until DOE to turn on; this is a slave read or DMA write.
    // When the board responds to itself, the buffers are left off.
    assign DBOE_n = !(( slavecycle &&  slave && !Z_FCS_n && !READ) ||
                      ( slavecycle &&  slave && !Z_FCS_n &&  READ && DOE) ||
                      (mastercycle && !slave && !Z_FCS_n &&  READ) ||
                      (mastercycle && !slave && !Z_FCS_n && !READ && DOE));

    // The data buffer direction calculations are very simple.  The data to
    // Zorro III connection is made for slave reads or DMA writes.  The Zorro III
    // to data bus connection is made for slave writes or DMA reads.
    assign D2Z_n = !(( slavecycle &&  slave && !Z_FCS_n &&  READ) ||
                     (mastercycle && !slave && !Z_FCS_n && !READ));
    assign Z2D_n = !(( slavecycle &&  slave && !Z_FCS_n && !READ) ||
                     (mastercycle && !slave && !Z_FCS_n &&  READ));

    // For either kind of access, data is latched when DTACK_n is asserted and
    // we're in data time.  Data is held through the end of the cycle.
    always @(*) begin
        if (Z_FCS_n) begin
            DBLT = 0;
        end else if (((slavecycle && slave) || (mastercycle && !slave)) && DOE && !DTACK_n) begin
            DBLT = 1;
        end
    end

    // A1,A0 and SIZ based on ds_n from Zorro
    assign siz[1] = (DS_n == 4'b1100 || DS_n == 4'b1001 || DS_n == 4'b1000 || DS_n == 4'b0011 || DS_n == 4'b0001);
    assign siz[0] = (DS_n == 4'b1110 || DS_n == 4'b1101 || DS_n == 4'b1011 || DS_n == 4'b1000 || DS_n == 4'b0111 || DS_n == 4'b0001);
    assign addrl[1] = (DS_n == 4'b1110 || DS_n == 4'b1101 || DS_n == 4'b1100);
    assign addrl[0] = (DS_n == 4'b1110 || DS_n == 4'b1011 || DS_n == 4'b1001 || DS_n == 4'b1000);

endmodule
