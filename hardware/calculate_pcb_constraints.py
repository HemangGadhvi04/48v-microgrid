#!/usr/bin/env python3
"""Check preliminary PCB current, separation, and placement constraints."""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent


def load_inputs():
    return json.loads((ROOT / "pcb_constraints.json").read_text(encoding="utf-8"))


def ipc2221_external_width_mm(current_a, copper_um, rise_c):
    """Return IPC-2221 external-conductor width using its legacy equation."""
    area_mil2 = (current_a / (0.048 * rise_c ** 0.44)) ** (1.0 / 0.725)
    thickness_mil = copper_um / 25.4
    return area_mil2 / thickness_mil * 0.0254


def calculate(data):
    board = data["board"]
    classes = []
    for item in data["trace_classes"]:
        calculated = ipc2221_external_width_mm(
            item["design_current_a"], board["outer_copper_thickness_um"],
            board["maximum_external_trace_temperature_rise_c"])
        classes.append({
            **item,
            "ipc2221_external_width_mm": calculated,
            "selected_to_calculated_margin": item["minimum_width_mm"] / calculated
        })
    return {"board": board, "trace_classes": classes,
            "separation": data["separation"], "power_via": data["power_via"],
            "placement": data["placement"]}


def write_outputs(result):
    out = ROOT / "results"
    out.mkdir(exist_ok=True)
    (out / "pcb_constraint_metrics.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8")
    rows = []
    for item in result["trace_classes"]:
        current = (f"{item['design_current_a']:.2f} A"
                   + (f" ({item['peak_pulse_current_a']:.1f} A pulse)"
                      if "peak_pulse_current_a" in item else ""))
        rows.append(f"| {item['name']} | {current} | "
                    f"{item['ipc2221_external_width_mm']:.2f} mm | "
                    f"{item['minimum_width_mm']:.2f} mm | "
                    f"{item['selected_to_calculated_margin']:.2f}x |")
    report = f"""# PCB Constraint Baseline

The first prototype uses four layers with 70 um outer copper and 35 um inner
copper. High-current switching loops stay on the outer layers as copper pours or
bus structures. They are not permitted to depend on plated vias as their primary
current path.

| Class | Design current | IPC-2221 external width at 20 C rise | Selected minimum | Margin |
|---|---:|---:|---:|---:|
{chr(10).join(rows)}

The legacy IPC-2221 equation is used only as a conservative pre-layout screen.
Final temperature rise requires the fabricator's stackup, actual polygon geometry,
connector transitions, and thermal test data.

## Mandatory placement and separation

- Keep switch-node copper at least {result['separation']['switch_node_to_analog_mm']:.1f} mm from analog sensing.
- Keep power copper at least {result['separation']['power_to_controller_mm']:.1f} mm from controller routing.
- Preserve {result['separation']['isolated_rs485_barrier_mm']:.1f} mm across the isolated RS-485 barrier.
- Keep power copper {result['separation']['board_edge_to_power_copper_mm']:.1f} mm from the board edge.
- Place each driver within {result['placement']['driver_to_mosfet_gate_max_mm']:.0f} mm of its MOSFET gates and each bootstrap/commutation loop within {result['placement']['bootstrap_loop_max_mm']:.0f} mm.
- If a power-layer transition cannot be avoided, use at least {result['power_via']['minimum_parallel_count']} vias with {result['power_via']['finished_drill_mm']:.1f} mm finished drill and validate the transition thermally.
"""
    (out / "pcb_constraints_report.md").write_text(report, encoding="utf-8")


def main():
    result = calculate(load_inputs())
    write_outputs(result)
    for item in result["trace_classes"][:2]:
        print(f"{item['name']}: {item['minimum_width_mm']:.1f} mm selected, "
              f"{item['selected_to_calculated_margin']:.2f}x legacy margin")


if __name__ == "__main__":
    main()
