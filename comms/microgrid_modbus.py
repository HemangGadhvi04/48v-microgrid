"""Small dependency-free SunSpec Model 1/101 Modbus RTU implementation."""

import json
import pathlib
import struct


HERE = pathlib.Path(__file__).resolve().parent


class ModbusError(ValueError):
    pass


def crc16(data):
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc


def with_crc(payload):
    return payload + struct.pack("<H", crc16(payload))


def verify_frame(frame):
    if len(frame) < 4:
        raise ModbusError("frame too short")
    expected = struct.unpack("<H", frame[-2:])[0]
    if crc16(frame[:-2]) != expected:
        raise ModbusError("CRC mismatch")
    return frame[:-2]


def read_holding_request(unit_id, address, count):
    if not 1 <= unit_id <= 247 or not 1 <= count <= 125:
        raise ValueError("invalid Modbus unit or register count")
    return with_crc(struct.pack(">BBHH", unit_id, 3, address, count))


def _encode_string(value, registers):
    raw = value.encode("ascii")[: 2 * registers].ljust(2 * registers, b"\0")
    return list(struct.unpack(">" + "H" * registers, raw))


def _signed_word(value):
    return value & 0xFFFF


def _encode_value(point, value):
    kind = point["type"]
    if "scale" in point:
        value = round(value / (10 ** point["scale"]))
    if kind == "string":
        return _encode_string(str(value), point["registers"])
    if kind in ("int16", "sunssf"):
        if not -32768 <= int(value) <= 32767:
            raise ValueError(f"{point['name']} exceeds int16")
        return [_signed_word(int(value))]
    if kind in ("uint16", "enum16"):
        if not 0 <= int(value) <= 0xFFFF:
            raise ValueError(f"{point['name']} exceeds uint16")
        return [int(value)]
    if kind in ("acc32", "bitfield32"):
        if not 0 <= int(value) <= 0xFFFFFFFF:
            raise ValueError(f"{point['name']} exceeds uint32")
        return [(int(value) >> 16) & 0xFFFF, int(value) & 0xFFFF]
    raise ValueError(f"unsupported SunSpec type {kind}")


def _decode_value(point, registers):
    kind = point["type"]
    if kind == "string":
        raw = struct.pack(">" + "H" * len(registers), *registers)
        return raw.rstrip(b"\0 ").decode("ascii")
    if kind in ("int16", "sunssf"):
        value = struct.unpack(">h", struct.pack(">H", registers[0]))[0]
    elif kind in ("uint16", "enum16"):
        value = registers[0]
    elif kind in ("acc32", "bitfield32"):
        value = (registers[0] << 16) | registers[1]
    else:
        raise ValueError(f"unsupported SunSpec type {kind}")
    if "scale" in point:
        value *= 10 ** point["scale"]
    return value


class SunSpecImage:
    def __init__(self, schema_path=None):
        path = pathlib.Path(schema_path) if schema_path else HERE / "sunspec_map.json"
        self.schema = json.loads(path.read_text(encoding="utf-8"))
        self.base = self.schema["base_register"]
        self.unit_id = self.schema["unit_id"]
        self.registers = [0xFFFF] * (self.schema["end_model_offset"] + 2)
        self.registers[0:2] = [0x5375, 0x6E53]
        for model in self.schema["models"]:
            start = model["offset"]
            self.registers[start] = model["id"]
            self.registers[start + 1] = model["length"]
            for point in model["points"]:
                if "value" in point:
                    self._write_point(model, point, point["value"])
        end = self.schema["end_model_offset"]
        self.registers[end:end + 2] = [0xFFFF, 0]

    def _write_point(self, model, point, value):
        encoded = _encode_value(point, value)
        start = model["offset"] + point["offset"]
        self.registers[start:start + len(encoded)] = encoded

    def update(self, telemetry):
        model = next(item for item in self.schema["models"] if item["id"] == 101)
        for point in model["points"]:
            source = point.get("source")
            if source is not None:
                self._write_point(model, point, telemetry[source])

    def read_registers(self, address, count):
        offset = address - self.base
        if offset < 0 or count < 1 or offset + count > len(self.registers):
            raise ModbusError("illegal data address")
        return self.registers[offset:offset + count]

    def handle_rtu(self, frame):
        try:
            payload = verify_frame(frame)
        except ModbusError:
            return b""  # RTU servers silently discard bad CRC frames.
        if len(payload) != 6 or payload[0] != self.unit_id:
            return b""
        function, address, count = struct.unpack(">BHH", payload[1:])
        if function != 3:
            return with_crc(bytes((self.unit_id, function | 0x80, 1)))
        if count > 125:
            return with_crc(bytes((self.unit_id, 0x83, 3)))
        try:
            values = self.read_registers(address, count)
        except ModbusError:
            return with_crc(bytes((self.unit_id, 0x83, 2)))
        data = struct.pack(">" + "H" * count, *values)
        return with_crc(bytes((self.unit_id, 3, len(data))) + data)


def decode_read_response(frame, unit_id, count):
    payload = verify_frame(frame)
    if payload[0] != unit_id:
        raise ModbusError("wrong unit id")
    if payload[1] & 0x80:
        raise ModbusError(f"Modbus exception {payload[2]}")
    if payload[1] != 3 or payload[2] != count * 2 or len(payload) != 3 + count * 2:
        raise ModbusError("invalid read response")
    return list(struct.unpack(">" + "H" * count, payload[3:]))


def decode_image(registers, schema_path=None):
    path = pathlib.Path(schema_path) if schema_path else HERE / "sunspec_map.json"
    schema = json.loads(path.read_text(encoding="utf-8"))
    if registers[:2] != [0x5375, 0x6E53]:
        raise ModbusError("SunS identifier missing")
    decoded = {}
    for model in schema["models"]:
        start = model["offset"]
        if registers[start] != model["id"] or registers[start + 1] != model["length"]:
            raise ModbusError(f"model {model['id']} header mismatch")
        values = {}
        for point in model["points"]:
            size = point.get("registers", 2 if point["type"] in ("acc32", "bitfield32") else 1)
            point_start = start + point["offset"]
            values[point["name"]] = _decode_value(point, registers[point_start:point_start + size])
        decoded[model["name"]] = values
    return decoded


def read_complete_image(exchange, schema_path=None):
    image = SunSpecImage(schema_path)
    count = len(image.registers)
    first_count = min(125, count)
    first = decode_read_response(exchange(read_holding_request(image.unit_id, image.base, first_count)),
                                 image.unit_id, first_count)
    if first_count == count:
        return decode_image(first, schema_path)
    remaining = count - first_count
    second = decode_read_response(exchange(read_holding_request(
        image.unit_id, image.base + first_count, remaining)), image.unit_id, remaining)
    return decode_image(first + second, schema_path)
