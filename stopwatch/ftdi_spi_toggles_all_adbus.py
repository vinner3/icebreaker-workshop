import time
from pyftdi.gpio import GpioController

URL = 'ftdi://::/1'  # Interface A

for bit in range(8):
    mask = 1 << bit
    try:
        print(f"\n=== Testing ADBUS{bit} (mask 0x{mask:02X}) ===")
        gpio = GpioController()
        # Only this bit is an output; all other ADBUS lines remain inputs
        gpio.configure(URL, direction=mask)

        # Drive the selected bit LOW for 1 second
        print("Drive LOW (LED should turn ON if this is CS#)...")
        gpio.write(0x00)
        time.sleep(1.0)

        # Drive the selected bit HIGH for 0.5s
        print("Drive HIGH (LED should turn OFF if this is CS#)...")
        gpio.write(mask)
        time.sleep(0.5)

    except Exception as e:
        print("Error on ADBUS", bit, "->", e)
    finally:
        try:
            gpio.close()
        except Exception:
            pass
        time.sleep(0.3)
