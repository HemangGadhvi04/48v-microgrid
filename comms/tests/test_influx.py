import pathlib
import sys
import unittest

COMMS = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(COMMS))

from influx_writer import InfluxWriter, telemetry_line


RECORD = {
    "timestamp_unix_s": 100.25, "poll_errors": 0, "A": 17.32,
    "PhVphA": 28.85, "W": 499, "Hz": 50.01, "VA": 500,
    "VAr": -150, "PF": 99.94, "WH": 123456, "DCA": 10.81,
    "DCV": 48.02, "DCW": 519, "TmpCab": 31.2, "TmpSnk": 42.6,
    "St": 4, "Evt1": 258,
}


class FakeResponse:
    status = 204
    def __enter__(self): return self
    def __exit__(self, *args): return False


class InfluxTests(unittest.TestCase):
    def test_line_protocol_contains_units_and_timestamp(self):
        line = telemetry_line(RECORD, "lab inverter")
        self.assertTrue(line.startswith("microgrid,device=lab\\ inverter "))
        self.assertIn("active_power_w=499i", line)
        self.assertIn("reactive_power_var=-150i", line)
        self.assertTrue(line.endswith("100250000000"))

    def test_writer_builds_authenticated_v2_request(self):
        captured = {}
        def opener(request, timeout):
            captured["request"] = request
            captured["timeout"] = timeout
            return FakeResponse()
        writer = InfluxWriter("http://localhost:8086", "lab", "telemetry", "secret", opener)
        self.assertEqual(writer.write([RECORD]), 1)
        request = captured["request"]
        self.assertEqual(request.method, "POST")
        self.assertIn("org=lab", request.full_url)
        self.assertEqual(request.headers["Authorization"], "Token secret")
        self.assertNotIn("secret", request.data.decode("utf-8"))


if __name__ == "__main__":
    unittest.main()
