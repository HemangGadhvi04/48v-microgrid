#!/usr/bin/env python3
"""Electrical-rule checks for the schematic-ready connectivity table."""
import csv
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
rows = list(csv.DictReader((ROOT / "connectivity_netlist.csv").open()))
assert rows
bom_rows = list(csv.DictReader((ROOT / "reference_bom.csv").open()))
assert all(None not in row and all(value for value in row.values()) for row in bom_rows)

pins = [(row["reference"], row["pin"]) for row in rows]
assert len(pins) == len(set(pins)), "duplicate component pin assignment"
by_net = defaultdict(list)
by_ref = defaultdict(dict)
for row in rows:
    assert row["net"] and row["domain"]
    by_net[row["net"]].append((row["reference"], row["pin"]))
    by_ref[row["reference"]][row["pin"]] = row["net"]
for net, endpoints in by_net.items():
    if net != "HEATSINK" and not net.startswith("NC_"):
        assert len(endpoints) >= 2, f"dangling net {net}: {endpoints}"

adc_nets = {
    "ADC_PV_V", "ADC_VDC", "ADC_PV_I", "ADC_IL_DC", "ADC_GRID_V",
    "ADC_UTILITY_V", "ADC_GRID_I", "ADC_TEMP",
}
assert adc_nets <= by_net.keys()
for net in adc_nets:
    assert any(ref == "JCTRL" for ref, _ in by_net[net]), net
assert by_ref["U11"]["IN+"] == "AC_INV"
assert by_ref["U12"]["IN+"] == "UTILITY_AC"
assert by_ref["KAC"]["COM"] == "AC_PCC"
assert by_ref["KAC"]["NO"] == "UTILITY_AC"
assert not any(ref != "KAC" and {row["net"] for row in rows if row["reference"] == ref}
               >= {"AC_PCC", "UTILITY_AC"} for ref in by_ref)

switch_returns = ["SW_PV", "PGND", "SW_DC", "PGND",
                  "SW_A", "PGND", "AC_RETURN", "PGND"]
for index in range(1, 9):
    gate = f"GATE_Q{index}"
    drive = f"DRV_Q{index}"
    assert by_ref[f"Q{index}"]["G"] == gate
    assert by_ref[f"RG{index}"] == {"1": drive, "2": gate}
    assert by_ref[f"RGS{index}"] == {"1": gate, "2": switch_returns[index-1]}

for index in range(1, 9):
    pair = (index + 1) // 2
    side = "A" if index % 2 else "B"
    enable = by_ref[f"UEN{index}"]
    assert enable["PWM"] == f"PWM{pair}{side}_RAW"
    assert enable["OUT"] == f"PWM{pair}{side}"
    assert enable["ARM"] == "PWM_ARM"
    assert enable["ESTOP_N"] == "ESTOP_N"
    assert enable["TRIP_N"] == "TRIP_LATCH_N"
    assert enable["BIAS_OK"] == "BIAS_POWER_GOOD"

assert {by_ref["UTRIP"][f"IN{i}_N"] for i in range(1, 5)} == {
    "OC_PV_N", "OC_DC_N", "OC_GRID_N", "ESTOP_N"
}
assert by_ref["UTRIP"]["OUT_N"] == "TRIP_LATCH_N"
for relay, driver, diode, low_net, command in (
    ("KPRE", "QKPRE", "DKPRE", "PRECHARGE_COIL_LOW", "PRECHARGE_CMD"),
    ("K1", "QK1", "DK1", "MAIN_COIL_LOW", "MAIN_CONTACTOR_CMD"),
    ("KAC", "QKAC", "DKAC", "GRID_COIL_LOW", "GRID_BREAKER_CMD"),
):
    assert by_ref[relay]["COIL+"] == "RELAY12V"
    assert by_ref[relay]["COIL-"] == low_net
    assert by_ref[driver]["G"] == command
    assert by_ref[driver]["S"] == "PGND"
    assert by_ref[driver]["D"] == low_net
    assert by_ref[diode] == {"A": low_net, "K": "RELAY12V"}

summary = {
    "component_count": len(by_ref),
    "pin_count": len(rows),
    "net_count": len(by_net),
    "adc_channels": len(adc_nets),
    "mosfet_gate_chains": 8,
    "hardware_interlock_channels": 8,
    "relay_drivers": 3,
    "bom_line_items": len(bom_rows),
    "checks_passed": True,
}
(ROOT / "results").mkdir(exist_ok=True)
(ROOT / "results" / "connectivity_summary.json").write_text(
    json.dumps(summary, indent=2) + "\n")
print(f"Validated {summary['component_count']} components, {summary['pin_count']} pins, {summary['net_count']} nets")
