from pyftdi.spi import SpiController
from pyftdi.gpio import GpioController
import time

# Constants
FPGA_CS_MASK = 0x01  # BDBUS0 = bit 0

# --- Setup SPI on Port A ---
spi = SpiController()
spi.configure('ftdi://ftdi:2232h/1')  # Port A = interface 1
port = spi.get_port(cs=0, freq=100_000, mode=0)

# --- Setup GPIO on Port B for manual CS ---
gpio = GpioController()
gpio.configure('ftdi://ftdi:2232h/2')  # Port B = interface 2
gpio.set_direction(FPGA_CS_MASK, FPGA_CS_MASK)  # BDBUS0 output

def cs_low():
    gpio.write(gpio.read() & ~FPGA_CS_MASK)

def cs_high():
    gpio.write(gpio.read() | FPGA_CS_MASK)

# --- Begin communication ---
cs_high()  # Idle state: CS high
time.sleep(0.1)

for i in range(10):
    cs_low()                     # Assert CS#
    rx = port.exchange([i], 1)   # Send 1 byte, receive 1 byte
    cs_high()                    # Deassert CS#

    print(f"Sent: {i:02X}, Got: {rx[0]:02X}")
    time.sleep(0.5)

# --- Cleanup ---
gpio.close()
spi.terminate()
