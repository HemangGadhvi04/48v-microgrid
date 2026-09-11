# Phase 1 Simulation Validation Report

## Scope and result

Phase 1 establishes an executable, low-voltage 500 W research model from a
single-diode PV source to a stiff AC grid. The complete chain is:

`PV array -> P&O MPPT -> four-switch buck-boost -> 48 V DC link -> switching H-bridge -> LCL filter -> research grid`

Every implemented subsystem and the coupled system pass their automated
acceptance checks in MATLAB R2025b. The coupled validation intentionally uses a
28.85 V RMS, 50 Hz research grid. It does not represent a direct 230 V utility
connection.

## Architecture

The PV source uses an explicit five-parameter single-diode equation. P&O selects
the PV-voltage reference. An outer PV-voltage PI loop produces the DC-inductor
current reference and an inner PI loop drives an averaged four-switch
buck-boost stage. This permits both buck and boost operation as the PV maximum
power voltage crosses the 48 V bus voltage.

The DC link is a dynamic 30 mF energy-storage element, matching the tolerance-safe
three-capacitor hardware candidate. The inverter-side energy
controller turns DC-link energy error into active-power demand. A SOGI-PLL
estimates grid phase and a stationary-frame PR controller regulates injected
current through the switching H-bridge and LCL plant.

The electrical plant uses a 1 microsecond fixed integration step. Control loops
run at their configured discrete sample rates. The validation accounts for PV
energy, exported grid energy, modeled resistive and switching losses, and the
change in stored electrical energy.

## Subsystem results

| Subsystem | Acceptance evidence | Result |
|---|---:|---:|
| Open-loop H-bridge and LC filter | Three-level unipolar switching and filtered output | Pass |
| Islanded voltage control | 250 W to 500 W load step | Pass |
| LCL grid interface | Resonance placement and damped response | Pass |
| SOGI-PLL | 46.5 ms startup lock; 47.5 ms after 50 to 52 Hz step | Pass |
| SOGI-PLL disturbance | 19.7 ms after 20-degree phase jump; 3.241-degree sag error | Pass |
| Grid-following inverter | 499.5 W, PF 0.9994, current THD 2.72% | Pass |
| Reactive-power command | 150.0 var while maintaining 499.5 W | Pass |
| PV source | 498.3 W maximum power at STC | Pass |
| P&O MPPT | Greater than 99.9% mean settled-window efficiency | Pass |

## Coupled solar-to-grid validation

Five settled operating windows cover irradiance and temperature changes. Values
below are calculated from the retained validation artifact.

| Irradiance (W/m2) | Temperature (deg C) | Available PV (W) | Captured PV (W) | MPPT efficiency | Grid power (W) | Mean bus (V) | Bus ripple p-p (V) | Current THD | PF |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1000 | 25 | 498.26 | 498.22 | 99.992% | 471.90 | 47.993 | 1.134 | 2.68% | 0.99928 |
| 600 | 25 | 294.74 | 294.71 | 99.990% | 285.22 | 48.005 | 0.697 | 4.83% | 0.99804 |
| 900 | 25 | 447.74 | 447.70 | 99.991% | 425.98 | 47.982 | 1.047 | 2.85% | 0.99915 |
| 900 | 45 | 405.11 | 405.07 | 99.989% | 386.74 | 47.997 | 0.929 | 3.02% | 0.99893 |
| 900 | 10 | 479.84 | 477.56 | 99.524% | 452.26 | 47.974 | 1.091 | 2.40% | 0.99924 |

The full run receives 956.114 J from the PV source, exports 912.104 J to the
grid, dissipates 44.412 J in modeled losses, and finishes with a -0.402 J change
in stored energy. The peak integrated energy residual is 0.000303 J, or
0.000032% of PV energy. Both converter modes occur in the test profile, the
modulator remains unsaturated in every settled window, and current-limit checks
pass.

## Acceptance criteria

The coupled run fails automatically if any waveform is non-finite, mean DC-bus
error exceeds 1%, transient DC-bus voltage leaves 90% to 110% of nominal,
settled MPPT efficiency falls below 98%, grid-current THD exceeds 5%, power
factor falls below 0.99, steady modulation saturation exceeds 1%, energy
residual exceeds 0.1%, either converter mode is absent, or a configured current
limit is exceeded.

## Reproducing the evidence

Run the complete regression suite from MATLAB:

```matlab
addpath('/Users/hemanggadhvi/Desktop/48V microgrid/simulations')
summary = run_phase1_validation();
```

This writes the consolidated result to
`simulations/results/phase1_regression_summary.csv` and preserves each stage's
own artifacts.

Run the coupled validation from MATLAB:

```matlab
cd('/Users/hemanggadhvi/Desktop/48V microgrid/simulations/system')
report = run_solar_grid_validation();
```

The run writes `solar_grid_validation.mat`, `solar_grid_metrics.csv`,
`solar_grid_waveforms.csv`, `solar_grid_validation.png`, and
`solar_grid_current_and_duties.png` under `simulations/system/results/`.

## Boundaries of the result

The results validate the numerical model and the selected control structure.
They do not establish semiconductor thermal performance, dead-time immunity,
EMI compliance, sensing accuracy, protection coordination, PCB integrity, or
grid-code certification. Those require Phase 2 hardware-in-the-loop and
isolated bench tests before any higher-voltage experiment.
