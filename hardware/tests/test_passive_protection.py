import json
import pathlib
import sys
import unittest

HARDWARE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARDWARE))

import calculate_passive_protection


class PassiveProtectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = calculate_passive_protection.load_inputs()
        cls.result = calculate_passive_protection.calculate(cls.inputs)

    def test_capacitor_tolerance_still_meets_ripple_limit(self):
        dc = self.result["dc_link"]
        self.assertGreaterEqual(dc["minimum_capacitance_f"], dc["required_capacitance_f"])
        self.assertLessEqual(dc["predicted_ripple_pp_v_at_minimum_c"],
                             self.inputs["dc_bus"]["maximum_ripple_pp_v"])

    def test_capacitor_ripple_and_voltage_have_margin(self):
        self.assertGreater(self.result["dc_link"]["ripple_current_margin"], 2.0)
        self.assertGreater(self.result["dc_link"]["voltage_margin"], 1.5)

    def test_precharge_never_exceeds_continuous_resistor_rating(self):
        self.assertGreaterEqual(self.result["precharge"]["power_rating_margin"], 1.0)

    def test_series_components_meet_basic_ratings(self):
        self.assertGreaterEqual(self.result["dc_fuse"]["voltage_margin"], 2.0)
        self.assertGreaterEqual(self.result["power_connector"]["current_margin"], 2.0)
        self.assertGreaterEqual(self.result["main_contactor"]["voltage_margin"], 1.5)

    def test_result_is_strict_json(self):
        json.dumps(self.result, allow_nan=False)


if __name__ == "__main__":
    unittest.main()
