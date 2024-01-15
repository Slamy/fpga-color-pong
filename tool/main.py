import math
import os
import struct

import serial
import serial.threaded
import matplotlib.pyplot as plt

serial = serial.Serial()
serial.port = "/dev/serial/by-id/usb-SIPEED_JTAG_Debugger_FactoryAIOT_Pro-if01-port0"
serial.baudrate = 3000000
serial.timeout = 1
serial.open()

# TODO For some reason the serial port only works after the second open.
# This problem correlates with the baud rate. With 115200 I don't have this issue
# This might be a linux only problem? Requires check on another operation system.
serial.close()
serial.open()

values = []
for _ in range(6000):
    arr = serial.read()
    values.append(struct.unpack("B", arr)[0])


plt.plot(values, 'g', label='value')
plt.show()
