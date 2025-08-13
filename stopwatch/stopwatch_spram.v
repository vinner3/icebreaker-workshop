// ==========================================================
// IceBreaker FPGA Example: Internal SPRAM Write + Readback
// ----------------------------------------------------------
// This design writes a fixed value (0xFFFF) into the FPGA's
// internal SRAM (SPRAM) and continuously reads it back.
//
// The lower 5 bits of the readback value are displayed on
// LED1 through LED5.
//
// Requires: VPP_2V5 tied to 3.3V (NVCM not needed)
// Author: Vincent + ChatGPT Debug Team
// ==========================================================

module top (
    input  wire CLK,      // External 12 MHz clock input (pin 35)
    output wire LED1,     // Output to LED1 (pin 26)
    output wire LED2,     // Output to LED2 (pin 23)
    output wire LED3,     // Output to LED3 (pin 21)
    output wire LED4,     // Output to LED4 (pin 20)
    output wire LED5      // Output to LED5 (pin 19)
);

    // ----------------------------
    // SPRAM Interface Wires
    // ----------------------------
    reg  [13:0] addr     = 14'h0010;    // Memory address to write/read
    reg  [15:0] data_in  = 16'hFFFF;    // Data to write (all ones)
    wire [15:0] data_out;               // Readback data from SPRAM
    reg         we       = 1'b0;        // Write enable
    reg         ce       = 1'b1;        // Chip select (always enabled)

    // ----------------------------
    // Write Pulse Generator
    // ----------------------------
    reg [4:0] write_cycles = 0;         // Counts 0 to 7
    always @(posedge CLK) begin
        if (write_cycles < 5'd8)
            write_cycles <= write_cycles + 1;
    end

    // Write-enable signal: only active for first 8 clock cycles
    always @(*) begin
        we = (write_cycles < 5'd8);
    end

    // ----------------------------
    // Instantiate SPRAM
    // ----------------------------
    SB_SPRAM256KA spram_inst (
        .ADDRESS(addr),           // 14-bit address
        .DATAIN(data_in),         // 16-bit data input
        .DATAOUT(data_out),       // 16-bit data output
        .MASKWREN(4'b1111),       // Enable all 4 bytes for writing
        .WREN(we),                // Write enable (pulsed)
        .CHIPSELECT(ce),          // Always select the SRAM
        .CLOCK(CLK),              // Clock input

        // ⚠️ Required control pins — MUST be set for SRAM to work!
        .STANDBY(1'b0),           // 0 = disable standby mode
        .SLEEP(1'b0),             // 0 = disable sleep mode
        .POWEROFF(1'b0)           // 0 = keep SRAM powered on
    );

    // ----------------------------
    // Use data_out to drive dummy logic
    // to avoid optimization removal
    // ----------------------------
    reg [15:0] dummy_counter = 0;
    always @(posedge CLK) begin
        dummy_counter <= dummy_counter + data_out;
    end

    // ----------------------------
    // Output lower 5 bits of data_out
    // to the 5 LEDs
    // ----------------------------
    assign LED1 = data_out[0];  // LSB
    assign LED2 = data_out[1];
    assign LED3 = data_out[2];
    assign LED4 = data_out[3];
    assign LED5 = data_out[4];  // MSB

endmodule
