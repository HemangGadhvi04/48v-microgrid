import json
import pathlib
import sys
import unittest

HARDWARE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARDWARE))

import calculate_pcb_constraints


class PcbConstraintTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.result = calculate_pcb_constraints.calculate(
            calculate_pcb_constraints.load_inputs())

    def test_power_widths_exceed_legacy_screen(self):
        for item in self.result["trace_classes"]:
            with self.subTest(netclass=item["name"]):
                self.assertGreaterEqual(item["selected_to_calculated_margin"], 1.1)

    def test_switch_node_separation_exceeds_general_power(self):
        separation = self.result["separation"]
        self.assertGreater(separation["switch_node_to_analog_mm"],
                           separation["power_to_controller_mm"])

    def test_power_vias_are_not_primary_path(self):
        self.assertFalse(self.result["power_via"]["use_for_primary_current_path"])
        self.assertGreaterEqual(self.result["power_via"]["minimum_parallel_count"], 12)

    def test_result_is_strict_json(self):
        json.dumps(self.result, allow_nan=False)


if __name__ == "__main__":
    unittest.main()
