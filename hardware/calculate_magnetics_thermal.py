import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def calculate_thermal():
    with (ROOT / "results" / "magnetics_metrics.json").open() as f:
        metrics = json.load(f)

    # Copper properties
    rho_cu_100c = 2.3e-5  # Ohm*mm
    
    # E65/32/27 core geometry approximations
    window_area_mm2 = 411.0 # 4.11 cm^2 Wa
    center_leg_width_mm = 20.0
    center_leg_depth_mm = 27.4 # Per core pair
    
    # Base surface area for 1 pair of E65 is ~140 cm^2. 
    # Each additional core pair increases the depth by 27.4mm, adding ~50 cm^2 
    base_surface_area_cm2 = 140.0
    extra_surface_per_core_cm2 = 50.0

    strand_area_mm2 = metrics["preferred_strand_copper_area_mm2"]
    
    inductors_out = []
    
    for ind in metrics["inductors"]:
        name = ind["name"]
        core_count = ind["core_count"]
        turns = ind["analysis_turns"]
        strands = ind["minimum_parallel_strands"]
        
        # Calculate MLT (Mean Length of Turn)
        # Center leg perimeter + winding build-out
        mlt_mm = 2 * center_leg_width_mm + 2 * (center_leg_depth_mm * core_count) + 31.4 # pi * 10mm avg build
        
        # Calculate DCR
        copper_area_mm2 = strands * strand_area_mm2
        dcr_ohm = rho_cu_100c * (mlt_mm * turns) / copper_area_mm2
        
        # Copper Loss
        i_rms = ind["rms_current_a"]
        copper_loss_w = (i_rms ** 2) * dcr_ohm
        
        # Total Loss
        core_loss_w = ind["predicted_core_loss_w"]
        total_loss_w = copper_loss_w + core_loss_w
        
        # Window Fill Factor
        # Area of copper / Window area
        fill_factor = (turns * copper_area_mm2) / window_area_mm2
        
        # Temperature Rise (empirical formula: dT = (P_mw / Surface_Area_cm2)^0.833 )
        surface_area_cm2 = base_surface_area_cm2 + (core_count - 1) * extra_surface_per_core_cm2
        temp_rise_c = ( (total_loss_w * 1000.0) / surface_area_cm2 ) ** 0.833
        
        inductors_out.append({
            "name": name,
            "turns": turns,
            "strands": strands,
            "core_count": core_count,
            "mlt_mm": mlt_mm,
            "dcr_ohm": dcr_ohm,
            "copper_loss_w": copper_loss_w,
            "core_loss_w": core_loss_w,
            "total_loss_w": total_loss_w,
            "fill_factor": fill_factor,
            "surface_area_cm2": surface_area_cm2,
            "temp_rise_c": temp_rise_c
        })
        
    # Write report
    report_path = ROOT / "results" / "magnetics_thermal_report.md"
    
    report = "# Magnetics Thermal & Winding Proof\n\n"
    report += "This report verifies the winding feasibility (window fill) and thermal limits (temperature rise) "
    report += "for the E65 Kool Mu inductor designs at full 500W load.\n\n"
    
    report += "| Inductor | Cores | Turns | Strands | MLT (mm) | DCR (mΩ) | Cu Loss (W) | Core Loss (W) | Total (W) | Fill Factor | $\Delta$T (°C) |\n"
    report += "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n"
    
    all_feasible = True
    for out in inductors_out:
        report += f"| {out['name']} | {out['core_count']} | {out['turns']} | {out['strands']} | "
        report += f"{out['mlt_mm']:.1f} | {out['dcr_ohm']*1000:.2f} | "
        report += f"{out['copper_loss_w']:.2f} | {out['core_loss_w']:.2f} | {out['total_loss_w']:.2f} | "
        report += f"{out['fill_factor']*100:.1f}% | {out['temp_rise_c']:.1f} |\n"
        
        if out['fill_factor'] > 0.4: # Typical limit for round wire
            all_feasible = False
        if out['temp_rise_c'] > 40.0:
            all_feasible = False
            
    report += "\n## Feasibility Assessment\n\n"
    
    if all_feasible:
        report += "✅ **PASSED**: All inductors have a window fill factor below 40% and a predicted temperature rise below 40°C.\n"
    else:
        report += "❌ **WARNING**: One or more inductors exceed the 40% window fill limit or 40°C temperature rise target.\n"
        
    with report_path.open("w") as f:
        f.write(report)
        
    print(f"Generated {report_path}")

if __name__ == "__main__":
    calculate_thermal()
