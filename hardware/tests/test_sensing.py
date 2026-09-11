import json
import pathlib
import sys
import unittest

HARDWARE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARDWARE))

import calculate_sensing


class SensingDesignTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = calculate_sensing.load_inputs()
        cls.result = calculate_sensing.calculate(cls.inputs)

    def test_every_channel_stays_inside_adc_rails(self):
        for channel in self.result["channels"]:
            with self.subTest(channel=channel["name"]):
                self.assertGreaterEqual(channel["adc_at_min_v"], 0.1)
                self.assertLessEqual(channel["adc_at_max_v"], 3.2)

    def test_resolution_meets_control_needs(self):
        limits = {"V": 0.05, "A": 0.03, "degC": 0.1}
        for channel in self.result["channels"]:
            with self.subTest(channel=channel["name"]):
                self.assertLess(channel["plant_units_per_count"], limits[channel["unit"]])

    def test_filter_is_above_control_band_and_below_nyquist(self):
        cutoff = self.result["anti_alias_cutoff_hz"]
        self.assertGreater(cutoff, 5000.0)
        self.assertLess(cutoff, 100000.0)

    def test_result_is_strict_json(self):
        json.dumps(self.result, allow_nan=False)

    def test_exact_current_sensor_matches_channel_scaling(self):
        sensor = self.result["current_sensor"]
        self.assertEqual(sensor["part_number"], "TMCS1123B2AQDVGRQ1")
        self.assertEqual(sensor["sensitivity_v_per_a"], 0.05)
        for channel in self.result["channels"]:
            if channel["name"] in sensor["design_rms_current_a"]:
                self.assertEqual(channel["adc_gain_v_per_unit"], sensor["sensitivity_v_per_a"])
                self.assertLessEqual(abs(channel["plant_min"]), sensor["linear_range_a"])
                self.assertLessEqual(abs(channel["plant_max"]), sensor["linear_range_a"])

    def test_current_sensor_trip_and_losses(self):
        sensor = self.result["current_sensor"]
        self.assertAlmostEqual(sensor["voc_setting_v"], 0.6)
        self.assertLessEqual(sensor["overcurrent_response_max_s"], 250e-9)
        self.assertLess(sensor["maximum_conductor_loss_w"], 0.25)


if __name__ == "__main__":
    unittest.main()
