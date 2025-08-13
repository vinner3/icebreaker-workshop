from pyftdi.gpio import GpioController

URL = 'ftdi://::/1'     # Interface A
BIT = 4                 # change to 4 to test ADBUS4, etc.
MASK = 1 << BIT

gpio = GpioController()
gpio.configure(URL, direction=MASK)

gpio.write(MASK)        # HIGH -> LED off
input(f"ADBUS{BIT} HIGH. Press Enter to set LOW...")

gpio.write(0x00)        # LOW -> LED on (if this is CS#)
input(f"ADBUS{BIT} LOW. Press Enter to set HIGH again...")

gpio.write(MASK)        # HIGH -> LED off
gpio.close()
