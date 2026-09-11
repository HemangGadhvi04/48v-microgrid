# Phase 1: 12-Week Simulation & Foundation Roadmap

This document outlines the week-by-week plan for **Phase 1: Simulation Foundation** of the 48V Open-Source Microgrid Research Platform.

---

## Month 1: Fundamentals & Open-Loop Inverter Simulation

### Week 1: Big Picture, Repository Setup & Math Foundations
- [x] Establish Git repository, structure, and documentation conventions.
- [x] Configure MATLAB environment and verify Simscape Electrical toolbox.
- [ ] Derive full-bridge (H-bridge) voltage and switching relationships.
- [ ] Study Unipolar vs. Bipolar Sinusoidal Pulse-Width Modulation (SPWM).
- [x] **Deliverable**: `inverter_params.m` parameter script and filter design equations.

### Week 2: First Inverter Simulation (Ideal Switching)
- [x] Construct ideal H-bridge inverter in MATLAB/Simulink.
- [x] Implement SPWM carrier/reference generator ($50\text{ Hz}$ sine, $20\text{ kHz}$ triangle).
- [x] Measure unfiltered 3-level output voltage ($+V_{dc}, 0, -V_{dc}$).
- [x] Run FFT spectrum analysis to verify switching harmonics at $2f_{sw} \pm n f_o$ (Unipolar).
- [x] **Deliverable**: Functional open-loop H-bridge model with harmonic spectrum plot (`hbridge_inverter_lc_open_loop.slx`).

### Week 3: Output LC Filter Design & Analysis
- [x] Derive LC low-pass filter transfer function:
  $$G(s) = \frac{1}{L C s^2 + \frac{L}{R_{load}} s + 1}$$
- [x] Calculate inductor value based on peak-to-peak current ripple $\Delta I_L \le 20\%\text{--}40\%$.
- [x] Calculate capacitor value based on reactive power consumption $\le 5\% P_{nom}$.
- [x] Simulate LC filter under $500\text{ W}$ resistive load and record voltage THD.
- [x] **Deliverable**: Filtered sinusoidal output waveform achieving $\text{THD} < 5\%$.

### Week 4: Control Foundations & Load Steps
- [ ] Study Proportional-Integral (PI) and Proportional-Resonant (PR) controller theory.
- [x] Model closed-loop voltage regulation for islanded mode.
- [x] Simulate dynamic response under $50\% \rightarrow 100\%$ load steps ($250\text{ W} \rightarrow 500\text{ W}$).
- [x] Record settling time and voltage sag.
- [x] **Deliverable**: Voltage-regulated islanded inverter model with transient analysis (`hbridge_inverter_lc_closed_loop.slx`).

---

## Month 2: Grid Synchronization & LCL Filter Design

### Week 5: LCL Filter Design & Passive Damping
- [x] Contrast LC vs. LCL filter topologies (size, cost, high-frequency attenuation $60\text{ dB/decade}$).
- [x] Calculate inverter-side inductor ($L_1$), grid-side inductor ($L_2$), and filter capacitor ($C_f$).
- [x] Calculate resonant frequency:
  $$f_{res} = \frac{1}{2\pi} \sqrt{\frac{L_1 + L_2}{L_1 L_2 C_f}}$$
- [x] Verify $10 f_{grid} < f_{res} < 0.5 f_{sw}$.
- [x] Implement passive damping resistor ($R_d = \frac{1}{3} \frac{1}{2\pi f_{res} C_f}$) in series with $C_f$.
- [x] **Deliverable**: Frequency response plot and LCL filter Simulink block (`hbridge_lcl_grid_open_loop.slx`).

### Week 6: Grid Interface & Stiff AC Source Modeling
- [x] Build a stiff single-phase AC grid model ($V_{grid}, L_{grid}, R_{grid}$).
- [x] Implement circuit breaker subsystem for grid connection/disconnection.
- [x] Analyze current injection and synchronized breaker dynamics.
- [x] **Deliverable**: Interfaced low-voltage grid-tie model with variable grid impedance.

