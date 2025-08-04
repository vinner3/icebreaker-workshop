/*===========================================================
 top.v — UART RX + TX echo demo for iCEBreaker (Port B, 115200, 8-N-1)

 PURPOSE
   Let a PC directly control the iCEBreaker’s red LED over the on-board FTDI
   UART (Port B). Sending ASCII '1' turns the LED ON, sending ASCII '0'
   turns it OFF. This version also ECHOS each received byte back to the PC,
   so software on the PC can confirm communication (useful for debugging).

 WHAT THIS MODULE DOES
   - Receives UART frames at 115200 baud, 8-N-1 on RX (from FTDI Port B TXD).
   - Uses a 2-flip-flop synchronizer to safely bring the async RX into CLK domain.
   - Detects the start bit, then samples each bit near the bit center using DIV.
   - Reassembles 8 data bits into a byte and applies simple commands to LEDR_N.
   - Immediately transmits the received byte back on TX (to FTDI Port B RXD).

 WHAT THIS MODULE DOES NOT DO
   - No parity or framing-error checks (kept minimal for clarity).
   - TX sends one byte per received byte (echo).

 CLOCKING & SERIAL SETTINGS
   - System clock: 12 MHz (iCEBreaker).
   - UART format: 115200 baud, 8 data, No parity, 1 stop (8-N-1).
   - Bit-time divider: DIV = 12_000_000 / 115200 ≈ 104 clocks per bit.

 PIN / PCF MAPPING (iCEBreaker)
   - CLK     → pin 35 (12 MHz from oscillator)
   - RX      → pin 6  (FTDI Port B TXD → FPGA RX)
   - TX      → pin 9  (FPGA TX → FTDI Port B RXD)
   - LEDR_N  → pin 11 (red LED, active-low: 0=ON, 1=OFF)

 QUICK TEST (Windows, COM6 example)
   1) Build & program:      make prog
   2) Python (pyserial):
      >>> import serial, time
      >>> s = serial.Serial('COM6', 115200, timeout=1)
      >>> s.reset_input_buffer()
      >>> s.write(b'1'); s.read(1)   # expect b'1' (LED ON)
      >>> s.write(b'0'); s.read(1)   # expect b'0' (LED OFF)
      >>> s.close()

 NOTES
   - Active-low LED: LEDR_N=0 lights the LED; LEDR_N=1 turns it off.
   - Keep only one program connected to COM6 at a time.
   - Extend TX to send "OK\r\n" or implement a register protocol as needed.
===========================================================*/

