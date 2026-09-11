#!/usr/bin/env python3
"""Derive magnetic energy, copper, flux and reference-core requirements."""

import csv
import json
import math
import pathlib


ROOT = pathlib.Path(__file__).resolve().parent
MU_0 = 4.0e-7 * math.pi


def load_inputs():
    with (ROOT / "magnetics_inputs.json").open(encoding="utf-8") as handle:
        return json.load(handle)


def calculate(data):
    frequency = data["switching_frequency_hz"]
    resistivity = data["copper_resistivity_ohm_m"]
    relative_mu = data["copper_relative_permeability"]
    skin_depth_m = math.sqrt(resistivity / (math.pi * frequency * MU_0 * relative_mu))
    strand_diameter = data["preferred_round_strand_diameter_mm"]
    strand_copper_area = math.pi * strand_diameter ** 2 / 4.0
    core = data["candidate_reference_core"]
    al_h = core["initial_al_nh_per_turn2"] * 1e-9
    area_m2 = core["effective_area_mm2"] * 1e-6
    bias_curve = core["dc_bias_curve"]
    loss_curve = core["core_loss_curve"]
    rows = []
    for item in data["inductors"]:
        inductance = item["inductance_h"]
        peak_current = item["peak_current_a"]
        required_copper_area = (item["rms_current_a"]
                                / data["maximum_current_density_a_per_mm2"])
        core_count = item["core_count"]
        stack_al_h = core_count * al_h
        stack_area_m2 = core_count * area_m2
        turns_initial_al = math.sqrt(inductance / stack_al_h)
        turns_flux = inductance * peak_current / (
            data["maximum_flux_density_t"] * stack_area_m2)
        selected_analysis_turns = None
        for turns in range(1, 1001):
            field = 4.0 * math.pi * turns * peak_current / core["effective_length_mm"]
            retention = bias_curve["a"] / (
                bias_curve["a"] + bias_curve["b"] * field ** bias_curve["c"])
            loaded_inductance = stack_al_h * retention * turns ** 2
            peak_flux = loaded_inductance * peak_current / (turns * stack_area_m2)
            if loaded_inductance >= inductance and peak_flux <= data["maximum_flux_density_t"]:
                selected_analysis_turns = turns
                break
        if selected_analysis_turns is None:
            raise ValueError(f"No feasible turn count for {item['name']}")
        dc_bias_oe = (4.0 * math.pi * selected_analysis_turns * peak_current
                      / core["effective_length_mm"])
        predicted_retention = bias_curve["a"] / (
            bias_curve["a"] + bias_curve["b"] * dc_bias_oe ** bias_curve["c"])
        predicted_inductance = (stack_al_h * predicted_retention
                                * selected_analysis_turns ** 2)
        predicted_peak_flux = (predicted_inductance * peak_current
                               / (selected_analysis_turns * stack_area_m2))
        ripple_flux_peak = (inductance * item["ripple_pp_a"] / 2.0
                            / (selected_analysis_turns * stack_area_m2))
        loss_density_mw_cm3 = (loss_curve["a"] * ripple_flux_peak ** loss_curve["b"]
                               * (item["ripple_frequency_hz"] / 1000.0)
                               ** loss_curve["c"])
        core_loss_w = (loss_density_mw_cm3
                       * core["effective_volume_mm3"] / 1000.0
                       * core_count / 1000.0)
        required_loaded_al = inductance / selected_analysis_turns ** 2 / core_count
        required_al_retention = required_loaded_al / al_h
        rows.append({
            **item,
            "stored_energy_j": 0.5 * inductance * peak_current ** 2,
            "required_copper_area_mm2": required_copper_area,
            "minimum_parallel_strands": math.ceil(required_copper_area / strand_copper_area),
            "initial_al_turns": turns_initial_al,
            "flux_limited_turns": turns_flux,
            "analysis_turns": selected_analysis_turns,
            "core_count": core_count,
            "required_loaded_al_nh_per_turn2": required_loaded_al * 1e9,
            "required_al_retention": required_al_retention,
            "predicted_al_retention": predicted_retention,
            "predicted_inductance_h": predicted_inductance,
            "bias_field_oe": dc_bias_oe,
            "predicted_peak_flux_t": predicted_peak_flux,
            "ripple_flux_peak_t": ripple_flux_peak,
            "predicted_core_loss_w": core_loss_w,
            "copper_loss_at_maximum_dcr_w": item["rms_current_a"] ** 2
                                                 * item["maximum_dcr_ohm"],
        })
    return {
        "skin_depth_mm": skin_depth_m * 1000.0,
        "recommended_maximum_round_strand_diameter_mm": 2.0 * skin_depth_m * 1000.0,
        "preferred_strand_copper_area_mm2": strand_copper_area,
        "candidate_reference_core": core,
        "inductors": rows,
    }


