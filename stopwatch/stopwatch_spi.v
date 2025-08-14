// -----------------------------------------------------------------------------
// Soft SPI Slave with Echo + LED Display for FTDI Master
// -----------------------------------------------------------------------------
// Receives 8-bit SPI data from FTDI (MOSI) via dedicated PMOD,
// echoes it back on next transfer (MISO), and displays lower 5 bits on LEDs.
// -----------------------------------------------------------------------------

module top (
    input  wire CLK,            // 12 MHz system clock from FPGA

    // SPI interface from FTDI (master) connected via FLASH PMOD
    input  wire FLASH_SCK,      // SPI Clock (ADBUS0 → Pin 15)
    input  wire FLASH_SSB,      // SPI Chip Select, active-low (ADBUS4 → Pin 16)
    input  wire FLASH_IO0,      // MOSI: Master Out Slave In (ADBUS1 → Pin 14)
    output wire FLASH_IO1,      // MISO: Master In Slave Out (ADBUS2 ← Pin 17)

    // Output to LEDs on PMOD2, active-low (0 = ON, 1 = OFF)
    output wire LED1,           // Pin 26
    output wire LED2,           // Pin 27
    output wire LED3,           // Pin 25
    output wire LED4,           // Pin 23
    output wire LED5            // Pin 21
);

    // =========================================================================
    // Synchronize SPI signals to internal clock domain (12 MHz CLK)
    // =========================================================================
    reg sck_q  = 1'b0, sck_qq  = 1'b0;  // SPI clock synchronizer
    reg cs_q   = 1'b1, cs_qq   = 1'b1;  // CS# synchronizer (start high, inactive)

    always @(posedge CLK) begin
        sck_q  <= FLASH_SCK;  // First stage
        sck_qq <= sck_q;      // Second stage for edge detection

        cs_q   <= FLASH_SSB;
        cs_qq  <= cs_q;
    end

    // Edge detection (in CLK domain)
    wire sck_rise = ( sck_q & ~sck_qq);  // Rising edge of SCK
    wire sck_fall = (~sck_q &  sck_qq);  // Falling edge of SCK
    wire cs_fall  = (~cs_q  &  cs_qq);   // CS# goes low (start of transaction)
    wire cs_rise  = ( cs_q  & ~cs_qq);   // CS# goes high (end of transaction)

    // =========================================================================
    // SPI Shift Register Logic
    // =========================================================================
    reg [7:0] rx_shift = 8'h00;         // Shift register for incoming data
    reg [7:0] tx_shift = 8'h00;         // Latches received byte for future echo
    reg [7:0] tx_shift_next = 8'h00;    // Currently transmitting this byte
    reg [2:0] bit_cnt = 3'd7;           // Bit counter for SPI (MSB first)

    reg miso_out = 1'b0;                // Output value to drive on MISO

    // Tristate MISO when CS# is high (inactive); drive MISO only when selected
    assign FLASH_IO1 = cs_q ? 1'bz : miso_out;

    always @(posedge CLK) begin
        // --- Start of SPI transaction ---
        if (cs_fall) begin
            bit_cnt <= 3'd7;              // Reset bit counter
            tx_shift_next <= tx_shift;    // Load byte to transmit
        end

        // --- Capture incoming MOSI on rising edge of SCK ---
        if (!cs_q && sck_rise) begin
            rx_shift[bit_cnt] <= FLASH_IO0;  // Sample 1 bit
            if (bit_cnt != 3'd0)
                bit_cnt <= bit_cnt - 3'd1;   // Decrement bit index
        end

        // --- Shift out MISO bit on falling edge of SCK ---
        if (!cs_q && sck_fall) begin
            miso_out <= tx_shift_next[bit_cnt];  // Drive corresponding bit
        end

        // --- End of SPI transaction ---
        if (cs_rise) begin
            tx_shift <= rx_shift;             // Store received byte
            tx_shift_next <= rx_shift;        // Prepare to echo it next time
        end
    end

    // =========================================================================
    // LED Display Logic (shows bits [4:0] of received byte)
    // =========================================================================
    reg [7:0] led_reg = 8'h00;

    always @(posedge CLK) begin
        if (cs_rise) begin
            led_reg <= rx_shift;  // Latch received byte when CS# goes high
        end
    end

    // Drive LEDs based on latched value; active-low
    assign LED1 = ~led_reg[0];
    assign LED2 = ~led_reg[1];
    assign LED3 = ~led_reg[2];
    assign LED4 = ~led_reg[3];
    assign LED5 = ~led_reg[4];

endmodule