module top (
    input  wire CLK,     // 12 MHz system clock (pin 35)
    input  wire RX,      // UART receive from FTDI Port B TXD (pin 6)
    output wire TX,      // UART transmit to FTDI Port B RXD (pin 9)
    output reg  LEDR_N   // Red LED (active-low) (pin 11)
);
    // ===== UART parameters =====
    localparam integer CLK_HZ = 12_000_000;   // Board clock frequency in Hz
    localparam integer BAUD   = 115200;       // UART line rate (bits per second)
    localparam integer DIV    = CLK_HZ / BAUD; // CLK ticks per bit (~104 @12MHz)
    // ===== 2-flip-flop synchronizer for RX (metastability protection) =====
    reg rx_d1 = 1'b1;              // First stage FF sampling asynchronous RX
    reg rx_d2 = 1'b1;              // Second stage FF to stabilize into CLK domain
    always @(posedge CLK) begin
        rx_d1 <= RX;                // Sample external RX into rx_d1
        rx_d2 <= rx_d1;             // Advance to rx_d2 (now safely in CLK domain)
    end
    // ===== UART RX state =====
    reg [15:0] rx_tick = 16'd0;     // Countdown to the next mid-bit sample point
    reg        rx_busy = 1'b0;      // 1 while receiving a frame (start→stop)
    reg [3:0]  rx_bitn = 4'd0;      // Bit index 0..9: start, d0..d7, stop
    reg [9:0]  rx_sh   = 10'h3FF;   // Shift reg (idle=all 1's) for sampled bits
    reg [7:0]  rx_byte;             // Captured data byte from the frame
    // LED default OFF (active-low ⇒ drive '1' to turn it off)
    initial LEDR_N = 1'b1;
    // ===== Hand-off strobes to TX =====
    reg        tx_load = 1'b0;      // One-clock pulse to request a TX of tx_data
    reg [7:0]  tx_data = 8'h00;     // Data byte to transmit when tx_load asserted
    // ===== UART RX finite-state behavior =====
    always @(posedge CLK) begin
        tx_load <= 1'b0;                      // Default: no transmit request now
        if (!rx_busy) begin                   // If idle (not receiving)
            if (rx_d2 == 1'b0) begin          // Start bit detect: line went low
                rx_busy <= 1'b1;              // Enter receiving state
                rx_bitn <= 4'd0;              // Reset bit counter
                rx_tick <= DIV + (DIV >> 1);  // Wait ~1.5 bit-times to mid-start
            end
        end else begin                        // Else: currently receiving bits
            if (rx_tick == 16'd0) begin       // Time to sample a bit
                rx_tick <= DIV[15:0];         // Next sample 1 bit later
                rx_sh   <= {rx_d2, rx_sh[9:1]};// Shift in sampled bit at MSB side
                rx_bitn <= rx_bitn + 1'b1;    // Move to next bit position
                if (rx_bitn == 4'd9) begin    // After 10 samples (0..9) we have full frame
                    rx_busy <= 1'b0;          // Done with this frame
                    rx_byte <= rx_sh[8:1];    // Extract 8 data bits (ignore start/stop)
                    // ===== Simple "command parser" for this demo =====
                    if      (rx_sh[8:1] == "1") LEDR_N <= 1'b0; // '1' → LED ON
                    else if (rx_sh[8:1] == "0") LEDR_N <= 1'b1; // '0' → LED OFF
                    tx_data <= rx_sh[8:1];    // Prepare to echo received byte
                    tx_load <= 1'b1;          // Request a transmit of tx_data
                end
            end else begin
                rx_tick <= rx_tick - 1'b1;    // Count down toward next sample
            end
        end
    end

   // ===== UART TX (echo) =====
    reg        tx_line = 1'b1;       // The actual TX output line (idle=1)
    assign TX = tx_line;             // Drive top-level TX port from tx_line

    reg [15:0] tx_tick = 16'd0;      // Countdown for TX bit timing
    reg        tx_busy = 1'b0;       // 1 while transmitting a frame
    reg [3:0]  tx_bitn = 4'd0;       // Bit index 0..9 for TX (start..stop)
    reg [9:0]  tx_sh   = 10'h3FF;    // TX shift register (seed idle=1's)

    always @(posedge CLK) begin
        if (!tx_busy) begin          // If idle (ready to start a new frame)
            if (tx_load) begin       // A transmit request arrived this cycle
                tx_sh   <= {1'b1, tx_data, 1'b0}; // Load {stop, data[7:0], start}
                tx_bitn <= 4'd0;     // Reset TX bit counter
                tx_tick <= DIV[15:0];// Start bit-time countdown
                tx_busy <= 1'b1;     // Enter busy (transmitting)
                tx_line <= 1'b1;     // Keep line idle until first tick shifts out
            end
        end else begin               // Currently transmitting
            if (tx_tick == 16'd0) begin // Time to output next bit
                tx_tick <= DIV[15:0];// Reload for next bit time
                tx_line <= tx_sh[0]; // Present current LSB on TX line
                tx_sh   <= {1'b1, tx_sh[9:1]}; // Shift right, fill top with 1's
                tx_bitn <= tx_bitn + 1'b1; // Advance to next bit
                if (tx_bitn == 4'd9) begin // After 10 bits (start+8+stop)
                    tx_busy <= 1'b0; // Done transmitting
                    tx_line <= 1'b1; // Return line to idle-high
                end
            end else begin
                tx_tick <= tx_tick - 1'b1; // Count down toward next bit
            end
        end
    end

endmodule