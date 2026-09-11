import json
import pathlib
import sys
import unittest

HARDWARE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARDWARE))

import calculate_analog_frontends


class AnalogFrontendTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = calculate_analog_frontends.load_inputs()
        cls.result = calculate_analog_frontends.calculate(cls.inputs)

    def test_all_adc_ranges_have_rail_margin(self):
        ranges = list(self.result["dc_voltage_channels"].values())
        ranges += [self.result["isolated_ac_voltage"], self.result["temperature"]]
        for row in ranges:
            self.assertGreaterEqual(row["adc_min_v"], 0.1)
            self.assertLessEqual(row["adc_max_v"], 3.2)

    def test_isolator_input_stays_inside_one_volt(self):
        ac = self.result["isolated_ac_voltage"]
        self.assertLess(ac["isolator_input_peak_v"], ac["isolator_input_limit_v"])

    def test_divider_dissipation_is_small(self):
        for row in self.result["dc_voltage_channels"].values():
            self.assertLess(row["divider_power_at_max_w"], 0.025)
        self.assertLess(self.result["isolated_ac_voltage"]["divider_power_at_peak_w"], 0.01)

    def test_result_is_strict_json(self):
        json.dumps(self.result, allow_nan=False)

    def test_isolator_release_connections_are_complete(self):
        ac = self.result["isolated_ac_voltage"]
        self.assertEqual(set(ac["required_pin_connections"]), {
            "DCDC_OUT-HLDO_IN", "DCDC_HGND-HGND", "LDO_OUT-DCDC_IN",
            "DCDC_GND-GND", "INN-HGND",
        })
        self.assertEqual(set(ac["required_decoupling"]), {
            "VDD_GND", "DCDC_IN_DCDC_GND", "DCDC_OUT_DCDC_HGND",
            "HLDO_OUT_HGND", "INP_INN",
        })
        self.assertIn("DIAG", ac["diagnostic_output"])


if __name__ == "__main__":
    unittest.main()
