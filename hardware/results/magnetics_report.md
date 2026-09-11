# Phase 2 Magnetics Requirements

Generated from `hardware/magnetics_inputs.json`.

At 20 kHz, copper skin depth is
0.467 mm. The preferred 0.5
mm strand is below the 0.935
mm two-skin-depth guideline. Parallel strand counts below are based on
4.0 A/mm2 copper density before
insulation, packing, termination, proximity-effect, and temperature derating.

| Ref | L | RMS current | Design peak | Stored energy | Copper area | 0.5 mm strands | Cores | Turns |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| LDC | 500 uH | 15.08 A | 15.65 A | 61.23 mJ | 3.77 mm2 | 20 | 3 | 28 |
| L1 | 150 uH | 17.33 A | 27.00 A | 54.67 mJ | 4.33 mm2 | 23 | 2 | 19 |
| L2 | 75 uH | 17.33 A | 26.00 A | 25.35 mJ | 4.33 mm2 | 23 | 1 | 19 |

## Reference-core feasibility check

The calculation uses the published geometry of the Magnetics
Kool Mu HF E65/32/27 candidate (00F6527E040): initial AL
230 nH/turn2, effective area
540 mm2, effective length
147 mm, and effective volume
79400 mm3. The DC-bias and core-loss coefficients
come from the manufacturer's 2026 curve-fit workbook. The former single-core
60-permeability estimate was removed because the workbook does not publish a
60-permeability HF E-core bias fit.

| Ref | Stack | Turns | Bias field | Predicted retention | Predicted L | Peak B | Ripple Bpk | Estimated core loss |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| LDC | 3 | 28 | 37.5 Oe | 92.8% | 502.2 uH | 0.173 T | 0.0068 T | 0.096 W |
| L1 | 2 | 19 | 43.9 Oe | 90.8% | 150.9 uH | 0.199 T | 0.0073 T | 0.190 W |
| L2 | 1 | 19 | 42.2 Oe | 91.4% | 75.9 uH | 0.192 T | 0.0073 T | 0.095 W |


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