def write_outputs(data, result):
    output_dir = ROOT / "results"
    output_dir.mkdir(exist_ok=True)
    with (output_dir / "magnetics_metrics.json").open("w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    fields = [
        "name", "inductance_h", "rms_current_a", "peak_current_a",
        "stored_energy_j", "required_copper_area_mm2", "minimum_parallel_strands",
        "initial_al_turns", "flux_limited_turns", "analysis_turns", "core_count",
        "required_loaded_al_nh_per_turn2", "required_al_retention", "bias_field_oe",
        "predicted_al_retention", "predicted_inductance_h", "predicted_peak_flux_t",
        "ripple_pp_a", "ripple_frequency_hz", "ripple_flux_peak_t", "predicted_core_loss_w",
        "maximum_dcr_ohm", "copper_loss_at_maximum_dcr_w", "excitation",
    ]
    with (output_dir / "magnetics_requirements.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(result["inductors"])

    rows = []
    for item in result["inductors"]:
        rows.append(
            f"| {item['name']} | {item['inductance_h']*1e6:.0f} uH "
            f"| {item['rms_current_a']:.2f} A | {item['peak_current_a']:.2f} A "
            f"| {item['stored_energy_j']*1000:.2f} mJ "
            f"| {item['required_copper_area_mm2']:.2f} mm2 "
            f"| {item['minimum_parallel_strands']} | {item['core_count']} | {item['analysis_turns']} |"
        )
    core = result["candidate_reference_core"]
    report = f"""# Phase 2 Magnetics Requirements

Generated from `hardware/magnetics_inputs.json`.

At {data['switching_frequency_hz']/1000:.0f} kHz, copper skin depth is
{result['skin_depth_mm']:.3f} mm. The preferred {data['preferred_round_strand_diameter_mm']:.1f}
mm strand is below the {result['recommended_maximum_round_strand_diameter_mm']:.3f}
mm two-skin-depth guideline. Parallel strand counts below are based on
{data['maximum_current_density_a_per_mm2']:.1f} A/mm2 copper density before
insulation, packing, termination, proximity-effect, and temperature derating.

| Ref | L | RMS current | Design peak | Stored energy | Copper area | 0.5 mm strands | Cores | Turns |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
{chr(10).join(rows)}

## Reference-core feasibility check

The calculation uses the published geometry of the {core['manufacturer']}
{core['family']} candidate ({core['part']}): initial AL
{core['initial_al_nh_per_turn2']:.0f} nH/turn2, effective area
{core['effective_area_mm2']:.0f} mm2, effective length
{core['effective_length_mm']:.0f} mm, and effective volume
{core['effective_volume_mm3']:.0f} mm3. The DC-bias and core-loss coefficients
come from the manufacturer's 2026 curve-fit workbook. The former single-core
60-permeability estimate was removed because the workbook does not publish a
60-permeability HF E-core bias fit.

| Ref | Stack | Turns | Bias field | Predicted retention | Predicted L | Peak B | Ripple Bpk | Estimated core loss |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
"""
    for item in result["inductors"]:
        report += (
            f"| {item['name']} | {item['core_count']} | {item['analysis_turns']} | "
            f"{item['bias_field_oe']:.1f} Oe | {100*item['predicted_al_retention']:.1f}% | "
            f"{item['predicted_inductance_h']*1e6:.1f} uH | "
            f"{item['predicted_peak_flux_t']:.3f} T | {item['ripple_flux_peak_t']:.4f} T | "
            f"{item['predicted_core_loss_w']:.3f} W |\n"
        )
    report += """

These are electrically feasible reference windings on identical E65 core sets.
The core-loss estimate covers the stated switching ripple only; it does not
replace calorimetric verification. Window fill, mean length per turn, proximity
loss, winding temperature, insulation, and measured inductance at current remain
release gates.

## Required bench evidence

- Measure inductance at zero current and at the design peak current.
- Measure winding resistance cold and after thermal equilibrium.
- Record 20 kHz ripple current and core surface temperature at every rated
  operating corner.
- Confirm no local gap-fringing hot spot and verify winding termination current
  sharing when parallel strands are used.
- Perform a 125% current pulse without saturation or insulation damage before
  enabling closed-loop full-power operation.
"""
    (output_dir / "magnetics_report.md").write_text(report, encoding="utf-8")


def main():
    data = load_inputs()
    result = calculate(data)
    write_outputs(data, result)
    print(f"Copper skin depth: {result['skin_depth_mm']:.3f} mm")
    for item in result["inductors"]:
        print(f"{item['name']}: {item['stored_energy_j']*1000:.2f} mJ, "
              f"{item['analysis_turns']} analysis turns")


if __name__ == "__main__":
    main()
