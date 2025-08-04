// Diagnostic: prove bitstream is running (heartbeat) and show FTDI CS# on LED.
// - LEDG_N blinks at ~2 Hz from the 12 MHz clock
// - LEDR_N mirrors FLASH_SSB (CS#): LED ON when CS# is LOW

module top (
    input  wire CLK,          // 12 MHz (pin 35) -- used for heartbeat
    input  wire FLASH_SCK,    // not used here
    input  wire FLASH_SSB,    // CS# from FTDI (active-low)
    input  wire FLASH_IO0,    // not used (MOSI)
    inout  wire FLASH_IO1,    // leave Hi-Z (MISO)
    output wire FLASH_IO2,    // WP# high: release flash
    output wire FLASH_IO3,    // HOLD# high: release flash
    output wire LEDR_N,       // red LED (active-low): CS# mirror
    output reg  LEDG_N        // green LED (active-low): heartbeat
);
    // Leave flash fully enabled so we can talk to it
    assign FLASH_IO2 = 1'b1;  // WP# inactive
    assign FLASH_IO3 = 1'b1;  // HOLD# released
    assign FLASH_IO1 = 1'bz;  // never drive MISO in this test

    // Mirror CS# on the red LED (active-low LED): CS low -> LED ON
    assign LEDR_N = FLASH_SSB;

    // Heartbeat on the green LED ~2 Hz
    reg [23:0] hb = 24'd0;
    always @(posedge CLK) begin
        hb <= hb + 1'd1;               // 12 MHz / 2^23 ≈ 1.4 Hz toggle
        LEDG_N <= hb[22];              // active-low LED: toggles visibly
    end
endmodule
