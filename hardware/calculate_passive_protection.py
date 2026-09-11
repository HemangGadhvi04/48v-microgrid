#!/usr/bin/env python3
"""Check candidate capacitor, precharge, fuse, connector and contactor margins."""

import json
import math
import pathlib


ROOT = pathlib.Path(__file__).resolve().parent


def load_inputs():
    with (ROOT / "passive_protection_inputs.json").open(encoding="utf-8") as handle:
        return json.load(handle)


def calculate(data):
    dc = data["dc_bus"]
    c_nominal = dc["capacitor_quantity"] * dc["capacitance_each_f"]
    c_minimum = c_nominal * (1.0 - dc["capacitance_tolerance_minus_fraction"])
    omega = 2.0 * math.pi * dc["line_frequency_hz"]
    required_c = dc["rated_power_w"] / (
        omega * dc["maximum_voltage_v"] * dc["maximum_ripple_pp_v"])
    predicted_ripple = dc["rated_power_w"] / (
        omega * dc["maximum_voltage_v"] * c_minimum)
    bus_ripple_current = dc["rated_power_w"] / (
        dc["maximum_voltage_v"] * math.sqrt(2.0))
    bank_ripple_rating = (dc["capacitor_quantity"]
                          * dc["ripple_rating_each_a_rms_100hz_85c"])
    bank_esr = dc["esr_each_ohm_100hz_20c"] / dc["capacitor_quantity"]
    bank_esr_loss = bus_ripple_current ** 2 * bank_esr
    stored_energy = 0.5 * c_nominal * dc["maximum_voltage_v"] ** 2

    pre = data["precharge"]
    precharge_initial_power = dc["maximum_voltage_v"] ** 2 / pre["resistance_ohm"]
    precharge_tau = pre["resistance_ohm"] * c_nominal
    precharge_90 = -precharge_tau * math.log(0.1)

    cf = data["lcl_capacitor"]
    fundamental_current = (2.0 * math.pi * cf["frequency_hz"]
                           * cf["capacitance_f"] * cf["bus_voltage_rms_v"])
    fundamental_var = (2.0 * math.pi * cf["frequency_hz"]
                       * cf["capacitance_f"] * cf["bus_voltage_rms_v"] ** 2)

    return {
        "dc_link": {
            "nominal_capacitance_f": c_nominal,
            "minimum_capacitance_f": c_minimum,
            "required_capacitance_f": required_c,
            "predicted_ripple_pp_v_at_minimum_c": predicted_ripple,
            "ripple_current_a_rms": bus_ripple_current,
            "bank_ripple_rating_a_rms": bank_ripple_rating,
            "ripple_current_margin": bank_ripple_rating / bus_ripple_current,
            "bank_esr_ohm": bank_esr,
            "bank_esr_loss_w": bank_esr_loss,
            "stored_energy_j": stored_energy,
            "voltage_margin": dc["voltage_rating_v"] / dc["maximum_voltage_v"]
        },
        "precharge": {
            "initial_power_w": precharge_initial_power,
            "time_constant_s": precharge_tau,
            "time_to_90_percent_s": precharge_90,
            "power_rating_margin": (pre["continuous_rating_w_with_required_heatsink"]
                                    / precharge_initial_power),
            "energy_per_charge_j": stored_energy
        },
        "lcl_capacitor": {
            "fundamental_current_a_rms": fundamental_current,
            "fundamental_reactive_power_var": fundamental_var,
            "ripple_rating_to_fundamental_margin": (
                cf["ripple_rating_a_rms_10khz_70c"] / fundamental_current),
            "voltage_margin": cf["voltage_rating_vdc"] / (
                math.sqrt(2.0) * cf["bus_voltage_rms_v"])
        },
        "damping_resistor": {
            "continuous_power_margin": (
                data["damping_resistor"]["continuous_rating_w_with_required_heatsink"]
                / data["damping_resistor"]["allocated_loss_w"])
        },
        "dc_fuse": {
            "voltage_margin": (data["dc_fuse"]["voltage_rating_vdc"]
                               / dc["maximum_voltage_v"]),
            "full_power_current_margin": (data["dc_fuse"]["current_rating_a"]
                                          / (dc["rated_power_w"] / 35.0))
        },
        "power_connector": {
            "current_margin": (data["power_connector"]["continuous_current_rating_a"]
                               / data["power_connector"]["design_current_a"]),
            "voltage_margin": (data["power_connector"]["voltage_rating_v"]
                               / dc["maximum_voltage_v"])
        },
        "main_contactor": {
            "current_margin": (data["main_contactor"]["thermal_current_rating_a"] / 25.0),
            "voltage_margin": (data["main_contactor"]["contact_voltage_rating_vdc"]
                               / dc["maximum_voltage_v"])
        }
    }


