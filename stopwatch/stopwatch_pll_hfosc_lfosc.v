// -----------------------------------------------------------------------------
// FPGA LED Blink Demo Using 3 Different Clock Sources
//
// - LED1 blinks using an external 12 MHz clock (via PLL)
// - LED2 blinks using the internal high-frequency oscillator (HFOSC)
// - LED3 blinks using the internal low-frequency oscillator (LFOSC)
//
// This example demonstrates how to use multiple independent clock domains
// in the same design, safely driving separate logic (no clock crossing).
//
// Target FPGA: Lattice iCE40 UP5K (e.g., IceBreaker board)
// -----------------------------------------------------------------------------

module top (
    input  wire CLK,   // External 12 MHz clock input (pin 35)
    output wire LED1,  // Output to LED1 (driven by external PLL clock)
    output wire LED2,  // Output to LED2 (driven by HFOSC)
    output wire LED3   // Output to LED3 (driven by LFOSC)
);

    // =========================================================================
    // SECTION 1: PLL driven by external 12 MHz clock input (pin 35)
    // =========================================================================

    wire clk_pll;  // Output clock from the PLL

    // PLL parameter values:
    // - DIVR = 0: divide input by (0 + 1) = 1
    // - DIVF = 88: multiply by (88 + 1) = 89
    // - DIVQ = 4: divide VCO by 2^4 = 16
    // Resulting PLL output frequency:
    //   F_PLL = 12 MHz × 89 / 16 ≈ 66.75 MHz
    // This value is chosen so that bit 25 of a counter will toggle at ~1 Hz.
    localparam integer DIVR_VAL = 0;
    localparam integer DIVF_VAL = 88;
    localparam integer DIVQ_VAL = 4;

    // Instantiate PLL using SB_PLL40_PAD:
    // - PACKAGEPIN: connects directly to external clock input (pin 35)
    // - PLLOUTCORE: PLL output clock to internal logic
    // - RESETB: active-low reset, tied high to keep enabled
    // - BYPASS: bypass the PLL (set to 0 to enable PLL operation)
    SB_PLL40_PAD #(
        .FEEDBACK_PATH("SIMPLE"),            // Simple feedback loop
        .PLLOUT_SELECT("GENCLK"),            // Use general-purpose PLL output
        .DIVR(DIVR_VAL[3:0]),                // Input divider (4 bits)
        .DIVF(DIVF_VAL[6:0]),                // Feedback multiplier (7 bits)
        .DIVQ(DIVQ_VAL[2:0]),                // Output divider (3 bits)
        .FILTER_RANGE(3'b001)                // PLL filter tuning (based on F_in)
    ) pll_inst (
        .PACKAGEPIN(CLK),                    // External clock input (pin 35)
        .PLLOUTCORE(clk_pll),                // Output clock to drive logic
        .RESETB(1'b1),                       // PLL enabled (reset inactive)
        .BYPASS(1'b0)                        // PLL not bypassed
    );

    // Counter that increments every PLL clock cycle (~66.75 MHz)
    reg [25:0] counter_pll = 0;
    always @(posedge clk_pll) begin
        counter_pll <= counter_pll + 1;
    end

    // Connect high bit of counter to LED1
    // - Bit 25 toggles every 2^25 PLL cycles, so full period = 2^26 / F_PLL
    // - At 66.75 MHz, this gives ~1.006 second period (≈ 1 Hz blink)
    assign LED1 = counter_pll[25];

    // =========================================================================
    // SECTION 2: Internal High-Frequency Oscillator (HFOSC)
    // =========================================================================

    wire clk_hf;  // Output clock from HFOSC

    // Instantiate SB_HFOSC to enable internal oscillator
    // Parameters:
    // - .CLKHF_DIV("0b10") sets output divider to ÷4 → 48 MHz / 4 = 12 MHz
    //
    // Ports:
    // - CLKHFEN (input): clock output enable — set to 1'b1 to enable output
    // - CLKHFPU (input): power up the oscillator — set to 1'b1 to turn on
    // - CLKHF   (output): output clock after divider
    SB_HFOSC #(
        .CLKHF_DIV("0b10")  // Divide 48 MHz by 4 → 12 MHz output (can only divide by 1/2/4/8)
    ) hfosc_inst (
        .CLKHFEN(1'b1),     // Enable HFOSC clock output
        .CLKHFPU(1'b1),     // Power up the HFOSC
        .CLKHF(clk_hf)      // Output clock wire
    );

    // Counter driven by 12 MHz internal HFOSC clock
    reg [23:0] counter_hf = 0;
    always @(posedge clk_hf) begin
        counter_hf <= counter_hf + 1;
    end

    // Use counter bit 23 to blink LED2
    // - Toggles at 12 MHz / 2^24 ≈ 0.715 Hz → full blink period ≈ 1.4 seconds
    assign LED2 = counter_hf[23];

    // =========================================================================
    // SECTION 3: Internal Low-Frequency Oscillator (LFOSC)
    // =========================================================================

    wire clk_lf;  // Output clock from LFOSC

    // Instantiate SB_LFOSC for ~10 kHz internal oscillator
    //
    // Ports:
    // - CLKLFEN (input): clock output enable — set to 1'b1 to enable output
    // - CLKLFPU (input): power up the oscillator — set to 1'b1 to turn it on
    // - CLKLF   (output): output clock (~10 kHz, ±50% inaccurate)
    SB_LFOSC lfosc_inst (
        .CLKLFEN(1'b1),     // Enable LFOSC clock output
        .CLKLFPU(1'b1),     // Power up the LFOSC
        .CLKLF(clk_lf)      // Output clock wire
    );

    // Counter driven by ~10 kHz LFOSC
    reg [16:0] counter_lf = 0;
    always @(posedge clk_lf) begin
        counter_lf <= counter_lf + 1;
    end

    // Use counter bit 16 to blink LED3
    // - Toggles at 10 kHz / 2^17 ≈ 0.076 Hz → full blink period ≈ 13.1 seconds
    // - Note: LFOSC is ±50% inaccurate; this is approximate
    assign LED3 = counter_lf[16];

endmodule
