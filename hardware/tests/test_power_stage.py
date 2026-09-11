import json
import pathlib
import sys
import unittest

HARDWARE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARDWARE))

import calculate_power_stage


class PowerStageDesignTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parameters = calculate_power_stage.load_inputs()
        cls.result = calculate_power_stage.calculate(cls.parameters)

    def test_all_voltage_corners_are_covered(self):
        modes = {corner["mode"] for corner in self.result["corners"]}
        self.assertEqual(modes, {"buck", "boost"})
        self.assertEqual(len(self.result["corners"]), 4)

    def test_current_and_voltage_ratings_have_margin(self):
        self.assertLess(self.result["worst_corner"]["peak_inductor_current_a"], 18.0)
        self.assertLess(self.result["recommended_inductor_saturation_current_a"], 25.0)
        self.assertGreaterEqual(self.result["mosfet_voltage_rating_margin"], 1.5)
        self.assertGreaterEqual(self.result["dc_link_voltage_rating_margin"], 1.4)

    def test_dc_link_meets_ripple_target(self):
        self.assertGreaterEqual(
            self.parameters["dc_link_capacitance_f"],
            self.result["dc_link_required_capacitance_f"],
        )
        self.assertLessEqual(
            self.result["dc_link_predicted_ripple_pp_v"],
            self.parameters["dc_link_ripple_target_pp_v"],
        )

    def test_lcl_resonance_is_between_grid_and_switching_bands(self):
        resonance = self.result["lcl_resonant_frequency_hz"]
        self.assertGreater(resonance, 10.0 * self.parameters["ac_frequency_hz"])
        self.assertLess(resonance, 0.5 * self.parameters["switching_frequency_hz"])

    def test_estimate_is_finite_and_plausible(self):
        self.assertGreater(self.result["estimated_system_efficiency"], 0.94)
        self.assertLess(self.result["estimated_system_efficiency"], 1.0)
        json.dumps(self.result, allow_nan=False)


if __name__ == "__main__":
    unittest.main()
