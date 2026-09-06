# The 48V Open-Source Microgrid Research Platform (500W)

An open-source, research-grade microgrid development platform designed for lab-bench exploration of grid-interactive inverters, grid code compliance, advanced power electronics control, and seamless islanding.

![Status](https://img.shields.io/badge/status-active%20development-blue)
![Platform](https://img.shields.io/badge/platform-MATLAB%20Simulink%20%7C%20C2000-orange)
![Voltage](https://img.shields.io/badge/DC%20Bus-48V-green)
![Power](https://img.shields.io/badge/Power-500W-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## 1. System Architecture

```
+---------------------------------------------------------------------------------------------------+
|                                  48V MICROGRID RESEARCH PLATFORM                                  |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|  +--------------------+         +-------------------+         +--------------------+              |
|  |   Solar PV Array   | ------> |  Synch Buck-Boost | ------> |     48V DC Bus     | <---------+  |
|  | (1-Diode Model/MPPT)         |   (C2000 TMS320)  |         | (Battery Interface)|           |  |
|  +--------------------+         +-------------------+         +--------------------+           |  |
|                                                                         |                      |  |
|                                                                         v                      |  |
|                                                               +--------------------+           |  |
|                                                               | Single-Phase VSI   |           |  |
|                                                               | (H-Bridge SPWM)    |           |  |
|                                                               +--------------------+           |  |
|                                                                         |                      |  |
|                                                                         v                      |  |
|                                                               +--------------------+           |  |
|                                                               |  LC / LCL Filter   |           |  |
|                                                               | (Resonance Damped) |           |  |
|                                                               +--------------------+           |  |
|                                                                         |                      |  |
|                                                                         v                      |  |
|                                                               +--------------------+           |  |
|                                                               | Grid / Microgrid   |           |  |
|                                                               | (PLL, Droop, Sync) |           |  |
|                                                               +--------------------+           |  |
|                                                                                                   |
|  Telemetry: SunSpec Modbus RTU (RS-485) ---> Raspberry Pi (Python) ---> InfluxDB ---> Grafana   |
+---------------------------------------------------------------------------------------------------+
```

---

## 2. Technical Specifications

| Parameter | Baseline Value | Hardware Target |
| :--- | :--- | :--- |
| **DC Bus Voltage ($V_{dc}$)** | $48\text{ V nominal}$ ($42\text{ V} - 54\text{ V}$) | $48\text{ V}$ LiFePO4 Battery / Emulated DC |
| **Rated Output Power ($P_{nom}$)** | $500\text{ W}$ | $500\text{ W}$ Continuous |
| **Grid / AC Output Frequency ($f_{grid}$)** | $50\text{ Hz}$ ($\pm 0.5\text{ Hz}$) | $50\text{ Hz}$ |
| **Switching Frequency ($f_{sw}$)** | $20\text{ kHz}$ (Baseline) | $50\text{ kHz} - 100\text{ kHz}$ (GaN/SiC) |
| **Output Filter Topology** | Stage 1: LC $\rightarrow$ Stage 2: LCL | Passively/Actively Damped LCL |
| **Total Harmonic Distortion (THD)** | $< 5\%$ ($< 3\%$ individual harmonics) | IEEE 1547 / IEC 61727 compliant |
| **Primary Controller** | MATLAB/Simulink Simulation | TI C2000 LaunchPad (TMS320F28379D) |
| **Communication Protocol** | SunSpec Modbus RTU over RS-485 | Modbus RTU + InfluxDB + Grafana |

---

## 3. Four-Phase Master Roadmap

- [ ] **Phase 1: Simulation Foundation (Months 1–3)**
  - Single-phase H-bridge inverter with Unipolar/Bipolar SPWM
  - LC filter vs. LCL filter design and frequency-response verification
  - Single-diode PV model & Perturb-and-Observe (P&O) MPPT
  - SOGI-PLL (Second-Order Generalized Integrator) grid synchronization
  - Closed-loop PR / PI current control injecting into a stiff AC grid
- [ ] **Phase 2: Power Electronics Hardware (Months 4–7)**
  - Synchronous Buck-Boost DC-DC converter prototype
  - Digital PI voltage/current control in C on TI C2000 TMS320F28379D
  - Custom 4-layer PCB design (KiCad), gate drivers, shunt/Hall current sensing
- [ ] **Phase 3: Battery & Grid Interface (Months 8–11)**
  - Grid emulator testbench (programmable AC source / back-to-back inverter)
  - Droop control ($P\text{-}f$ and $Q\text{-}V$) for autonomous microgrid operation
  - Anti-islanding detection and seamless transfer logic
- [ ] **Phase 4: Communications & SCADA Dashboard (Months 12+)**
  - SunSpec Modbus map implementation over RS-485
  - Edge gateway on Raspberry Pi running Python `pymodbus`
  - Time-series logging with InfluxDB and real-time visualization with Grafana

---

## 4. Repository Structure

```
.
├── README.md                     # Project overview and specifications
├── .gitignore                    # Ignore rules for MATLAB, Python, KiCad
├── docs/                         # Technical documentation, derivations, and guides
│   ├── ROADMAP_12_WEEKS.md       # Detailed 12-week Phase 1 simulation breakdown
│   ├── design_notes_lc_filter.md # LC and LCL filter mathematical derivations
│   └── archive/                  # Historical planning transcripts and archives
├── simulations/                  # MATLAB and Simulink models
│   ├── inverter/                 # H-bridge, SPWM generator, and LC/LCL filter models
│   ├── pv_model/                 # Single-diode PV model functions and I-V curves
│   ├── mppt/                     # P&O and incremental conductance MPPT
│   └── grid_sync/                # SOGI-PLL and grid monitoring blocks
├── hardware/                     # KiCad schematics, PCB layouts, and BOMs
├── firmware/                     # TI C2000 CCS projects and C control routines
└── comms/                        # Modbus RS-485, Python edge polling, Grafana dashboards
```

---

## 5. Quickstart & Phase 1 Execution

### Prerequisites
- **MATLAB & Simulink** (R2024b / R2025b or later with Simscape Electrical)
- **Git**

### Running Inverter Parameters
Initialize parameters in MATLAB:
```matlab
cd simulations/inverter
inverter_params
```
Open the Simulink model:
```matlab
open_system('hbridge_inverter_lc.slx')
sim('hbridge_inverter_lc')
```