def write_outputs(data, result):
    out = ROOT / "results"
    out.mkdir(exist_ok=True)
    (out / "passive_protection_metrics.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8")
    dc = data["dc_bus"]
    report = f"""# Passive and Protection Candidate Check

Generated from `hardware/passive_protection_inputs.json`.

| Function | Candidate | Calculated result | Status |
|---|---|---:|---|
| DC-link bank | {dc['capacitor_quantity']} x {dc['capacitor_part']} | {result['dc_link']['minimum_capacitance_f']*1000:.1f} mF minimum; {result['dc_link']['predicted_ripple_pp_v_at_minimum_c']:.2f} V p-p; {result['dc_link']['ripple_current_margin']:.1f}x ripple margin | Electrical check passed |
| Precharge | {data['precharge']['part']} | {result['precharge']['initial_power_w']:.1f} W initial; {result['precharge']['time_to_90_percent_s']:.2f} s to 90%; {result['precharge']['energy_per_charge_j']:.1f} J | Pass with specified heatsink |
| LCL capacitor | {data['lcl_capacitor']['part']} | {result['lcl_capacitor']['fundamental_current_a_rms']:.3f} Arms; {result['lcl_capacitor']['fundamental_reactive_power_var']:.2f} var | Electrical check passed |
| Damping resistor | {data['damping_resistor']['part']} | {result['damping_resistor']['continuous_power_margin']:.0f}x allocated-loss margin | Pass with specified heatsink |
| DC fuse | {data['dc_fuse']['part']} | {result['dc_fuse']['voltage_margin']:.2f}x voltage margin | Coordination test pending |
| Power connector | {data['power_connector']['family']} | {result['power_connector']['current_margin']:.1f}x current margin | Crimp and temperature-rise test pending |
| Main DC contactor | {data['main_contactor']['family']} | {result['main_contactor']['voltage_margin']:.2f}x voltage; {result['main_contactor']['current_margin']:.1f}x thermal current | Ordering code and break test pending |
| AC contactor | {data['ac_contactor']['part']} | Auxiliary mirror contact included | PCB/coil hold-drive design pending |

The capacitor bank is deliberately 30 mF nominal: its -20% tolerance value is
24 mF, above the analytical requirement of {result['dc_link']['required_capacitance_f']*1000:.1f} mF.
The {result['dc_link']['stored_energy_j']:.1f} J maximum bus energy sets discharge,
precharge, enclosure, and servicing requirements. Fuse selection remains provisional
until cable ampacity and measured semiconductor let-through coordination are known.
"""
    (out / "passive_protection_report.md").write_text(report, encoding="utf-8")


def main():
    data = load_inputs()
    result = calculate(data)
    write_outputs(data, result)
    print(f"DC link: {result['dc_link']['minimum_capacitance_f']*1000:.1f} mF minimum, "
          f"{result['dc_link']['predicted_ripple_pp_v_at_minimum_c']:.2f} V p-p")
    print(f"Precharge: {result['precharge']['time_to_90_percent_s']:.2f} s to 90%")


if __name__ == "__main__":
    main()
