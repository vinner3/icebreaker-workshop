/*==============================================================================
 top.v — UART RX + TX echo demo for iCEBreaker (Port B, 115200, 8-N-1)

 PURPOSE
   Let a PC directly control the iCEBreaker’s red LED over the on-board FTDI
   UART (Port B). Sending ASCII '1' turns the LED ON, sending ASCII '0'
   turns it OFF. In addition, this version ECHOS the received byte back to
   the PC so you can read a response (useful for debugging and protocols).

 WHAT THIS MODULE DOES
   - Receives UART frames from FTDI Port B at 115200 baud, 8-N-1.
   - Uses a 2-flip-flop synchronizer (for metastability protection).
   - Detects the start bit, then samples each bit near the center of its
     bit period using the 12 MHz board clock.
   - Reassembles the received 8 data bits into a byte.
   - If the byte is ASCII '1' (0x31): drive LEDR_N = 0 (LED ON, active-low).
     If the byte is ASCII '0' (0x30): drive LEDR_N = 1 (LED OFF).
   - TX path: after a byte is received, it is queued and transmitted back to
     the PC as a proper 8-N-1 frame (start, 8 data LSB-first, stop).

 WHAT THIS MODULE DOES NOT DO
   - It does not implement parity or framing-error checks (simple demo).
   - It transmits only one byte per received byte (echo). You can extend
     this to send strings like "OK\\r\\n" or implement a register protocol.

 CLOCKING & SERIAL SETTINGS
   - System clock: 12 MHz (iCEBreaker).
   - UART: 115200 baud, 8 data bits, No parity, 1 stop bit (8-N-1).
   - Bit-time divider: DIV = 12_000_000 / 115200 ≈ 104 clocks/bit.

 PIN / PCF MAPPING (iCEBreaker)
   - CLK     → pin 35 (12 MHz)
   - RX      → pin 6  (FTDI Port B TXD → FPGA RX)
   - TX      → pin 9  (FPGA TX → FTDI Port B RXD)
   - LEDR_N  → pin 11 (red LED, active-low: 0=ON, 1=OFF)

 QUICK TEST (Windows, COM6 example)
   1) Program bitstream:   make prog
   2) In Python:           pip install pyserial
      >>> import serial, time
      >>> ser = serial.Serial('COM6', 115200, timeout=1)
      >>> ser.reset_input_buffer()
      >>> ser.write(b'1'); ser.read(1)   # should return b'1' (LED ON)
      >>> ser.write(b'0'); ser.read(1)   # should return b'0' (LED OFF)
      >>> ser.close()

 NOTES
   - Active-low LED: driving LEDR_N low lights the LED.
   - The simple receiver/transmitter are adequate for clean lab links over FTDI.
   - You can later change the TX to send "OK\\r\\n" or implement a protocol.
==============================================================================*/

