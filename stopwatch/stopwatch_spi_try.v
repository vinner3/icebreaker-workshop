module top (
    input  wire CLK,            // 12 MHz system clock

    // SPI from FTDI (via FLASH PMOD)
    input  wire FLASH_SCK,      // FTDI ADBUS0 → Pin 15
    input  wire FLASH_SSB,      // FTDI ADBUS4 → Pin 16 (active low)
    input  wire FLASH_IO0,      // FTDI ADBUS1 → Pin 14 (MOSI)
    output wire FLASH_IO1,      // FTDI ADBUS2 ← Pin 17 (MISO)

    // LEDs on PMOD2
    output wire LED1,           // Pin 26
    output wire LED2,           // Pin 27
    output wire LED3,           // Pin 25
    output wire LED4,           // Pin 23
    output wire LED5            // Pin 21
);

    reg [7:0] rx_shift = 8'b0;
    reg [7:0] tx_shift = 8'h00;
    reg [2:0] bit_cnt = 3'd7;

    reg sck_d = 0, sck_rising = 0, sck_falling = 0;

    // Edge detection for SPI clock
    always @(posedge CLK) begin
        sck_d <= FLASH_SCK;
        sck_rising  <= ~sck_d & FLASH_SCK;
        sck_falling <=  sck_d & ~FLASH_SCK;
    end

    always @(posedge CLK) begin
        if (FLASH_SSB) begin
            bit_cnt  <= 3'd7;
            tx_shift <= 8'h00;
        end else begin
            if (sck_rising) begin
                rx_shift[bit_cnt] <= FLASH_IO0;
            end
            if (sck_falling) begin
                bit_cnt <= bit_cnt - 1;
                if (bit_cnt == 0) begin
                    tx_shift <= rx_shift;   // ← ECHO the received byte
                    bit_cnt <= 3'd7;
                end
            end
        end
    end

    assign FLASH_IO1 = FLASH_SSB ? 1'bz : tx_shift[bit_cnt];

    // Show received bits on LEDs (first 5 bits)
    assign LED1 = rx_shift[0];
    assign LED2 = rx_shift[1];
    assign LED3 = rx_shift[2];
    assign LED4 = rx_shift[3];
    assign LED5 = rx_shift[4];

endmodule
