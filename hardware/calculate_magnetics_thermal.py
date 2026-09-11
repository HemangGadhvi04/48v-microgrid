#!/usr/bin/env python3
"""Size magnetics conductors and screen winding/thermal feasibility."""

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load_inputs():
    return (
        json.loads((ROOT / "magnetics_inputs.json").read_text()),
        json.loads((ROOT / "results" / "magnetics_metrics.json").read_text()),
    )


def calculate(inputs, metrics):
    rho_100c = 2.3e-5  # ohm mm2/mm
    window_per_pair_mm2 = 411.0
    packing_factor = 0.70
    strand_area_mm2 = metrics["preferred_strand_copper_area_mm2"]
    requirements = {row["name"]: row for row in inputs["inductors"]}
    rows = []
    for magnetic in metrics["inductors"]:
        requirement = requirements[magnetic["name"]]
        cores = magnetic["core_count"]
        turns = magnetic["analysis_turns"]
        mlt_mm = 2 * 20.0 + 2 * 27.4 * cores + 31.4
        dcr_strands = math.ceil(
            rho_100c * mlt_mm * turns
            / (requirement["maximum_dcr_ohm"] * strand_area_mm2)
        )
        strands = max(magnetic["minimum_parallel_strands"], dcr_strands)
        copper_area = strands * strand_area_mm2
        dcr = rho_100c * mlt_mm * turns / copper_area
        copper_loss = requirement["rms_current_a"] ** 2 * dcr
        core_loss = magnetic["predicted_core_loss_w"]
        total_loss = copper_loss + core_loss
        fill = turns * copper_area / (window_per_pair_mm2 * cores * packing_factor)
        surface_cm2 = 140.0 + (cores - 1) * 50.0
        rise_c = ((total_loss * 1000.0) / surface_cm2) ** 0.833
        passes = (
            dcr <= requirement["maximum_dcr_ohm"]
            and fill <= 0.40
            and rise_c <= 40.0
        )
        rows.append({
            "name": magnetic["name"], "core_count": cores, "turns": turns,
            "minimum_strands_by_current_density": magnetic["minimum_parallel_strands"],
            "minimum_strands_by_dcr": dcr_strands,
            "selected_strands": strands, "mlt_mm": mlt_mm,
            "dcr_ohm": dcr, "maximum_dcr_ohm": requirement["maximum_dcr_ohm"],
            "copper_loss_w": copper_loss, "core_loss_w": core_loss,
            "total_loss_w": total_loss, "effective_window_fill": fill,
            "estimated_temperature_rise_c": rise_c, "passes_screen": passes,
        })
    return {
        "assumptions": {
            "copper_resistivity_at_100c_ohm_mm2_per_mm": rho_100c,
            "window_area_per_core_pair_mm2": window_per_pair_mm2,
            "winding_packing_factor": packing_factor,
        },
        "inductors": rows,
        "all_pass_screen": all(row["passes_screen"] for row in rows),
    }


def write_outputs(result):
    results_dir = ROOT / "results"
    (results_dir / "magnetics_thermal_metrics.json").write_text(
        json.dumps(result, indent=2) + "\n"
    )
    lines = [
        "# Magnetics Winding and Thermal Screen", "",
        "This analytical screen sizes conductor count from both current-density and DCR requirements. "
        "The stacked-core window scales with stack count and a 70% round-wire packing factor is applied. "
        "Release still requires the exact bobbin drawing, a wound sample, measured DCR, loaded inductance, and a thermal test.",
        "",
        "| Inductor | Cores | Turns | Strands (current / DCR / selected) | Est. DCR / limit | Effective fill | Est. loss | Est. rise | Screen |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in result["inductors"]:
        lines.append(
            f"| {row['name']} | {row['core_count']} | {row['turns']} | "
            f"{row['minimum_strands_by_current_density']} / {row['minimum_strands_by_dcr']} / {row['selected_strands']} | "
            f"{row['dcr_ohm']*1000:.2f} / {row['maximum_dcr_ohm']*1000:.2f} mOhm | "
            f"{row['effective_window_fill']*100:.1f}% | {row['total_loss_w']:.2f} W | "
            f"{row['estimated_temperature_rise_c']:.1f} C | {'PASS' if row['passes_screen'] else 'FAIL'} |"
        )
    lines.extend(["", "## Result", ""])
    if result["all_pass_screen"]:
        lines.append("**PRELIMINARY PASS:** the revised conductor counts satisfy the analytical DCR, effective-fill, and temperature-rise screens.")
    else:
        lines.append("**FAIL:** revise the conductor or core geometry before winding release.")
    (results_dir / "magnetics_thermal_report.md").write_text("\n".join(lines) + "\n")


def main():
    inputs, metrics = load_inputs()
    result = calculate(inputs, metrics)
    write_outputs(result)
    print("Magnetics winding screen: " + ("PASS" if result["all_pass_screen"] else "FAIL"))


if __name__ == "__main__":
    main()
