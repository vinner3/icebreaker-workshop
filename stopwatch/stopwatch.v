module top (
    input  wire CLK,            // 12 MHz system clock

    // SPI from FTDI (via FLASH PMOD)
    input  wire FLASH_SCK,      // ADBUS0 → Pin 15
    input  wire FLASH_SSB,      // ADBUS4 → Pin 16 (CS#, active low)
    input  wire FLASH_IO0,      // ADBUS1 → Pin 14 (MOSI)
    output wire FLASH_IO1,      // ADBUS2 ← Pin 17 (MISO)

    // LEDs on PMOD2
    output wire LED1,           // Pin 26
    output wire LED2,           // Pin 27
    output wire LED3,           // Pin 25
    output wire LED4,           // Pin 23
    output wire LED5            // Pin 21
);

	reg [23:0] counter = 0;
	reg toggled_miso = 0;

	always @(posedge CLK) begin
		counter <= counter + 1;
		if (counter == 12_000_000) begin  // ~1 second
			toggled_miso <= ~toggled_miso;
			counter <= 0;
		end
	end

    // ===============================
    // Synchronize SCK and SSB to CLK
    // ===============================
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

    // ===============================
    // SPI Shift Logic
    // ===============================
    reg [7:0] rx_shift = 8'h00;
    reg [7:0] tx_shift = 8'h00;
    reg [7:0] tx_shift_next = 8'h00;
    reg [7:0] tx_shift_dly  = 8'h00;  // for MISO timing
    reg [2:0] bit_cnt = 3'd7;

    reg miso_out = 1'b0;
    //assign FLASH_IO1 = cs_q ? 1'bz : miso_out;
	//assign FLASH_IO1 = 1'b1;  // FTDI should always read 0xFF
	assign FLASH_IO1 = toggled_miso;



    always @(posedge CLK) begin
        if (cs_fall) begin
            bit_cnt <= 3'd7;
            tx_shift_dly <= tx_shift_next;
        end

        if (!cs_q && sck_rise) begin
            rx_shift[bit_cnt] <= FLASH_IO0;
            if (bit_cnt != 0)
                bit_cnt <= bit_cnt - 1;
        end

        if (!cs_q && sck_fall) begin
            miso_out <= tx_shift_dly[bit_cnt];
        end

        if (cs_rise) begin
            tx_shift     <= rx_shift;
            tx_shift_next <= rx_shift;
        end
    end

    // ===============================
    // LED display logic
    // ===============================
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
