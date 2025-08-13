// Top-level design to write known value into SPRAM and read it back
// Displays lower 5 bits of SPRAM output on LED1–LED5

module top (
    input  wire CLK,    // External 12 MHz clock
    output wire LED1,
    output wire LED2,
    output wire LED3,
    output wire LED4,
    output wire LED5
);

    // ----------------------
    // SPRAM Interface
    // ----------------------
    wire [15:0] data_out;
    reg  [15:0] data_in = 16'hBEEF;   // Data to write
    reg  [13:0] addr = 14'd0;         // Only address 0
    reg         we = 1'b1;            // Write enable
    reg         clk_en = 1'b1;

    // Required power control pins
    wire standby = 1'b0;   // 0 = not in standby → active
    wire sleep   = 1'b0;   // 0 = not in sleep → active
    wire poweroff = 1'b1;  // 1 = power is ON (inverted logic)

    // SPRAM instance
    SB_SPRAM256KA sram_inst (
        .ADDRESS(addr),
        .DATAIN(data_in),
        .MASKWREN(4'b1111),   // Write to all byte lanes
        .WREN(we),            // Write enable
        .CHIPSELECT(1'b1),
        .CLOCK(CLK),
        .STANDBY(standby),
        .SLEEP(sleep),
        .POWEROFF(poweroff),
        .DATAOUT(data_out)
    );

    // ----------------------
    // Read-after-write test
    // ----------------------

    // Create a register to hold SPRAM output
    reg [15:0] temp = 0;

    // After write is done (after first cycle), disable write
    reg write_done = 0;
    always @(posedge CLK) begin
        if (!write_done) begin
            we <= 1'b1;       // Write only in first cycle
            write_done <= 1'b1;
        end else begin
            we <= 1'b0;       // Then switch to read mode
        end
        temp <= data_out;     // Keep reading from SPRAM
    end

    // Drive LEDs from bits [4:0] of read data
    assign LED1 = temp[0];
    assign LED2 = temp[1];
    assign LED3 = temp[2];
    assign LED4 = temp[3];
    assign LED5 = temp[4];

endmodule
