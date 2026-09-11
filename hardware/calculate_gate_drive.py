#!/usr/bin/env python3
"""Calculate bootstrap, timing, and independent PWM-disable margins."""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent


def load_inputs():
    with (ROOT / "gate_drive_inputs.json").open(encoding="utf-8") as handle:
        return json.load(handle)


def calculate(data):
    period = 1.0 / data["switching_frequency_hz"]
    maximum_on_time = period * data["maximum_high_side_duty"]
    required_charge = (data["mosfet_gate_charge_c"]
                       + data["bootstrap_driver_current_a_max"] * maximum_on_time)
    minimum_capacitance = (data["bootstrap_capacitance_f"]
                           * (1.0 - data["bootstrap_capacitance_tolerance_minus_fraction"]))
    droop = required_charge / minimum_capacitance
    minimum_boot_voltage = (data["gate_drive_voltage_v"]
                            - data["bootstrap_diode_forward_voltage_v_max"] - droop)
    dead_time_margin = (data["configured_dead_time_s"]
                        - data["driver_delay_mismatch_s_max"])
    disable_latency = data["hardware_logic_delay_s_max"] + data["driver_fall_delay_s_max"]
    return {
        "switching_period_s": period,
        "maximum_high_side_on_time_s": maximum_on_time,
        "bootstrap_required_charge_c": required_charge,
        "bootstrap_minimum_capacitance_f": minimum_capacitance,
        "bootstrap_worst_case_droop_v": droop,
        "bootstrap_minimum_voltage_v": minimum_boot_voltage,
        "bootstrap_uvlo_margin_v": minimum_boot_voltage - data["bootstrap_uvlo_rising_v_max"],
        "gate_charge_power_per_half_bridge_w": (2.0 * data["mosfet_gate_charge_c"]
                                                 * data["gate_drive_voltage_v"]
                                                 * data["switching_frequency_hz"]),
        "dead_time_after_worst_driver_delay_s": dead_time_margin,
        "maximum_hardware_disable_latency_s": disable_latency,
        "integrated_bootstrap_diode": True,
        "interlock": data["interlock"]
    }


def write_outputs(data, result):
    out = ROOT / "results"
    out.mkdir(exist_ok=True)
    (out / "gate_drive_metrics.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8")
    report = f"""# Gate Drive and Hardware Interlock Check

Generated from `hardware/gate_drive_inputs.json`.

Four UCC27211A half-bridge drivers use their internal 120 V bootstrap diodes.
Each external HB-to-HS capacitor is 100 nF, 5%, and each VDD-to-VSS local
decoupler is 4.7 uF. At 98% maximum high-side duty, the conservative charge
budget predicts {result['bootstrap_worst_case_droop_v']:.2f} V droop and
{result['bootstrap_minimum_voltage_v']:.2f} V minimum bootstrap voltage,
{result['bootstrap_uvlo_margin_v']:.2f} V above the maximum rising UVLO threshold.

| Check | Result |
|---|---:|
| Gate-charge power per half bridge | {result['gate_charge_power_per_half_bridge_w']:.3f} W |
| Maximum hardware-disable latency | {result['maximum_hardware_disable_latency_s']*1e9:.0f} ns |
| Minimum dead time after worst delay mismatch | {result['dead_time_after_worst_driver_delay_s']*1e9:.0f} ns |

`SN74HCS21QPWRQ1` combines `PWM_ARM`, `ESTOP_N`, `TRIP_LATCH_N`, and
`BIAS_POWER_GOOD` into the shared safety enable. Two `SN74LVC08AQPWRG4Q1`
devices gate the eight raw PWM channels with that enable. A
`SN74HCS02QPWRQ1` implements the asynchronous set/reset trip latch; reset is
permitted only from the manual reset input while all fault inputs are inactive.
The logic is powered from the supervised 3.3 V safety rail and its outputs have
10 kohm pulldowns at every driver input, so unpowered or false enable states
command both UCC27211A outputs low.

The calculation establishes component and static timing feasibility. Double-pulse
testing must still tune gate resistance and confirm switch-node overshoot,
false-turn-on immunity, and actual dead time at temperature.
"""
    (out / "gate_drive_report.md").write_text(report, encoding="utf-8")


def main():
    data = load_inputs()
    result = calculate(data)
    write_outputs(data, result)
    print(f"Bootstrap minimum {result['bootstrap_minimum_voltage_v']:.2f} V; "
          f"UVLO margin {result['bootstrap_uvlo_margin_v']:.2f} V")
    print(f"Hardware disable <= {result['maximum_hardware_disable_latency_s']*1e9:.0f} ns")


if __name__ == "__main__":
    main()
