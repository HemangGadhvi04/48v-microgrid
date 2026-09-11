#!/usr/bin/env python3
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ROWS = list(csv.DictReader((ROOT / "pin_allocation.csv").open()))
required = {
    "dc_dc_input_high", "dc_dc_input_low", "dc_dc_output_high",
    "dc_dc_output_low", "inverter_leg_a_high", "inverter_leg_a_low",
    "inverter_leg_b_high", "inverter_leg_b_low", "trip_latch_n", "estop_n",
    "precharge_relay", "main_contactor", "grid_breaker", "pwm_arm",
    "bias_power_good", "rs485_rx", "rs485_tx", "rs485_driver_enable",
    "isr_timing_marker", "pv_voltage", "dc_bus_voltage", "pv_current",
    "dc_inductor_current", "grid_voltage", "utility_voltage", "grid_current",
    "heatsink_temperature",
}
names = {row["function"] for row in ROWS}
assert names == required, (required - names, names - required)
physical = [(row["launchpad_header"], row["pin"]) for row in ROWS]
assert len(physical) == len(set(physical)), "duplicate physical header pin"
assert len([row for row in ROWS if row["peripheral"].startswith("ADC")]) == 8
assert len([row for row in ROWS if row["peripheral"].startswith("ePWM")]) == 8
assert next(row for row in ROWS if row["function"] == "trip_latch_n")["peripheral"] == "INPUTXBAR1"
header = ROOT / "generated" / "c2000_pinmap.h"
gpio_rows = [row for row in ROWS if row["gpio_or_channel"].startswith("GPIO")]
lines = ["#ifndef MG_C2000_PINMAP_H", "#define MG_C2000_PINMAP_H", ""]
for row in gpio_rows:
    macro = "MG_GPIO_" + row["function"].upper()
    lines.append(f"#define {macro} ({row['gpio_or_channel'][4:]}u)")
lines += ["", "#endif", ""]
header.write_text("\n".join(lines))
print(f"Validated {len(ROWS)} assignments: 8 PWM, 8 ADC, {len(gpio_rows)} GPIO-routed")
