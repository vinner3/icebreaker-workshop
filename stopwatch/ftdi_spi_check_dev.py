from pyftdi.ftdi import Ftdi

devs = list(Ftdi.list_devices())
print(f"Found devices: {len(devs)}")

for idx, item in enumerate(devs):
    # PyFtdi returns (usb_device, interfaces) or sometimes (usb_device, interface)
    if isinstance(item, (list, tuple)) and len(item) >= 2:
        usb_dev = item[0]
        if hasattr(usb_dev, 'serial_number'):
            serial = usb_dev.serial_number
            manu   = getattr(usb_dev, 'manufacturer', '?')
            prod   = getattr(usb_dev, 'product', '?')
        else:
            serial = '?'; manu = '?'; prod = '?'

        # interfaces may be a list of interface numbers, or a single interface
        itf = item[1]
        if isinstance(itf, (list, tuple)):
            interfaces = list(itf)
        else:
            interfaces = [itf]

        print(f"[{idx}] serial={serial}  manufacturer={manu}  product={prod}  interfaces={interfaces}")

        # Print usable URLs for Interface A (= /1) and B (= /2)
        if serial and serial != '?':
            print(f"   Try A: ftdi://ftdi:2232h:{serial}/1")
            print(f"   Try B: ftdi://ftdi:2232h:{serial}/2")
        else:
            print("   Try generic A: ftdi://::/1")
            print("   Try generic B: ftdi://::/2")
    else:
        print(f"[{idx}] Unexpected descriptor: {item}")
