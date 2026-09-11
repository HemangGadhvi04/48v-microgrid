# Phase 2 Power-Stage Calculation Report

Generated from `hardware/design_inputs.json` by `hardware/calculate_power_stage.py`.

## Rated operating requirements

| Quantity | Calculated value |
|---|---:|
| Minimum-input full-power DC current | 15.04 A |
| Worst inductor peak current | 15.65 A |
| Recommended inductor saturation rating (30% margin) | 20.35 A |
| Rated AC current | 17.33 A RMS / 24.51 A peak |
| Selected DC-link capacitance | 30.0 mF |
| Minimum capacitance for 2.0 V p-p 100 Hz ripple | 16.6 mF |
| Predicted ideal 100 Hz bus ripple | 1.11 V p-p |
| LCL resonance | 5032.9 Hz |
| MOSFET voltage-rating margin | 1.72x |
| Capacitor voltage-rating margin | 1.85x |

## First-pass hot loss estimate

| Loss term | DC-DC | Inverter |
|---|---:|---:|
| MOSFET conduction | 2.08 W | 2.76 W |
| MOSFET switching | 0.44 W | 0.84 W |
| Gate drive | 0.06 W | 0.11 W |
| Dead time | 0.05 W | 0.05 W |
| Magnetics copper | 3.39 W | 7.21 W |
| Core/damping estimate | 2.00 W | 1.00 W |
| Auxiliary estimate | 1.10 W | included later |
| **Stage total** | **9.12 W** | **11.98 W** |

The combined first-pass loss is 21.09 W, giving
an estimated 95.95% electrical efficiency.
This is a sizing estimate. Calorimetric or input/output power measurements must
replace it before Phase 2 can close.

## Precharge

With 30.0 mF and 47 ohm,
the bus reaches 90% in 3.25 s. Initial resistor
power is 62.0 W and maximum stored DC-link
energy is 43.74 J. The resistor therefore needs
a verified pulse-energy curve; its printed wattage alone is insufficient.

## Model boundaries

The switching estimate uses overlap time and average commutation current. It
does not include measured parasitic ringing, reverse recovery, PCB resistance,
temperature-dependent magnetics, capacitor ESR, control-supply efficiency, or
fan power. The reference MOSFET's hot resistance is represented by the explicit
input value rather than its 25 degree headline value.
