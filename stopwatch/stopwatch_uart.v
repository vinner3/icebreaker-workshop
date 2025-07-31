/*==============================================================================
 top.v — Minimal UART-controlled LED demo for iCEBreaker

 PURPOSE
   Let a PC directly control the iCEBreaker’s red LED over the on-board FTDI
   UART (Port B). Sending ASCII '1' turns the LED ON, sending ASCII '0'
   turns it OFF.

 WHAT THIS MODULE DOES
   - Receives UART frames from FTDI Port B at 115200 baud, 8-N-1.
   - Uses a 2-flip-flop synchronizer (for metastability protection).
   - Detects the start bit, then samples each bit near the center of its
     bit period using the 12 MHz board clock.
   - Reassembles the received 8 data bits into a byte.
   - If the byte is ASCII '1' (0x31): drive LEDR_N = 0 (LED ON, active-low).
     If the byte is ASCII '0' (0x30): drive LEDR_N = 1 (LED OFF).

 WHAT THIS MODULE DOES NOT DO
   - It does not transmit replies back to the PC (TX is held idle-high).
   - It does not implement parity or framing-error checks (simple demo).

 CLOCKING & SERIAL SETTINGS
   - System clock: 12 MHz (iCEBreaker).
   - UART: 115200 baud, 8 data bits, No parity, 1 stop bit (8-N-1).
   - Bit-time divider: DIV = 12_000_000 / 115200 ≈ 104 clocks/bit.

 PIN / PCF MAPPING (iCEBreaker)
   - CLK     → pin 35 (12 MHz)
   - RX      → pin 6  (FTDI Port B TXD → FPGA RX)
   - TX      → pin 9  (FPGA TX → FTDI Port B RXD; idle only in this demo)
   - LEDR_N  → pin 11 (red LED, active-low: 0=ON, 1=OFF)

 QUICK TEST (Windows, COM6 example)
   1) Program bitstream:   make prog
   2) In Python:           pip install pyserial
      >>> import serial, time
      >>> ser = serial.Serial('COM6', 115200, timeout=1)
      >>> ser.write(b'1')   # LED ON
      >>> ser.write(b'0')   # LED OFF
      >>> ser.close()

 NOTES
   - Active-low LED: driving LEDR_N low lights the LED.
   - The simple receiver is adequate for clean lab links over FTDI.
   - You can later add a TX path to echo responses or implement a command protocol.
==============================================================================*/

module top (
    input  wire CLK,     // 12 MHz system clock (pin 35 in your PCF)
    input  wire RX,      // UART receive from FTDI Port B TXD (pin 6)
    output wire TX,      // UART transmit to FTDI Port B RXD (pin 9) -- we hold it idle
    output reg  LEDR_N   // Red LED (active-low) (pin 11)
);

    // ===== UART parameters =====
    localparam CLK_HZ = 12_000_000;   // board clock
    localparam BAUD   = 115200;       // serial speed to match PC
    localparam DIV    = CLK_HZ / BAUD; // number of CLK ticks per UART bit time (~104)

    // ===== 2-flip-flop synchronizer for RX (metastability protection) =====
    reg rx_d1 = 1, rx_d2 = 1;
    always @(posedge CLK) begin
        rx_d1 <= RX;      // first stage samples the async RX line
        rx_d2 <= rx_d1;   // second stage stabilizes it
    end

    // ===== Receiver state =====
    reg [15:0] tick = 0;  // counts down clock cycles to next sample
    reg        busy = 0;  // are we in the middle of receiving a frame?
    reg [3:0]  bitn = 0;  // which bit have we sampled (0..9) => start, 8 data, stop
    reg [9:0]  sh   = 10'h3FF; // shift register for 10 bits (LSB first)
    reg [7:0]  byte;      // captured data byte (8 bits)

    // LED default OFF (active-low ⇒ drive '1' to turn it off)
    initial LEDR_N = 1'b1;

    // ===== UART RX finite-state behavior =====
    always @(posedge CLK) begin
        if (!busy) begin
            // IDLE: line should be high (stop/idle = '1'). Look for START (a falling edge).
            if (rx_d2 == 1'b0) begin                 // saw line go low = start bit edge
                busy <= 1'b1;                        // we are now receiving a frame
                bitn <= 0;                           // we will collect 10 bits total
                tick <= DIV + DIV/2;                 // wait 1.5 bit-times to hit mid-start
            end
        end else begin
            // RECEIVING: count down to next sample point
            if (tick == 0) begin
                tick <= DIV;                         // next samples exactly 1 bit later
                sh   <= {rx_d2, sh[9:1]};            // shift in latest sampled bit at MSB side
                bitn <= bitn + 1;                    // move to next bit position

                if (bitn == 9) begin                 // after 10 samples (0..9) we have full frame
                    busy <= 0;                       // go back to idle for next frame
                    byte <= sh[8:1];                 // extract the 8 data bits (ignore start/stop)

                    // ===== Simple "command parser" for this demo =====
                    if      (sh[8:1] == "1") LEDR_N <= 1'b0; // '1' → LED ON  (active-low)
                    else if (sh[8:1] == "0") LEDR_N <= 1'b1; // '0' → LED OFF (inactive-high)
                end
            end else begin
                tick <= tick - 1;                    // keep counting toward the sample point
            end
        end
    end

    // ===== Minimal TX path =====
    assign TX = 1'b1;  // Keep TX idle-high (UART idle level). We don't send replies yet.

endmodule
