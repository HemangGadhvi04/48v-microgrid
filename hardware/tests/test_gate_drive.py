import json
import pathlib
import sys
import unittest

HARDWARE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARDWARE))

import calculate_gate_drive


class GateDriveTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = calculate_gate_drive.load_inputs()
        cls.result = calculate_gate_drive.calculate(cls.inputs)

    def test_bootstrap_remains_above_uvlo(self):
        self.assertGreater(self.result["bootstrap_uvlo_margin_v"], 1.0)

    def test_disable_path_is_faster_than_dead_time(self):
        self.assertLess(self.result["maximum_hardware_disable_latency_s"],
                        self.inputs["configured_dead_time_s"])

    def test_integrated_bootstrap_diode_is_recorded(self):
        self.assertTrue(self.result["integrated_bootstrap_diode"])

    def test_safety_chain_has_frozen_parts(self):
        for value in self.result["interlock"].values():
            self.assertTrue(value and value != "TBD")

    def test_result_is_strict_json(self):
        json.dumps(self.result, allow_nan=False)


if __name__ == "__main__":
    unittest.main()
