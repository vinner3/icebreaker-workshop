import serial, time

with serial.Serial('COM6', 115200, timeout=1) as s:
    s.reset_input_buffer()
    print("Turning on LED")
    s.write(b'1')            # LED ON
    print("RX:", s.read(1))  # expect b'1', waits for at most 1 byte of incoming data
    time.sleep(1)
    print("Turning off LED")
    s.write(b'0')            # LED OFF
    print("RX:", s.read(1))  # expect b'0', waits for at most 1 byte of incoming data
