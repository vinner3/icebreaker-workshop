module top (
    input  wire CLK,            // 12 MHz system clock

    // SPI from FTDI (via FLASH PMOD)
    input  wire FLASH_SCK,      // FTDI ADBUS0 → Pin 15 (SPI SCK)
    input  wire FLASH_SSB,      // FTDI ADBUS4 → Pin 16 (CS#, active low)
    input  wire FLASH_IO0,      // FTDI ADBUS1 → Pin 14 (MOSI)
    output wire FLASH_IO1,      // FTDI ADBUS2 ← Pin 17 (MISO)

    // LEDs on PMOD2 (active-low)
    output wire LED1,           // Pin 26
    output wire LED2,           // Pin 27
    output wire LED3,           // Pin 25
    output wire LED4,           // Pin 23
    output wire LED5            // Pin 21
);

    // ===============================================================
    // Synchronize SCK and CS# into CLK domain and detect edges
    // ===============================================================
    reg sck_q  = 1'b0, sck_qq  = 1'b0;
    reg cs_q   = 1'b1, cs_qq   = 1'b1;

    always @(posedge CLK) begin
        sck_q  <= FLASH_SCK;
        sck_qq <= sck_q;

        cs_q   <= FLASH_SSB;
        cs_qq  <= cs_q;
    end

    wire sck_rise = ( sck_q & ~sck_qq);   // SCK rising edge
    wire sck_fall = (~sck_q &  sck_qq);   // SCK falling edge
    wire cs_fall  = (~cs_q  &  cs_qq);    // CS# goes low (start)
    wire cs_rise  = ( cs_q  & ~cs_qq);    // CS# goes high (end)

    // ===============================================================
    // Simple SPI slave: sample MOSI on SCK rising while CS# is low
    // Bit counter runs 7→0 (MSB-first), like standard SPI flashes
    // ===============================================================
    reg [7:0] rx_shift = 8'h00;
    reg [7:0] tx_shift = 8'h00;      // value to echo on next transaction
    reg [2:0] bit_cnt  = 3'd7;

    // MISO output register (updated on SCK falling; tri-stated when CS# high)
    reg miso_out = 1'b0;
    assign FLASH_IO1 = (cs_q) ? 1'bz : miso_out;

    always @(posedge CLK) begin
        // Start of a transaction: reset bit counter
        if (cs_fall) begin
            bit_cnt <= 3'd7;
        end

        // While CS# is low, on each SCK rising edge, capture MOSI into rx_shift[bit_cnt]
        if (!cs_q && sck_rise) begin
            rx_shift[bit_cnt] <= FLASH_IO0;
            if (bit_cnt != 3'd0) begin
                bit_cnt <= bit_cnt - 3'd1;
            end
        end

        // While CS# is low, on each SCK falling edge, drive the current bit of tx_shift
        // This provides a clean, stable MISO bit between the falling and next rising edge
        if (!cs_q && sck_fall) begin
            miso_out <= tx_shift[bit_cnt];
        end

        // End of transaction: latch received byte to LEDs and prepare echo for next xfer
        if (cs_rise) begin
            // At CS# rising edge, a well-formed master has delivered all 8 SCK pulses.
            // rx_shift now holds the full byte. Latch it for LEDs and echo next time.
            tx_shift <= rx_shift;   // echo on NEXT transaction
        end
    end

    // ===============================================================
    // LED register: latch the received byte on CS# rising (transaction end)
    // ===============================================================
    reg [7:0] led_reg = 8'h00;
    always @(posedge CLK) begin
        if (cs_rise) begin
            led_reg <= rx_shift;
        end
    end

    // ===============================================================
    // Active-low LEDs: invert for human-friendly visualization
    // Show bits [4:0] of the received byte
    // ===============================================================
    assign LED1 = ~led_reg[0];
    assign LED2 = ~led_reg[1];
    assign LED3 = ~led_reg[2];
    assign LED4 = ~led_reg[3];
    assign LED5 = ~led_reg[4];

endmodule
