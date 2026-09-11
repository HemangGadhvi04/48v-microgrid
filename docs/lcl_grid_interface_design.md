# LCL Filter and Low-Voltage Grid Interface

## Scope

This milestone adds a switching-level LCL filter, configurable grid impedance,
and a point-of-common-coupling breaker. The grid is deliberately set to the
project's existing 28.85 V RMS, 50 Hz research bus. It is a simulation testbench
for control development and is not a 230 V utility-interconnection design.

## Selected baseline

| Parameter | Value |
|---|---:|
| Inverter-side inductance / resistance | 150 uH / 15 mOhm |
| Filter capacitance | 20 uF |
| Series damping resistance | 0.56 ohm |
| Grid-side filter inductance / resistance | 75 uH / 15 mOhm |
| Baseline grid inductance / resistance | 20 uH / 50 mOhm |
| Nominal grid | 28.85 V RMS, 50 Hz |
| Switching frequency / model step | 20 kHz / 1 us |

Including baseline grid inductance, the analytical LCL resonant frequency is
about 4.67 kHz. This satisfies the project's preliminary criterion of 500 Hz
to 10 kHz. The capacitor draws about 5.23 var at 50 Hz, approximately 1.05% of
the 500 W rating.

## Test sequence

The inverter and grid references start synchronized. The breaker closes at
80 ms. At 140 ms, the inverter modulation increases by 0.006 to excite the
passive plant and produce a measurable grid current. This voltage step is only
an LCL/grid-interface validation stimulus. It is not a grid-current controller.

The runner rejects excessive synchronized close current and invalid post-step
current measurements. It exports the frequency response, switching waveforms,
harmonics, transient plot, and MAT metrics to `simulations/grid_tie/results`.

## Next control boundary

The next subsystem must replace the open-loop modulation step with a bounded
current controller. A SOGI-PLL supplies grid angle and frequency; a current
reference supplies commanded active/reactive current. Breaker closure must be
supervised using voltage, frequency, phase, and timeout checks.

