# Closed-Loop Islanded Inverter Controller Design

## Purpose

The islanded controller regulates the 50 Hz output-voltage fundamental of the
48 V single-phase inverter. Its command is the normalized unipolar-SPWM
modulation index. This is a voltage-source inverter controller for islanded
operation, not a grid-following current controller.

## Plant and Operating Point

| Item | Value |
| --- | ---: |
| DC bus nominal / operating range | 48 V / 42 V to 54 V |
| Nominal output | 28.85 V RMS, 50 Hz, 500 W |
| Nominal resistive load | 1.665 ohm |
| Switching frequency | 20 kHz |
| Simulation integration step | 1 us |
| PI control update rate in this switching simulation | 1 MHz |
| Output inductor | 100 uH, 15 mOhm ESR |
| Filter capacitor | 47 uF, 10 mOhm ESR |
| Series damping resistance | 0.50 ohm |
| LC cutoff frequency | 2.32 kHz |

The model uses unipolar SPWM, so its ideal fundamental voltage is
approximately `m * Vdc`. The LC branch removes switching-frequency content;
the 0.50 ohm series damping resistor controls the LC resonance.

## Voltage Measurement

The controller estimates the fundamental magnitude rather than using the
instantaneous, switched output voltage. It synchronously demodulates the
measured output with the known 50 Hz references:

```text
x_s = v_out sin(theta)
x_c = v_out cos(theta)
V_peak_est = 2 sqrt(mean_cycle(x_s)^2 + mean_cycle(x_c)^2)
V_rms_est = V_peak_est / sqrt(2)
```

`mean_cycle` is a moving average spanning one 20 ms line cycle (20,000
simulation samples). The average rejects the double-frequency term created by
the demodulator and substantially rejects the 20 kHz switching content. The
controller compares `V_peak_est` with a soft-ramped peak reference.

## PI Controller

```text
e_v = V_peak_ref - V_peak_est
m_raw = Kp e_v + Ki integral(e_v) dt
m_cmd = clamp(m_raw, 0, 0.95)
```

| Parameter | Value |
| --- | ---: |
| `Kp_voltage` | 0.010 1/V |
| `Ki_voltage` | 1.20 1/(V s) |
| Control sample period in this switching simulation | 1 us |
| Modulation limits | 0 to 0.95 |
| Reference-ramp duration | 60 ms |

These gains are intentionally conservative because the amplitude estimator
contains a line-cycle observation window. The present model is a
transient-validated switching baseline, not a final hardware-bandwidth design.
Hardware work should discretize the PI at the selected control interrupt (for
example 20 kHz), then add explicit anti-windup, ADC delay, PWM update timing,
dead time, and current limiting.

## Verified Baseline

For a 250 W to 500 W resistive step at 48 V DC, the switching-level model
achieved 28.84 V RMS post-step voltage, 0.04% one-cycle RMS sag, 7 ms rolling
RMS settling, 1.33% voltage THD, and 499.7 W post-step real power.

## Robustness Matrix

The next validated sweep uses the acceptance criteria below. A result is only
considered passing when the commanded modulation does not remain saturated,
unless the case is explicitly a saturation characterization.

| Case | Stimulus | Primary measurements |
| --- | --- | --- |
| Startup | 0 V reference to nominal over 60 ms | overshoot, settling, peak current |
| Light-to-full load | 250 W to 500 W resistive | sag, settling, THD |
| Full-to-light load | 500 W to 250 W resistive | overshoot, settling, THD |
| Inductive load | 500 W-class series RL load | RMS regulation, power factor, current stress |
| Low DC bus | 42 V with full load | regulation error and saturation duty |
| High DC bus | 54 V with full load | overshoot and modulation margin |
| Insufficient bus | 40 V with full load | saturation behavior and unmet-voltage limit |

At the 42 V minimum bus, `m_max = 0.95` yields an ideal ceiling of 28.21 V RMS
before parasitic losses. Full nominal output therefore has little or no voltage
margin at that bus and is expected to expose saturation. That is a useful
architecture result: a 48 V battery-only system needs either a lower AC target,
a higher permissible modulation index with a validated modulator, or an
upstream boost stage to guarantee 28.85 V RMS across the full battery range.

## Transition to Grid Following

Grid-following work should be a separate control path: grid-voltage sensing,
SOGI-PLL, an LCL-filter model, and a synchronized current loop. The present
voltage regulator remains the islanded-mode controller. Supervisory transfer
logic belongs after both modes have independent robustness evidence.
