import json
import math
import pathlib
import sys
import unittest

HARDWARE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARDWARE))

import calculate_magnetics


class MagneticsRequirementsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs = calculate_magnetics.load_inputs()
        cls.result = calculate_magnetics.calculate(cls.inputs)

    def test_all_three_inductors_are_present(self):
        self.assertEqual({row["name"] for row in self.result["inductors"]},
                         {"LDC", "L1", "L2"})

    def test_preferred_strand_is_below_two_skin_depths(self):
        self.assertLessEqual(
            self.inputs["preferred_round_strand_diameter_mm"],
            self.result["recommended_maximum_round_strand_diameter_mm"],
        )

    def test_turns_hold_flux_below_limit(self):
        limit = self.inputs["maximum_flux_density_t"]
        for row in self.result["inductors"]:
            with self.subTest(inductor=row["name"]):
                self.assertLessEqual(row["predicted_peak_flux_t"], limit)

    def test_bias_curve_delivers_target_inductance(self):
        for row in self.result["inductors"]:
            with self.subTest(inductor=row["name"]):
                self.assertGreaterEqual(row["predicted_inductance_h"],
                                        row["inductance_h"])
                self.assertGreater(row["predicted_al_retention"], 0.3)

    def test_core_loss_estimate_is_finite_and_positive(self):
        for row in self.result["inductors"]:
            with self.subTest(inductor=row["name"]):
                self.assertGreater(row["predicted_core_loss_w"], 0.0)
                self.assertTrue(math.isfinite(row["predicted_core_loss_w"]))

    def test_copper_loss_matches_dcr_limit(self):
        for row in self.result["inductors"]:
            expected = row["rms_current_a"] ** 2 * row["maximum_dcr_ohm"]
            self.assertAlmostEqual(row["copper_loss_at_maximum_dcr_w"], expected)

    def test_result_is_strict_json(self):
        json.dumps(self.result, allow_nan=False)


if __name__ == "__main__":
    unittest.main()
