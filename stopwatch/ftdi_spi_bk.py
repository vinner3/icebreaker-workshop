from pyftdi.spi import SpiController
import time

spi = SpiController()
spi.configure('ftdi://ftdi:2232h/1')  # Port A
slave = spi.get_port(cs=0, freq=1e6, mode=0)  # we'll ignore this CS and use GPIO on ADBUS4

gpio = spi.get_gpio()
# Configure ADBUS4 as output and start HIGH (inactive)
gpio.set_direction(0x10, 0x10)  # bit4 output
state = gpio.read() | 0x10
gpio.write(state)

def cs_low():
    nonlocal_state = gpio.read() & ~0x10
    gpio.write(nonlocal_state)

def cs_high():
    nonlocal_state = gpio.read() | 0x10
    gpio.write(nonlocal_state)

# --- Make the LED visibly on for ~0.5 s before and after the transfer ---
cs_low()
time.sleep(0.1)
resp = slave.exchange([0x9F], 3)
time.sleep(0.1)
cs_high()

print("JEDEC ID:", resp.hex())