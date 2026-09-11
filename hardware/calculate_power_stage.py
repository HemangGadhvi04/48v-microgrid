#!/usr/bin/env python3
"""Calculate first-pass electrical and loss requirements for Phase 2."""

import csv
import json
import math
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parent


def load_inputs(path=None):
    source = pathlib.Path(path) if path else ROOT / "design_inputs.json"
    with source.open(encoding="utf-8") as handle:
        return json.load(handle)


def calculate(p):
    power = p["rated_power_w"]
    efficiency = p["assumed_converter_efficiency"]
    fs = p["switching_frequency_hz"]
    inductance = p["dc_inductor_h"]
    corners = []
    for vin in (p["pv_full_power_min_v"], p["pv_max_v"]):
        for vout in (p["dc_bus_min_v"], p["dc_bus_max_v"]):
            if vin >= vout:
                mode = "buck"
                duty = vout / vin
                average_current = power / vout
                ripple = (vin - vout) * duty / (inductance * fs)
            else:
                mode = "boost"
                duty = 1.0 - vin / vout
                average_current = power / (efficiency * vin)
                ripple = vin * duty / (inductance * fs)
            rms_current = math.sqrt(average_current ** 2 + ripple ** 2 / 12.0)
            corners.append({
                "vin_v": vin,
                "vout_v": vout,
                "mode": mode,
                "duty": duty,
                "average_inductor_current_a": average_current,
                "ripple_pp_a": ripple,
                "peak_inductor_current_a": average_current + ripple / 2.0,
                "rms_inductor_current_a": rms_current,
            })
    worst = max(corners, key=lambda row: row["peak_inductor_current_a"])

    current = worst["rms_inductor_current_a"]
    voltage = max(p["pv_max_v"], p["dc_bus_max_v"])
    average_switch_current = worst["average_inductor_current_a"]
    converter_conduction = 2.0 * current ** 2 * p["mosfet_rds_on_hot_ohm"]
    converter_switching = (0.5 * voltage * average_switch_current
                           * p["mosfet_total_rise_fall_s"] * fs * 2.0)
    converter_gate = p["mosfet_gate_charge_c"] * p["gate_drive_voltage_v"] * fs * 2.0
    converter_deadtime = (2.0 * p["body_diode_drop_v"] * average_switch_current
                          * p["dead_time_s"] * fs)
    inductor_copper = current ** 2 * p["dc_inductor_dcr_ohm"]
    converter_total = sum((converter_conduction, converter_switching,
                           converter_gate, converter_deadtime, inductor_copper,
                           p["dc_inductor_core_loss_w"],
                           p["converter_auxiliary_loss_w"]))

    ac_current_rms = power / p["ac_voltage_rms_v"]
    ac_current_peak = math.sqrt(2.0) * ac_current_rms
    ac_average_absolute_current = 2.0 * ac_current_peak / math.pi
    inverter_conduction = 2.0 * ac_current_rms ** 2 * p["mosfet_rds_on_hot_ohm"]
    inverter_switching = (0.5 * p["dc_bus_max_v"] * ac_average_absolute_current
                          * p["mosfet_total_rise_fall_s"] * fs * 4.0)
    inverter_gate = p["mosfet_gate_charge_c"] * p["gate_drive_voltage_v"] * fs * 4.0
    inverter_deadtime = (2.0 * p["body_diode_drop_v"] * ac_average_absolute_current
                         * p["dead_time_s"] * fs)
    lcl_copper = ac_current_rms ** 2 * p["lcl_total_winding_resistance_ohm"]
    inverter_total = sum((inverter_conduction, inverter_switching, inverter_gate,
                          inverter_deadtime, lcl_copper,
                          p["lcl_damping_loss_estimate_w"]))

    omega = 2.0 * math.pi * p["ac_frequency_hz"]
    required_capacitance = power / (omega * p["dc_bus_nominal_v"]
                                    * p["dc_link_ripple_target_pp_v"])
    predicted_ripple = power / (omega * p["dc_bus_nominal_v"]
                                * p["dc_link_capacitance_f"])
    resonant_frequency = (1.0 / (2.0 * math.pi)
                          * math.sqrt((p["lcl_inverter_inductor_h"]
                                       + p["lcl_grid_inductor_h"])
                                      / (p["lcl_inverter_inductor_h"]
                                         * p["lcl_grid_inductor_h"]
                                         * p["lcl_capacitor_f"])))
    precharge_tau = p["precharge_resistor_ohm"] * p["dc_link_capacitance_f"]
    precharge_90_s = -precharge_tau * math.log(0.1)
    precharge_initial_power = p["dc_bus_max_v"] ** 2 / p["precharge_resistor_ohm"]
    stored_energy = 0.5 * p["dc_link_capacitance_f"] * p["dc_bus_max_v"] ** 2
    total_loss = converter_total + inverter_total
    system_efficiency = power / (power + total_loss)

    return {
        "corners": corners,
        "worst_corner": worst,
        "dc_input_current_at_minimum_v_a": power / (efficiency * p["pv_full_power_min_v"]),
        "recommended_inductor_saturation_current_a": 1.3 * worst["peak_inductor_current_a"],
        "converter_losses_w": {
            "mosfet_conduction": converter_conduction,
            "mosfet_switching": converter_switching,
            "gate_drive": converter_gate,
            "dead_time": converter_deadtime,
            "inductor_copper": inductor_copper,
            "inductor_core_estimate": p["dc_inductor_core_loss_w"],
            "auxiliary_estimate": p["converter_auxiliary_loss_w"],
            "total": converter_total,
        },
        "inverter_losses_w": {
            "mosfet_conduction": inverter_conduction,
            "mosfet_switching": inverter_switching,
            "gate_drive": inverter_gate,
            "dead_time": inverter_deadtime,
            "lcl_copper": lcl_copper,
            "damping_estimate": p["lcl_damping_loss_estimate_w"],
            "total": inverter_total,
        },
        "ac_current_rms_a": ac_current_rms,
        "ac_current_peak_a": ac_current_peak,
        "dc_link_required_capacitance_f": required_capacitance,
        "dc_link_predicted_ripple_pp_v": predicted_ripple,
        "dc_link_voltage_rating_margin": p["dc_link_capacitor_voltage_rating_v"] / p["dc_bus_max_v"],
        "mosfet_voltage_rating_margin": p["mosfet_voltage_rating_v"] / voltage,
        "lcl_resonant_frequency_hz": resonant_frequency,
        "precharge_90_percent_s": precharge_90_s,
        "precharge_initial_power_w": precharge_initial_power,
        "dc_link_stored_energy_j": stored_energy,
        "estimated_total_loss_w": total_loss,
        "estimated_system_efficiency": system_efficiency,
    }


