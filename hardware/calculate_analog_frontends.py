#!/usr/bin/env python3
"""Calculate exact voltage and temperature analog front-end ranges."""

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load_inputs():
    return json.loads((ROOT / "analog_frontend_inputs.json").read_text())


def calculate(data):
    dc = data["dc_voltage_channels"]
    total_dc_r = dc["input_top_resistance_ohm"] + dc["input_bottom_resistance_ohm"]
    dc_gain = dc["input_bottom_resistance_ohm"] / total_dc_r
    dc_offset = dc["bottom_reference_v"] * dc["input_top_resistance_ohm"] / total_dc_r
    dc_rows = {}
    for name, limits in dc["channels"].items():
        dc_rows[name] = {
            **limits,
            "gain_v_per_v": dc_gain,
            "offset_v": dc_offset,
            "adc_min_v": dc_offset + dc_gain * limits["minimum_v"],
            "adc_max_v": dc_offset + dc_gain * limits["maximum_v"],
            "divider_power_at_max_w": limits["maximum_v"] ** 2 / total_dc_r,
        }

    ac = data["isolated_ac_voltage_channels"]
    ac_divider_gain = ac["shunt_resistance_ohm"] / (
        ac["line_resistance_ohm"] + ac["shunt_resistance_ohm"]
    )
    ac_system_gain = (
        ac_divider_gain * ac["isolator_gain"] * ac["difference_amplifier_gain"]
    )
    ac_input_peak = max(abs(ac["minimum_v"]), abs(ac["maximum_v"])) * ac_divider_gain
    ac_low = ac["adc_center_v"] + ac_system_gain * ac["minimum_v"]
    ac_high = ac["adc_center_v"] + ac_system_gain * ac["maximum_v"]

    temp = data["temperature_channel"]
    filter_rc = data["output_filter_resistance_ohm"] * data["output_filter_capacitance_f"]
    return {
        "dc_voltage_channels": dc_rows,
        "isolated_ac_voltage": {
            "divider_gain": ac_divider_gain,
            "system_gain_v_per_v": ac_system_gain,
            "isolator_input_peak_v": ac_input_peak,
            "isolator_input_limit_v": ac["isolator_input_limit_v"],
            "adc_min_v": ac_low,
            "adc_max_v": ac_high,
            "divider_power_at_peak_w": max(abs(ac["minimum_v"]), abs(ac["maximum_v"])) ** 2
            / (ac["line_resistance_ohm"] + ac["shunt_resistance_ohm"]),
        },
        "temperature": {
            "adc_min_v": temp["offset_v"] + temp["gain_v_per_c"] * temp["minimum_c"],
            "adc_max_v": temp["offset_v"] + temp["gain_v_per_c"] * temp["maximum_c"],
            "gain_v_per_c": temp["gain_v_per_c"],
            "offset_v": temp["offset_v"],
        },
        "output_filter_cutoff_hz": 1.0 / (2.0 * math.pi * filter_rc),
    }


def write_outputs(data, result):
    results = ROOT / "results"
    (results / "analog_frontend_metrics.json").write_text(
        json.dumps(result, indent=2) + "\n"
    )
    dc = result["dc_voltage_channels"]
    ac = result["isolated_ac_voltage"]
    temp = result["temperature"]
    report = f"""# Analog Front-End Design

The PV and DC-bus dividers use {data['dc_voltage_channels']['part_number']}
buffers. A 200 kohm / 10 kohm divider referenced to 105 mV produces a nominal
100 mV live-zero offset and {next(iter(dc.values()))['gain_v_per_v']:.9f} V/V gain.

| Channel | Plant range | ADC range | Divider loss at maximum |
|---|---:|---:|---:|
| PV voltage | 0 to 65 V | {dc['pv_voltage']['adc_min_v']:.3f} to {dc['pv_voltage']['adc_max_v']:.3f} V | {dc['pv_voltage']['divider_power_at_max_w']*1000:.2f} mW |
| DC bus voltage | 0 to 60 V | {dc['dc_bus_voltage']['adc_min_v']:.3f} to {dc['dc_bus_voltage']['adc_max_v']:.3f} V | {dc['dc_bus_voltage']['divider_power_at_max_w']*1000:.2f} mW |

The PCC and utility channels use {data['isolated_ac_voltage_channels']['isolator_part_number']}
reinforced isolated amplifiers followed by
{data['isolated_ac_voltage_channels']['adc_driver_part_number']} differential-to-single-ended
drivers. The 498 kohm / 10 kohm divider limits the isolator input to
{ac['isolator_input_peak_v']:.3f} V at +/-45 V. Overall gain is
{ac['system_gain_v_per_v']:.9f} V/V and the ADC range is
{ac['adc_min_v']:.3f} to {ac['adc_max_v']:.3f} V.

The heatsink channel uses {data['temperature_channel']['part_number']};
-20 to 125 C maps to {temp['adc_min_v']:.3f} to {temp['adc_max_v']:.3f} V.
All ADC paths retain the 1 kohm / 4.7 nF output filter
({result['output_filter_cutoff_hz']/1000:.2f} kHz).
"""
    (results / "analog_frontend_report.md").write_text(report)


def main():
    data = load_inputs()
    result = calculate(data)
    write_outputs(data, result)
    print("Calculated DC, isolated AC, and temperature front ends")


if __name__ == "__main__":
    main()
