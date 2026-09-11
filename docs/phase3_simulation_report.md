# Phase 3 Battery and Microgrid-Control Report

## Validated scope

The Phase 3 simulation baseline contains two independent models:

1. A parameterized 16-series, 20 Ah LiFePO4 equivalent-circuit model with OCV,
   series resistance, polarization dynamics, SOC, heat generation, ambient heat
   loss, bidirectional terminal power, and reciprocal energy accounting.
2. A two-source RMS dynamic-phasor microgrid with unequal 300 W and 200 W
   sources, proportional P-frequency and Q-voltage droop, grid loss detection,
   islanded load sharing, a 400 W to 500 W load step, active synchronization,
   and breaker reconnection.

## Battery results

| Metric | Result |
|---|---:|
| Initial/final SOC | 65.00% / 58.53% |
| Terminal-voltage range | 51.828 V to 53.696 V |
| Maximum discharge current | 9.647 A |
| Maximum charge current | 5.655 A |
| Maximum temperature | 25.660 deg C |
| Peak energy residual | 0.000368 J |
| Chemical-energy throughput | 424.77 kJ |

The 1200-second profile contains 200 W and 500 W discharge, 300 W charge, and
400 W discharge intervals. Current, voltage, SOC, and thermal limits pass. The
OCV curve and ECM parameters are illustrative project parameters and must be
replaced by cell-level characterization before choosing a physical pack or BMS.

## Droop and transition results

| Metric | Result |
|---|---:|
| Grid-loss detection delay | 36.2 ms |
| Reconnection time | 1.9581 s |
| Source 1 active-power share before/after load step | 60.0% / 60.0% |
| Source 1 reactive-power share after load step | 60.0% |
| Island voltage range | 27.701 V to 28.017 V RMS |
| Island frequency range | 49.478 Hz to 49.646 Hz |
| Reconnection grid-current peak | 17.932 A RMS |
| Post-reconnection mean voltage | 28.350 V RMS |

The sharing ratio matches the 300:200 W source rating. Reconnection requires a
phase, frequency, and voltage qualification hold before closing the breaker.
The 20 A RMS reconnection gate is below the 30 A measurement range and the
configured grid-current protection range.

Matching portable C modules and the integrated 20 kHz application now implement
rating-normalized droop and the grid relay state machine. The application runs
separate PLLs for the microgrid bus and utility side of the open breaker, retains
PWM during an outage, changes from PR current control to droop-based voltage
synthesis, applies synchronization corrections after utility return, and only
then commands breaker closure. Host tests verify equal per-unit droop between unequal
source ratings, 20 ms loss qualification, breaker opening, bounded
synchronization bias, continuous reconnection qualification, and the complete
application mode sequence. The hardware
measurement design includes separate voltage channels on each side of the AC
contactor so this logic remains observable while the breaker is open.

## Fidelity boundary

The microgrid transition model uses RMS dynamic phasors. It validates droop,
power sharing, supervisory timing, and synchronization logic at the control
timescale. It does not resolve PWM ripple, contact bounce, magnetic saturation,
DC offsets, switching overvoltage, or sub-cycle breaker transients. Those items
remain switching-model, HIL, and isolated-grid-emulator tests. The grid-loss
event is a simulated source loss; no compliance claim follows from the 36.2 ms
detection result.

## Reproduction

```matlab
addpath('/Users/hemanggadhvi/Desktop/48V microgrid/simulations')
summary = run_phase3_validation();
```

Detailed MAT, CSV, and PNG artifacts are retained under
`simulations/battery/results/` and `simulations/microgrid/results/`.