module top (
    input  wire CLK,     // 12 MHz system clock (pin 35 in your PCF)
    input  wire RX,      // UART receive from FTDI Port B TXD (pin 6)
    output wire TX,      // UART transmit to FTDI Port B RXD (pin 9)
    output reg  LEDR_N   // Red LED (active-low) (pin 11)
);

    // ===== UART parameters =====
    localparam integer CLK_HZ = 12_000_000;   // board clock
    localparam integer BAUD   = 115200;       // serial speed to match PC
    localparam integer DIV    = CLK_HZ / BAUD; // number of CLK ticks per UART bit time (~104)

    // ===== 2-flip-flop synchronizer for RX (metastability protection) =====
    reg rx_d1 = 1'b1, rx_d2 = 1'b1;
    always @(posedge CLK) begin
        rx_d1 <= RX;      // first stage samples the async RX line
        rx_d2 <= rx_d1;   // second stage stabilizes it
    end

    // ===== UART RX state =====
    reg [15:0] rx_tick = 16'd0;   // counts down to next sample point
    reg        rx_busy = 1'b0;    // are we in the middle of receiving a frame?
    reg [3:0]  rx_bitn = 4'd0;    // which bit (0..9) => start, d0..d7, stop
    reg [9:0]  rx_sh   = 10'h3FF; // shift register for 10 bits (idle-high init)
    reg [7:0]  rx_byte;           // captured byte (data only)

    // LED default OFF (active-low ⇒ drive '1' to turn it off)
    initial LEDR_N = 1'b1;

    // ===== Strobes to hand off RX byte to TX (echo) =====
    reg        tx_load = 1'b0; // one-clock pulse to request a transmit
    reg [7:0]  tx_data = 8'h00;

    // ===== UART RX finite-state behavior =====
    always @(posedge CLK) begin
        tx_load <= 1'b0; // default: no transmit request this cycle

        if (!rx_busy) begin
            // IDLE: line should be high (stop/idle = '1'). Look for START (falling edge).
            if (rx_d2 == 1'b0) begin                    // saw line go low = start bit edge
                rx_busy <= 1'b1;                        // begin receiving a frame
                rx_bitn <= 4'd0;                        // will collect 10 bits total
                rx_tick <= DIV + (DIV >> 1);            // wait ~1.5 bit-times to mid-start
            end
        end else begin
            // RECEIVING: count down to next sample point
            if (rx_tick == 16'd0) begin
                rx_tick <= DIV[15:0];                   // next sample exactly 1 bit later
                rx_sh   <= {rx_d2, rx_sh[9:1]};         // shift in latest sampled bit (MSB side)
                rx_bitn <= rx_bitn + 1'b1;              // move to next bit position

                if (rx_bitn == 4'd9) begin              // after 10 samples (0..9) we have full frame
                    rx_busy <= 1'b0;                    // go back to idle for next frame
                    rx_byte <= rx_sh[8:1];              // extract the 8 data bits (ignore start/stop)

                    // ===== Simple "command parser" for this demo =====
                    if      (rx_sh[8:1] == "1") LEDR_N <= 1'b0; // '1' → LED ON  (active-low)
                    else if (rx_sh[8:1] == "0") LEDR_N <= 1'b1; // '0' → LED OFF (inactive-high)

                    // Hand off the received byte to TX for echo
                    tx_data <= rx_sh[8:1];
                    tx_load <= 1'b1;
                end
            end else begin
                rx_tick <= rx_tick - 1'b1;              // keep counting toward the sample point
            end
        end
    end

    // -------------------------------------------------------------------------
    // UART TX (echo) — sends one 8-N-1 frame when tx_load is asserted
    // -------------------------------------------------------------------------
    // TX line and shifter. We send LSB first: start(0), d0..d7, stop(1).
    reg        tx_line = 1'b1;  // UART idle is high
    assign TX = tx_line;

    reg [15:0] tx_tick = 16'd0;
    reg        tx_busy = 1'b0;
    reg [3:0]  tx_bitn = 4'd0;
    reg [9:0]  tx_sh   = 10'h3FF; // preload/idle as 1's

    always @(posedge CLK) begin
        if (!tx_busy) begin
            if (tx_load) begin
                // Load full frame into shifter: {stop, data[7:0], start}
                tx_sh   <= {1'b1, tx_data, 1'b0};
                tx_bitn <= 4'd0;
                tx_tick <= DIV[15:0];
                tx_busy <= 1'b1;
                tx_line <= 1'b1; // first bit will be driven on the first tick
            end
        end else begin
            if (tx_tick == 16'd0) begin
                tx_tick <= DIV[15:0];
                tx_line <= tx_sh[0];            // output current LSB (start, d0..d7, stop)
                tx_sh   <= {1'b1, tx_sh[9:1]};  // shift right, fill with 1's on top
                tx_bitn <= tx_bitn + 1'b1;
                if (tx_bitn == 4'd9) begin      // 10 bits sent → done
                    tx_busy <= 1'b0;
                    tx_line <= 1'b1;            // return to idle-high
                end
            end else begin
                tx_tick <= tx_tick - 1'b1;
            end
        end
    end

endmodule
