// =============================================================
// IceBreaker SPRAM Animation: Write and Display Patterns
// -------------------------------------------------------------
// This design writes 16 unique patterns to SPRAM (addresses 0–15)
// and then continuously reads them back, one per second,
// displaying the lower 5 bits on LED1–LED5.
//
// Author: Vincent + ChatGPT
// =============================================================

module top (
    input  wire CLK,    // 12 MHz external clock
    output wire LED1,
    output wire LED2,
    output wire LED3,
    output wire LED4,
    output wire LED5
);

    // -----------------------------
    // SPRAM Control Signals
    // -----------------------------
    reg  [13:0] addr = 0;         // SPRAM address
    reg  [15:0] data_in = 0;      // SPRAM data to write
    wire [15:0] data_out;         // SPRAM data read
    reg         we = 0;           // Write enable
    reg  [3:0]  phase = 0;        // FSM phase: 0–15 for writes, then loop
    reg         writing = 1;      // Write phase flag

    // SPRAM power control (must set!)
    wire standby  = 1'b0;  // 0 = active
    wire sleep    = 1'b0;  // 0 = active
    wire poweroff = 1'b1;  // 1 = powered on (inverted logic)

    SB_SPRAM256KA sram (
        .ADDRESS(addr),
        .DATAIN(data_in),
        .MASKWREN(4'b1111),
        .WREN(we),
        .CHIPSELECT(1'b1),
        .CLOCK(CLK),
        .STANDBY(standby),
        .SLEEP(sleep),
        .POWEROFF(poweroff),
        .DATAOUT(data_out)
    );

    // -----------------------------
    // FSM: Write phase then read loop
    // -----------------------------

    reg [23:0] slow_counter = 0;   // For 1Hz delay (12M counts)
    always @(posedge CLK) begin
        slow_counter <= slow_counter + 1;

        if (slow_counter == 0) begin  // Every ~1 second
            if (writing) begin
                // Write a fixed pattern into each address 0–15
                addr     <= phase;
                data_in  <= {12'h000, phase};  // Bits [3:0] set
                we       <= 1'b1;
                phase    <= phase + 1;

                if (phase == 4'd15) begin
                    writing <= 0;  // Done writing
                    phase   <= 0;
                end
            end else begin
                // Read phase: disable write, read from address = phase
                we     <= 1'b0;
                addr   <= phase;
                phase  <= phase + 1;
            end
        end
    end

    // -----------------------------
    // Drive LEDs from data_out
    // -----------------------------
    assign LED1 = data_out[0];
    assign LED2 = data_out[1];
    assign LED3 = data_out[2];
    assign LED4 = data_out[3];
    assign LED5 = data_out[4];

endmodule
