"""Optional pyserial transport for the dependency-free Modbus codec."""

import time


class SerialRtuTransport:
    def __init__(self, port, baudrate=115200, timeout_s=0.1):
        try:
            import serial
        except ImportError as exception:
            raise RuntimeError("Install pyserial to use a physical RS-485 port") from exception
        self.serial = serial.Serial(
            port=port, baudrate=baudrate, bytesize=8, parity=serial.PARITY_EVEN,
            stopbits=serial.STOPBITS_ONE, timeout=timeout_s,
        )
        bits_per_character = 11
        self.interframe_s = max(3.5 * bits_per_character / baudrate,
                                0.00175 if baudrate > 19200 else 0.0)

    def exchange(self, request):
        time.sleep(self.interframe_s)
        self.serial.reset_input_buffer()
        self.serial.write(request)
        self.serial.flush()
        header = self.serial.read(3)
        if len(header) != 3:
            return header
        if header[1] & 0x80:
            return header + self.serial.read(2)
        return header + self.serial.read(header[2] + 2)

    def close(self):
        self.serial.close()
