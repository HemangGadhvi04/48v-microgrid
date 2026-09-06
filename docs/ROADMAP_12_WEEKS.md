# Phase 1: 12-Week Simulation & Foundation Roadmap

This document outlines the week-by-week plan for **Phase 1: Simulation Foundation** of the 48V Open-Source Microgrid Research Platform.

---

## Month 1: Fundamentals & Open-Loop Inverter Simulation

### Week 1: Big Picture, Repository Setup & Math Foundations
- [x] Establish Git repository, structure, and documentation conventions.
- [x] Configure MATLAB environment and verify Simscape Electrical toolbox.
- [ ] Derive full-bridge (H-bridge) voltage and switching relationships.
- [ ] Study Unipolar vs. Bipolar Sinusoidal Pulse-Width Modulation (SPWM).
- [ ] **Deliverable**: `inverter_params.m` parameter script and filter design equations.

### Week 2: First Inverter Simulation (Ideal Switching)
- [ ] Construct ideal H-bridge inverter in MATLAB/Simulink.
- [ ] Implement SPWM carrier/reference generator ($50\text{ Hz}$ sine, $20\text{ kHz}$ triangle).
- [ ] Measure unfiltered 3-level output voltage ($+V_{dc}, 0, -V_{dc}$).
- [ ] Run FFT spectrum analysis to verify switching harmonics at $2f_{sw} \pm n f_o$ (Unipolar).
- [ ] **Deliverable**: Functional open-loop H-bridge model with harmonic spectrum plot.

### Week 3: Output LC Filter Design & Analysis
- [ ] Derive LC low-pass filter transfer function:
  $$G(s) = \frac{1}{L C s^2 + \frac{L}{R_{load}} s + 1}$$
- [ ] Calculate inductor value based on peak-to-peak current ripple $\Delta I_L \le 20\%\text{--}40\%$.
- [ ] Calculate capacitor value based on reactive power consumption $\le 5\% P_{nom}$.
- [ ] Simulate LC filter under $500\text{ W}$ resistive load and record voltage THD.
- [ ] **Deliverable**: Filtered sinusoidal output waveform achieving $\text{THD} < 5\%$.

### Week 4: Control Foundations & Load Steps
- [ ] Study Proportional-Integral (PI) and Proportional-Resonant (PR) controller theory.
- [ ] Model closed-loop voltage regulation for islanded mode.
- [ ] Simulate dynamic response under $50\% \rightarrow 100\%$ load steps ($250\text{ W} \rightarrow 500\text{ W}$).
- [ ] Record settling time and voltage sag.
- [ ] **Deliverable**: Voltage-regulated islanded inverter model with transient analysis.

---

## Month 2: Grid Synchronization & LCL Filter Design

### Week 5: LCL Filter Design & Passive Damping
- [ ] Contrast LC vs. LCL filter topologies (size, cost, high-frequency attenuation $60\text{ dB/decade}$).
- [ ] Calculate inverter-side inductor ($L_1$), grid-side inductor ($L_2$), and filter capacitor ($C_f$).
- [ ] Calculate resonant frequency:
  $$f_{res} = \frac{1}{2\pi} \sqrt{\frac{L_1 + L_2}{L_1 L_2 C_f}}$$
- [ ] Verify $10 f_{grid} < f_{res} < 0.5 f_{sw}$.
- [ ] Implement passive damping resistor ($R_d = \frac{1}{3} \frac{1}{2\pi f_{res} C_f}$) in series with $C_f$.
- [ ] **Deliverable**: Frequency response Bode plot and LCL filter Simulink block.

### Week 6: Grid Interface & Stiff AC Source Modeling
- [ ] Build a stiff single-phase AC grid model ($V_{grid}, L_{grid}, R_{grid}$).
- [ ] Implement circuit breaker subsystem for grid connection/disconnection.
- [ ] Analyze current injection and back-EMF dynamics.
- [ ] **Deliverable**: Interfaced grid-tie model with variable grid impedance.

### Week 7: Phase-Locked Loop (PLL) Design
- [ ] Study Single-Phase SOGI-PLL (Second-Order Generalized Integrator).
- [ ] Generate orthogonal system ($\alpha\text{-}\beta$) from single-phase voltage.
- [ ] Implement Park transformation ($dq$) and PI loop filter to track grid angle $\theta$ and frequency $\omega$.
- [ ] Test PLL under grid frequency steps ($50\text{ Hz} \rightarrow 52\text{ Hz}$) and harmonic distortion.
- [ ] **Deliverable**: SOGI-PLL subsystem with fast locking time ($< 2$ grid cycles).

### Week 8: Complete Grid-Following Inverter Simulation
- [ ] Implement inner current loop (Synchronous Reference Frame $dq$ or Stationary $\alpha\beta$ PR).
- [ ] Synchronize current reference $I_{ref}$ with PLL angle $\theta$.
- [ ] Demonstrate sinusoidal current injection at Unity Power Factor ($\text{PF} = 1.0$).
- [ ] Test non-unity power factor injection (reactive power support, $+/- Q$).
- [ ] **Deliverable**: Full grid-following inverter simulation injecting clean $500\text{ W}$ into AC grid.

---

## Month 3: Solar PV Modeling, MPPT & System Integration

### Week 9: Single-Diode PV Model from First Principles
- [ ] Derive 5-parameter single-diode model equation:
  $$I = I_{ph} - I_0 \left[ \exp\left(\frac{q(V + I R_s)}{A k T}\right) - 1 \right] - \frac{V + I R_s}{R_{sh}}$$
- [ ] Implement manual MATLAB script/function without using black-box Simscape PV blocks.
- [ ] Plot I-V and P-V characteristic curves under varying irradiance ($200\text{--}1000\text{ W/m}^2$) and temperature ($10\text{--}60^\circ\text{C}$).
- [ ] **Deliverable**: Verified single-diode PV MATLAB block with curve plotting utility.

### Week 10: Maximum Power Point Tracking (MPPT)
- [ ] Implement Perturb & Observe (P&O) MPPT algorithm in MATLAB/Simulink.
- [ ] Tune perturbation step size $\Delta V$ and sampling frequency to balance tracking speed vs. steady-state oscillation.
- [ ] Test dynamic MPPT efficiency during rapid irradiance ramps.
- [ ] **Deliverable**: P&O MPPT block achieving $> 98\%$ tracking efficiency.

### Week 11: End-to-End Solar-to-Grid Integration
- [ ] Connect PV model to DC-DC Boost stage.
- [ ] Regulate $48\text{ V}$ DC link voltage.
- [ ] Feed DC power into the grid-following H-bridge inverter.
- [ ] Simulate full solar irradiance transition and observe seamless power flow to the grid.
- [ ] **Deliverable**: Complete end-to-end solar microgrid simulation model.

### Week 12: Documentation, Benchmarking & Portfolio Release
- [ ] Compile comprehensive technical documentation and simulation reports.
- [ ] Generate publication-quality waveform figures and harmonic spectrum comparisons.
- [ ] Publish organized GitHub repository with clean documentation for portfolio and recruiter presentations.
- [ ] Review hardware specifications for Phase 2 kickoff.
- [ ] **Deliverable**: Phase 1 Final Technical Report & Git Release v1.0.
