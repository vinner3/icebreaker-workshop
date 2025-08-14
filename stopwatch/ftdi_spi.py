from pyftdi.spi import SpiController
import time

# Initialize SPI controller
spi = SpiController()

# Configure the FTDI interface (channel 1 of FT2232H)
# No automatic CS# line; we handle it manually via GPIO
spi.configure('ftdi://ftdi:2232h/1')

# Get SPI port with no chip select (we manually handle CS# via GPIO)
port = spi.get_port(cs=0, freq=100_000, mode=0)

# Configure ADBUS4 (bit 4) as manual CS#
gpio = spi.get_gpio()
gpio.set_direction(0x10, 0x10)  # Set bit 4 as output

def cs_low():
    """Drive CS# low to start a transaction"""
    gpio.write(gpio.read() & ~0x10)

def cs_high():
    """Drive CS# high to end a transaction"""
    gpio.write(gpio.read() | 0x10)

# Initial previous value
prev = 0xFF

# SPI transaction loop
for i in range(10):
    # Write i (no read)
    cs_low()
    port.write([i])
    cs_high()

    # Read echo of the previous write
    cs_low()
    rx = port.read(1)   # clocks 8 cycles with MOSI=0x00
    cs_high()

    print(f"Sent: {i:02X}, Got: {rx[0]:02X}")
    time.sleep(0.5)

