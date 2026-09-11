# Master research map and learning sequence

Prepared 6 September 2026. Read with [source index](source_index.md). Source IDs identify entries there. This is the broad project map requested; specialist research packs come later.

## Project basis

The local README, controller design notes and inverter parameter file describe a 48 V nominal DC bus, 500 W target, 50 Hz single-phase output and 20 kHz switching. The current AC target is about 28.85 V RMS. The controller adjusts modulation using a synchronously estimated fundamental amplitude and PI regulation. Its simulation update period is 1 µs, with a one-line-cycle estimator window. This is a specific amplitude-control architecture, so references using instantaneous PR regulation or cascaded current/voltage control should be compared explicitly.

These are descriptions of the saved project files, not independently reproduced simulation results. Grid compliance language in the README should be treated as an aspiration until applicable requirements and tests are established.

## All 27 research branches

Priority: **Now** supports understanding the existing inverter; **Next** supports grid-following simulation; **Later** supports energy integration or hardware; **Advanced** requires validated earlier stages. Reading order within each source cell runs left to right.

| # | Topic | Priority / prerequisites | Core sources | Question or exercise that closes the learning step |
|---|---|---|---|---|
| 1 | Microgrid fundamentals | Now | S21, S03 | Draw the power paths and identify which element establishes AC frequency and DC-bus voltage in each operating mode. |
| 2 | Single-phase H-bridge | Now; circuit basics | S04, S03, S07 | Derive bridge states and relate DC voltage, modulation and fundamental RMS output. |
| 3 | SPWM / unipolar PWM | Now; 2 | S04, S05, S07 | Compare bipolar/unipolar spectra at the same carrier rate and operating point. |
| 4 | LC filter | Now; 2–3 | S04, S01, S07 | Derive the loaded transfer function with ESR/damping and sweep load; distinguish natural resonance from actual −3 dB cutoff. |
| 5 | Islanded voltage control | Now; 4 and 6 | S07, S02 | Explain amplitude PI versus instantaneous waveform control; test load steps and nonlinear loads. |
| 6 | PI controller design | Now; transfer functions | S02, S01, S17 | Include estimator delay, discretization and saturation; calculate stability margins and test anti-windup. |
| 7 | Harmonics / FFT / THD | Now; 3 | S13, S07 | Specify voltage/current, analysis window, harmonic range and units; compare an integer-cycle FFT with another estimator. |
| 8 | LCL filter | Next; 4 and 6 | S08, S12 | Model resonance and damping including grid inductance and digital delay; sweep tolerances. |
| 9 | Grid model and impedance | Next; 8 | S08, S21 | Replace an ideal source with R–L impedance and evaluate control sensitivity. |
| 10 | Single-phase PLL | Next; 6 | S09, S08 | Explain orthogonal signal generation; test frequency step, phase jump, sag, harmonics and noise. |
| 11 | Grid-following current control | Next; 8–10 | S10, S08, S11 | Derive the actual current plant and test tracking, current limiting and weak-grid interaction. |
| 12 | Active/reactive power control | Next; 10–11 | S08, S22 | Define P/Q signs and RMS/peak conventions; test independent commands and current limits. |
| 13 | PV single-diode model | Later; circuit basics | S15, S11 | Validate cell/module scaling and I–V/P–V curves across irradiance and temperature. |
| 14 | DC/DC converter | Later; 6 | S01, S17, S16 | Choose voltage-ratio range and bidirectional requirements; derive averaged dynamics and current stresses. |
| 15 | MPPT | Later; 13–14 | S11, S15 | Compare P&O/incremental-conductance behavior with a swept maximum-power reference, including irradiance changes. |
| 16 | Battery integration | Later; 14 | S18, S16 | Define SOC limits, charge/discharge limits, bus ownership and behavior when battery power is unavailable. |
| 17 | Grid-forming inverter | Advanced; 5, 9, 16 | S21, S22, S23 | Explain voltage/frequency establishment and current limiting; test islanded operation and source power limits. |
| 18 | P–f / Q–V droop | Advanced; 12 and 17 | S21, S22 | Derive chosen droop signs and units; test sharing across unequal impedances and investigate resistive-network coupling. |
| 19 | Islanding detection | Advanced; 10–12 | S26, S30, S29 | Distinguish intentional islanding from unwanted energization; later derive tests from applicable full-text requirements. |
| 20 | Grid/island transition | Advanced; 17–19 | S22, S23, S21 | Define a supervisory state machine with reconnection criteria; test phase mismatch, timing and current peaks. |
| 21 | C2000 real-time control | Later; 6 and 14 | S17, S19, S20 | Port a bounded control exercise and measure execution time against the chosen interrupt budget. |
| 22 | PWM / ADC / interrupts / protection | Before power hardware; 21 | S20, S19, S07 | Draw ADC-to-PWM timing and implement a measured protection path; include missed deadlines and sensor faults. |
| 23 | Power PCB design | Later; 2, 14, 22 | S04, S01, S24 | Identify commutation loops, current returns, sensing paths, thermal paths and component-rating evidence. |
| 24 | GaN / SiC | Later; 23 | S01, S24, S25 | Compare silicon and wide-bandgap candidates at actual voltage/current/frequency, including total losses and driver constraints. |
| 25 | Grid standards | Scope now; clauses before grid interface | S26, S27, S28, S29, S30 | Build a jurisdiction/edition/clause/test-evidence matrix. Keep drafts and international comparisons distinct. |
| 26 | Modbus / SunSpec | Later; telemetry definitions | S33, S31, S32, S34 | Choose models, units, scaling and access rights; test decoding, exceptions and stale data. |
| 27 | Monitoring / acquisition | Later; 26 | S34, S35 | Specify timestamps, rates and retention; inject dropped packets and compare dashboard data with raw logs. |