### Week 7: Phase-Locked Loop (PLL) Design
- [x] Implement Single-Phase SOGI-PLL (Second-Order Generalized Integrator).
- [x] Generate orthogonal system ($\alpha\text{-}\beta$) from single-phase voltage.
- [x] Implement Park transformation ($dq$) and PI loop filter to track grid angle $\theta$ and frequency $\omega$.
- [x] Test PLL under a $50\text{ Hz} \rightarrow 52\text{ Hz}$ step, 20-degree phase jump, voltage sag, harmonics, and noise.
- [x] **Deliverable**: 20 kHz SOGI-PLL subsystem locking within three cycles in the combined disturbance test (`sogi_pll_validation.slx`).

### Week 8: Complete Grid-Following Inverter Simulation
- [x] Implement stationary-frame PR inner current loop.
- [x] Synchronize current reference $I_{ref}$ with PLL angle $\theta$.
- [x] Demonstrate sinusoidal current injection at unity power factor ($\text{PF} = 0.9985$ measured).
- [x] Test non-unity power factor injection (150 var while holding 499.5 W).
- [x] **Deliverable**: Grid-following switching simulation injecting 499.5 W with 2.72% current THD (`hbridge_lcl_grid_following.slx`).

---

## Month 3: Solar PV Modeling, MPPT & System Integration

### Week 9: Single-Diode PV Model from First Principles
- [x] Derive 5-parameter single-diode model equation:
  $$I = I_{ph} - I_0 \left[ \exp\left(\frac{q(V + I R_s)}{A k T}\right) - 1 \right] - \frac{V + I R_s}{R_{sh}}$$
- [x] Implement manual MATLAB script/function without using black-box Simscape PV blocks.
- [x] Plot I-V and P-V characteristic curves under varying irradiance ($200\text{--}1000\text{ W/m}^2$) and temperature ($10\text{--}60^\circ\text{C}$).
- [x] **Deliverable**: Verified 498.3 W STC single-diode PV MATLAB model and exported curves.

### Week 10: Maximum Power Point Tracking (MPPT)
- [x] Implement Perturb & Observe (P&O) MPPT algorithm in MATLAB.
- [x] Tune perturbation step size $\Delta V$ and sampling frequency to balance tracking speed vs. steady-state oscillation.
- [x] Test dynamic MPPT efficiency under irradiance and temperature steps.
- [x] **Deliverable**: P&O MPPT function exceeding 99.9% mean efficiency in settled validation windows.

### Week 11: End-to-End Solar-to-Grid Integration
- [x] Connect the PV model to an averaged four-switch buck-boost stage.
- [x] Regulate the $48\text{ V}$ DC link with cascaded PV-voltage and inductor-current control.
- [x] Feed the dynamic DC-link power into the switching grid-following H-bridge inverter.
- [x] Simulate irradiance and temperature transitions through buck and boost operation.
- [x] Verify MPPT efficiency, DC-link regulation, grid-current quality, converter limits, and reciprocal energy balance.
- [x] **Deliverable**: Complete executable solar-to-grid model in `simulations/system/` with retained CSV, MAT, and PNG evidence.

### Week 12: Documentation, Benchmarking & Portfolio Release
- [x] Compile comprehensive technical documentation and simulation reports.
- [x] Generate waveform, operating-point, converter-duty, and harmonic spectrum figures.
- [ ] Publish organized GitHub repository with clean documentation for portfolio and recruiter presentations.
- [x] Review hardware specifications and define a staged, isolated Phase 2 testbench.
- [ ] **Deliverable**: Phase 1 Final Technical Report & Git Release v1.0.

Current Phase 1 status: the technical simulation and documentation scope is complete.
The remaining Week 12 work is repository release preparation and publication. The
three unchecked study items in Weeks 1 and 4 are retained as learning exercises;
their mathematical content is already exercised by the implemented models.
