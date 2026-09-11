import json
import pathlib
import sys
import unittest

HARDWARE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARDWARE))

import calculate_magnetics_thermal


class MagneticsThermalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        inputs, metrics = calculate_magnetics_thermal.load_inputs()
        cls.result = calculate_magnetics_thermal.calculate(inputs, metrics)

    def test_every_winding_meets_screen(self):
        self.assertTrue(self.result["all_pass_screen"])
        for row in self.result["inductors"]:
            with self.subTest(inductor=row["name"]):
                self.assertLessEqual(row["dcr_ohm"], row["maximum_dcr_ohm"])
                self.assertLessEqual(row["effective_window_fill"], 0.40)
                self.assertLessEqual(row["estimated_temperature_rise_c"], 40.0)

    def test_dcr_can_increase_strand_count(self):
        self.assertTrue(any(
            row["minimum_strands_by_dcr"] > row["minimum_strands_by_current_density"]
            for row in self.result["inductors"]
        ))

    def test_result_is_strict_json(self):
        json.dumps(self.result, allow_nan=False)


if __name__ == "__main__":
    unittest.main()
