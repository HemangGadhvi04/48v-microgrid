#!/usr/bin/env python3
import json
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
cfg = json.loads((ROOT / "peripheral_config.json").read_text())
assert cfg["counter_mode"] == "up_down"
assert cfg["cpu_clock_hz"] > 100_000_000
assert cfg["epwm_clock_hz"] <= 100_000_000
assert cfg["adc_clock_hz"] <= 50_000_000
period = cfg["epwm_clock_hz"] // (2 * cfg["switching_frequency_hz"])
assert period * 2 * cfg["switching_frequency_hz"] == cfg["epwm_clock_hz"]
deadband = round(cfg["dead_time_ns"] * 1e-9 * cfg["epwm_clock_hz"])
acqps = cfg["adc_acquisition_sysclk_cycles"] - 1
acquisition_ns = cfg["adc_acquisition_sysclk_cycles"] / cfg["cpu_clock_hz"] * 1e9
assert acquisition_ns >= 75.0
signals = [soc["signal"] for rows in cfg["adc_modules"].values() for soc in rows]
assert len(signals) == 8 and len(set(signals)) == 8
pin_rows = {row["function"]: row for row in csv.DictReader(
    (ROOT / "pin_allocation.csv").open())}
for module, rows in cfg["adc_modules"].items():
    for soc in rows:
        expected = f"ADCIN{soc['channel']}" if soc["channel"] >= 14 else f"ADCIN{module}{soc['channel']}"
        assert pin_rows[soc["signal"]]["peripheral"] == expected
slowest_count = max(len(rows) for rows in cfg["adc_modules"].values())
interrupt_module = cfg["adc_completion_interrupt"]["module"]
assert len(cfg["adc_modules"][interrupt_module]) == slowest_count
adc_set_us = slowest_count * (cfg["adc_acquisition_sysclk_cycles"]
    + cfg["adc_conversion_sysclk_cycles"]) / cfg["cpu_clock_hz"] * 1e6
assert adc_set_us < 5.0
period_us = 1e6 / cfg["switching_frequency_hz"]
assert adc_set_us + cfg["control_deadline_us"] < period_us

(ROOT / "generated" / "peripheral_timing.h").write_text(f"""#ifndef MG_C2000_PERIPHERAL_TIMING_H
#define MG_C2000_PERIPHERAL_TIMING_H

#define MG_C2000_CPU_CLOCK_HZ ({cfg['cpu_clock_hz']}UL)
#define MG_C2000_EPWM_CLOCK_HZ ({cfg['epwm_clock_hz']}UL)
#define MG_C2000_PWM_TBPRD ({period}u)
#define MG_C2000_PWM_DEADBAND_COUNTS ({deadband}u)
#define MG_C2000_ADC_ACQPS ({acqps}u)
#define MG_C2000_CONTROL_DEADLINE_US ({cfg['control_deadline_us']}u)

#endif
""")
(ROOT / "peripheral_timing_report.md").write_text(f"""# F28379D Peripheral Timing

| Item | Frozen value |
|---|---:|
| CPU clock | {cfg['cpu_clock_hz']/1e6:.0f} MHz |
| ePWM clock | {cfg['epwm_clock_hz']/1e6:.0f} MHz |
| Center-aligned switching | {cfg['switching_frequency_hz']/1e3:.0f} kHz |
| TBPRD | {period} counts |
| Dead time | {cfg['dead_time_ns']} ns / {deadband} counts |
| ADC acquisition | {acquisition_ns:.0f} ns / ACQPS {acqps} |
| Estimated coherent set completion | {adc_set_us:.2f} us |
| Control deadline | {cfg['control_deadline_us']} us |
| Period reserve after acquisition and deadline | {period_us-adc_set_us-cfg['control_deadline_us']:.2f} us |

All eight SOCs use ePWM1 SOCA at counter zero. ADCA has the longest sequence
with four conversions; ADCA SOC3 raises ADCINT1 after the other modules have
completed their two-conversion sequences. The estimate uses the configured
acquisition and conservative conversion-cycle budget. Target oscilloscope and
timer measurements remain the release evidence.
""")
print(f"TBPRD {period}, dead band {deadband}, ADC set {adc_set_us:.2f} us")
