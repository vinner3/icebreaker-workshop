# Import the SPI controller class from the PyFTDI library
from pyftdi.spi import SpiController
import time  # For adding delays between transactions

# Create an instance of the SPI controller
spi = SpiController()

# Connect to FTDI device (FT2232H channel A) using PyFTDI
# The URL 'ftdi://ftdi:2232h/1' means:
#   - Use an FTDI chip with a 2232H layout
#   - Use interface 1 (which is channel A on the Icebreaker board)
spi.configure('ftdi://ftdi:2232h/1')

# Create a SPI port object -- this allows communication with the FPGA
# Even though we say cs=0, we will manually control chip select (CS) ourselves
#   - freq=100_000 sets SPI clock frequency to 100 kHz (slow and safe)
#   - mode=0 sets SPI mode 0 (CPOL=0, CPHA=0)
port = spi.get_port(cs=0, freq=100_000, mode=0)

# Get GPIO controller from the same SPI interface
# We'll use this to manually control ADBUS4 (which is CS# on the Icebreaker)
gpio = spi.get_gpio()

# Set the direction of GPIO pins:
#   - 0x10 = 0b00010000 = bit 4 = ADBUS4
#   - Set it as an output so we can toggle it
gpio.set_direction(0x10, 0x10)

# Define a function to pull CS# (chip select) low
# This tells the FPGA "you're selected, listen now"
def cs_low():
    # Read current GPIO state, clear bit 4, write it back
    gpio.write(gpio.read() & ~0x10)

# Define a function to release CS# (chip select high)
# This tells the FPGA "you're done, stop responding"
def cs_high():
    # Read current GPIO state, set bit 4, write it back
    gpio.write(gpio.read() | 0x10)

# Track the previously sent value (for printout comparison)
prev = 0x00

# Send 10 bytes to the FPGA over SPI
for i in range(10):
    cs_low()  # Begin SPI transaction (CS# low)

    # This is the core SPI transaction
    # Send 1 byte (value i) and receive 1 byte in return
    # SPI is full-duplex: for every byte sent on MOSI, we receive 1 byte on MISO
    # For example can do this: port.exchange([0x12, 0x34, 0x56], 3)
    rx = port.exchange([i], 1)  # [i] = list with one byte to send

    cs_high()  # End SPI transaction (CS# high)

    # Print what we sent and what we received in hexadecimal
    # Also show what value we sent last time (to check the echo delay)
    # :02X:
        # :	Start of format specifier
        # 0	Pad with zeros if needed
        # 2	Minimum width is 2 characters
        # X	Display number in uppercase hex
        #f"{5:02X}"   → "05"
        #f"{31:02X}"  → "1F"
        #f"{255:02X}" → "FF"

    print(f"Sent: {i:02X}  Got: {rx[0]:02X} (should match previous: {prev:02X})")

    # Update the previous sent value for next comparison
    prev = i

    # Wait half a second before next SPI transaction
    time.sleep(2)


