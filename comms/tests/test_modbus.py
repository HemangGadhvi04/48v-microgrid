import json
import pathlib
import sys
import tempfile
import unittest

COMMS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(COMMS))

from gateway import TelemetryGateway
from microgrid_modbus import (ModbusError, SunSpecImage, crc16, decode_read_response,
                              read_complete_image, read_holding_request, verify_frame)


TELEMETRY = {
    "ac_current_a": 17.32, "ac_voltage_v": 28.85,
    "active_power_w": 499, "frequency_hz": 50.01,
    "apparent_power_va": 500, "reactive_power_var": -150,
    "power_factor_percent": 99.94, "lifetime_energy_wh": 123456,
    "dc_current_a": 10.81, "dc_voltage_v": 48.02,
    "dc_power_w": 519, "cabinet_temperature_c": 31.2,
    "heatsink_temperature_c": 42.6, "operating_state": 4,
    "event_bits": 0x00000102,
}


class ModbusTests(unittest.TestCase):
    def setUp(self):
        self.device = SunSpecImage()
        self.device.update(TELEMETRY)

    def test_known_modbus_crc_vector(self):
        request = bytes.fromhex("01030000000a")
        self.assertEqual(crc16(request), 0xCDC5)
        self.assertEqual(read_holding_request(1, 0, 10), bytes.fromhex("01030000000ac5cd"))

    def test_bad_crc_is_rejected_and_silently_discarded(self):
        frame = bytearray(read_holding_request(1, 40000, 2))
        frame[-1] ^= 1
        with self.assertRaises(ModbusError):
            verify_frame(frame)
        self.assertEqual(self.device.handle_rtu(frame), b"")

    def test_complete_image_round_trip(self):
        decoded = read_complete_image(self.device.handle_rtu)
        common = decoded["common"]
        inverter = decoded["inverter_single_phase"]
        self.assertEqual(common["Mn"], "Open Microgrid Research")
        self.assertEqual(common["Md"], "48V-500W-LAB")
        self.assertAlmostEqual(inverter["A"], 17.32, places=2)
        self.assertAlmostEqual(inverter["PhVphA"], 28.85, places=2)
        self.assertEqual(inverter["W"], 499)
        self.assertEqual(inverter["VAr"], -150)
        self.assertAlmostEqual(inverter["PF"], 99.94, places=2)
        self.assertEqual(inverter["Evt1"], 0x00000102)

    def test_illegal_address_returns_exception(self):
        response = self.device.handle_rtu(read_holding_request(1, 50000, 1))
        payload = verify_frame(response)
        self.assertEqual(payload, bytes((1, 0x83, 2)))

    def test_success_is_logged_and_becomes_stale(self):
        clock = [100.0]
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "telemetry.jsonl"
            gateway = TelemetryGateway(self.device.handle_rtu, path, clock=lambda: clock[0])
            record = gateway.poll()
            self.assertFalse(gateway.is_stale())
            self.assertEqual(record["W"], 499)
            clock[0] += 0.6
            self.assertTrue(gateway.is_stale())
            lines = path.read_text(encoding="utf-8").splitlines()
            self.assertEqual(len(lines), 1)
            self.assertEqual(json.loads(lines[0])["DCV"], 48.02)

    def test_corrupt_response_increments_error_count(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "telemetry.jsonl"
            gateway = TelemetryGateway(lambda request: b"bad-frame", path)
            with self.assertRaises(ModbusError):
                gateway.poll()
            self.assertEqual(gateway.poll_errors, 1)
            self.assertTrue(gateway.is_stale())
            self.assertFalse(path.exists())


if __name__ == "__main__":
    unittest.main()
