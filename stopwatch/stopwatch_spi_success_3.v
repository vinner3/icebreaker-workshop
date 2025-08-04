module top (
    input  wire CLK,            // 12 MHz clock

    // SPI signals from FTDI (Flash PMOD)
    input  wire FLASH_SCK,      // ADBUS0
    input  wire FLASH_SSB,      // ADBUS4 (CS#)
    input  wire FLASH_IO0,      // ADBUS1 (MOSI)
    output wire FLASH_IO1,      // ADBUS2 (MISO)

    // 5 LEDs (active-low)
    output wire LED1,
    output wire LED2,
    output wire LED3,
    output wire LED4,
    output wire LED5
);

    // Sync SCK and CS# to CLK domain
    reg sck_q = 0, sck_qq = 0;
    reg cs_q  = 1, cs_qq  = 1;

    always @(posedge CLK) begin
        sck_q  <= FLASH_SCK;
        sck_qq <= sck_q;

        cs_q   <= FLASH_SSB;
        cs_qq  <= cs_q;
    end

    wire sck_rise = ( sck_q & ~sck_qq);
    wire sck_fall = (~sck_q &  sck_qq);
    wire cs_rise  = ( cs_q  & ~cs_qq);
    wire cs_fall  = (~cs_q  &  cs_qq);

    reg [7:0] rx_shift = 8'h00;
    reg [7:0] tx_shift = 8'hFF;
    reg [2:0] bit_cnt  = 3'd7;

    // Tri-state MISO when CS# is high
    reg miso_out = 1'b1;
    assign FLASH_IO1 = (cs_q) ? 1'bz : miso_out;

    always @(posedge CLK) begin
        if (cs_fall) begin
            bit_cnt <= 3'd7;
        end

        if (!cs_q && sck_rise) begin
            rx_shift[bit_cnt] <= FLASH_IO0;
            if (bit_cnt != 0)
                bit_cnt <= bit_cnt - 1;
        end

        if (!cs_q && sck_fall) begin
            miso_out <= tx_shift[bit_cnt];
        end

        if (cs_rise) begin
            tx_shift <= rx_shift;  // echo *next* time
        end
    end

    // LED latch
    reg [7:0] led_reg = 8'h00;
    always @(posedge CLK) begin
        if (cs_rise) begin
            led_reg <= rx_shift;
        end
    end

    assign LED1 = ~led_reg[0];
    assign LED2 = ~led_reg[1];
    assign LED3 = ~led_reg[2];
    assign LED4 = ~led_reg[3];
    assign LED5 = ~led_reg[4];

endmodule