def write_outputs(p, result):
    output_dir = ROOT / "results"
    output_dir.mkdir(exist_ok=True)
    with (output_dir / "power_stage_metrics.json").open("w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    with (output_dir / "operating_corners.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=result["corners"][0].keys())
        writer.writeheader()
        writer.writerows(result["corners"])

    c = result["converter_losses_w"]
    i = result["inverter_losses_w"]
    report = f"""# Phase 2 Power-Stage Calculation Report

Generated from `hardware/design_inputs.json` by `hardware/calculate_power_stage.py`.

## Rated operating requirements

| Quantity | Calculated value |
|---|---:|
| Minimum-input full-power DC current | {result['dc_input_current_at_minimum_v_a']:.2f} A |
| Worst inductor peak current | {result['worst_corner']['peak_inductor_current_a']:.2f} A |
| Recommended inductor saturation rating (30% margin) | {result['recommended_inductor_saturation_current_a']:.2f} A |
| Rated AC current | {result['ac_current_rms_a']:.2f} A RMS / {result['ac_current_peak_a']:.2f} A peak |
| Selected DC-link capacitance | {1000*p['dc_link_capacitance_f']:.1f} mF |
| Minimum capacitance for {p['dc_link_ripple_target_pp_v']:.1f} V p-p 100 Hz ripple | {1000*result['dc_link_required_capacitance_f']:.1f} mF |
| Predicted ideal 100 Hz bus ripple | {result['dc_link_predicted_ripple_pp_v']:.2f} V p-p |
| LCL resonance | {result['lcl_resonant_frequency_hz']:.1f} Hz |
| MOSFET voltage-rating margin | {result['mosfet_voltage_rating_margin']:.2f}x |
| Capacitor voltage-rating margin | {result['dc_link_voltage_rating_margin']:.2f}x |

## First-pass hot loss estimate

| Loss term | DC-DC | Inverter |
|---|---:|---:|
| MOSFET conduction | {c['mosfet_conduction']:.2f} W | {i['mosfet_conduction']:.2f} W |
| MOSFET switching | {c['mosfet_switching']:.2f} W | {i['mosfet_switching']:.2f} W |
| Gate drive | {c['gate_drive']:.2f} W | {i['gate_drive']:.2f} W |
| Dead time | {c['dead_time']:.2f} W | {i['dead_time']:.2f} W |
| Magnetics copper | {c['inductor_copper']:.2f} W | {i['lcl_copper']:.2f} W |
| Core/damping estimate | {c['inductor_core_estimate']:.2f} W | {i['damping_estimate']:.2f} W |
| Auxiliary estimate | {c['auxiliary_estimate']:.2f} W | included later |
| **Stage total** | **{c['total']:.2f} W** | **{i['total']:.2f} W** |

The combined first-pass loss is {result['estimated_total_loss_w']:.2f} W, giving
an estimated {100*result['estimated_system_efficiency']:.2f}% electrical efficiency.
This is a sizing estimate. Calorimetric or input/output power measurements must
replace it before Phase 2 can close.

## Precharge

With {1000*p['dc_link_capacitance_f']:.1f} mF and {p['precharge_resistor_ohm']:.0f} ohm,
the bus reaches 90% in {result['precharge_90_percent_s']:.2f} s. Initial resistor
power is {result['precharge_initial_power_w']:.1f} W and maximum stored DC-link
energy is {result['dc_link_stored_energy_j']:.2f} J. The resistor therefore needs
a verified pulse-energy curve; its printed wattage alone is insufficient.

## Model boundaries

The switching estimate uses overlap time and average commutation current. It
does not include measured parasitic ringing, reverse recovery, PCB resistance,
temperature-dependent magnetics, capacitor ESR, control-supply efficiency, or
fan power. The reference MOSFET's hot resistance is represented by the explicit
input value rather than its 25 degree headline value.
"""
    (output_dir / "power_stage_report.md").write_text(report, encoding="utf-8")


def main():
    parameters = load_inputs(sys.argv[1] if len(sys.argv) > 1 else None)
    result = calculate(parameters)
    write_outputs(parameters, result)
    print(f"Worst DC-inductor peak: {result['worst_corner']['peak_inductor_current_a']:.2f} A")
    print(f"Estimated combined efficiency: {100*result['estimated_system_efficiency']:.2f}%")
    print(f"Artifacts written to {ROOT / 'results'}")


if __name__ == "__main__":
    main()