## Recommended reading sequence

1. **Understand the existing plant:** S04 H-bridge/PWM lectures, the local inverter parameters, then S07. Produce an annotated block diagram and explain the modulation-to-voltage relationship.
2. **Understand feedback and evidence:** S02/S01 selected feedback material, local controller notes, then S13. Produce a measurement specification and a list of assumptions behind the reported transient results.
3. **Prepare grid following:** S08 filter/control material → S12 → S09 → S10/S11. Produce separate LCL, PLL and current-loop test plans before integrating them.
4. **Add energy sources:** S15 → S01/S17 → S16/S18 → S11 MPPT. Produce a power-balance diagram and bus-voltage control assignment.
5. **Translate to hardware:** S17 → S19/S20 with S04 hardware modules. Select actual device documentation after electrical and thermal requirements are set.
6. **Study advanced operation:** S21 → S22 → S23 after obtaining its full text. Produce a droop-control and transition test plan.
7. **Integrate communications:** S33 → S31/S32 → S34/S35. Begin with read-only telemetry and validated units before supervisory controls.

Read standards scope early and complete detailed applicability work before any physical grid interface. This is a learning order, not a calendar commitment.

## Corrections and design questions exposed by the map

- **Voltage architecture:** the saved parameters imply an ideal fundamental ceiling of 0.95 × 42 / √2 = 28.21 V RMS at the low-bus condition, below the 28.85 V target even before losses. This arithmetic follows from the project's modulation convention. Resolve regulation range before final hardware sizing.
- **Grid voltage:** the present bridge output is a low-voltage AC research bus. A future mains interface needs an explicitly chosen voltage-conversion/isolation architecture; the README diagram alone does not specify it.
- **Control rate:** a 1 µs simulation PI update is not a demonstrated embedded ISR design. Separate integration step, control sample period, PWM update period and measurement-window delay.
- **Controller comparisons:** S07 is valuable precisely because it allows comparison with a different regulator. Do not present the current amplitude PI loop as a direct TI implementation.
- **Reference match:** the original notes cite a three-phase MathWorks example. S10/S11 provide closer single-phase starting points while S12 remains useful with a clear three-phase caveat.
- **Standards:** CEA's 2013/2019 DG texts are the initial India-specific source set [S26]. IEEE's scope explicitly uses a 60 Hz source [S29]. The CEA notice dated 4 August 2026 is a draft [S28]. None establishes compliance for the current model.
- **Metrics:** a good rolling-RMS result does not by itself establish instantaneous waveform quality or fault behavior. Separate amplitude settling, waveform error, peak current, saturation, and THD measurements.

## Local project reading set

- [Architecture and specifications](../../README.md)
- [Existing roadmap](../../docs/ROADMAP_12_WEEKS.md)
- [Controller design notes](../../docs/closed_loop_controller_design.md)
- [LC design notes](../../docs/design_notes_lc_filter.md)
- [Inverter parameters](../../simulations/inverter/inverter_params.m)
- [Closed-loop model builder](../../simulations/inverter/build_closed_loop_model.m)
- [Closed-loop run script](../../simulations/inverter/run_closed_loop_inverter.m)
- [PV single-diode implementation](../../simulations/pv_model/pv_single_diode.m)

Only the README, controller notes and inverter parameters were read for the project basis in this pass. The other files are indexed for subsequent specialist study. Existing reported simulation results have not been re-run.
