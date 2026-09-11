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

Current simulation baseline: the complete PV-to-grid chain is executable and
passes automated electrical checks. The standalone grid-following baseline
injects 499.5 W at 0.9994 power factor with 2.72% current THD and separately
demonstrates 150 var reactive-power injection. The coupled run holds the 48 V
bus within its acceptance range across irradiance and temperature changes,
captures at least 99.5% of available PV power in all settled windows, exercises
both buck and boost operation, and closes its energy balance to 0.000032% of PV
energy. This is a 28.85 V RMS research-grid simulation and is not a 230 V
utility connection.

The portable Phase 2 firmware foundation is also executable on a host compiler:
PI and P&O control, four-switch buck-boost control, SOGI-PLL, PR current control,
and the protection supervisor pass their tests. See
[`docs/PROJECT_EXECUTION_STATUS.md`](docs/PROJECT_EXECUTION_STATUS.md) for the
current completion estimate and remaining execution gates.

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
│   ├── phase1_simulation_report.md # Validated Phase 1 results and limits
│   ├── phase2_hardware_specification.md # Isolated hardware-test requirements
│   ├── design_notes_lc_filter.md # LC and LCL filter mathematical derivations
│   └── archive/                  # Historical planning transcripts and archives
├── simulations/                  # MATLAB and Simulink models
│   ├── inverter/                 # H-bridge, SPWM generator, and LC/LCL filter models
│   ├── pv_model/                 # Single-diode PV model functions and I-V curves
│   ├── mppt/                     # P&O and incremental conductance MPPT
│   ├── grid_sync/                # SOGI-PLL and grid monitoring blocks
│   ├── system/                   # Coupled PV/DC-DC/DC-link/grid validation
│   ├── battery/                  # Bidirectional battery ECM and energy validation
│   └── microgrid/                # Droop, islanding, synchronization and reconnection
├── hardware/                     # KiCad schematics, PCB layouts, and BOMs
├── firmware/                     # TI C2000 CCS projects and C control routines
└── comms/                        # Modbus RS-485, Python edge polling, Grafana dashboards
```

---

## 5. Quickstart & Phase 1 Execution

Run all fast host-side hardware, firmware, protocol, and generated-artifact checks:

```sh
make test
```

Run the longer MATLAB simulation regressions separately:

```sh
make test-matlab
```

### Prerequisites
- **MATLAB & Simulink** (R2024b / R2025b or later with Simscape Electrical)
- **Git**

Run the complete Phase 1 regression suite from the repository root:

```matlab
cd('/Users/hemanggadhvi/Desktop/48V microgrid')
addpath('/Users/hemanggadhvi/Desktop/48V microgrid/simulations')
summary = run_phase1_validation();
```

### Running Inverter Parameters
Initialize parameters in MATLAB:
```matlab
cd simulations/inverter
inverter_params
```
Open the Simulink model:
```matlab
open_system('hbridge_inverter_lc_open_loop.slx')
sim('hbridge_inverter_lc_open_loop')
```

Build or open and run the open-loop Week 2 model:
```matlab
cd('/Users/hemanggadhvi/Desktop/48V microgrid/simulations/inverter')
run('run_open_loop_inverter.m')
```

Run the closed-loop islanded inverter milestone. It regulates the 28.85 V RMS
output through a 250 W to 500 W resistive load step:
```matlab
cd('/Users/hemanggadhvi/Desktop/48V microgrid/simulations/inverter')
run('run_closed_loop_inverter.m')
```

Design and validate the LCL filter, grid interface, SOGI-PLL, and complete
grid-following inverter:

```matlab
cd('/Users/hemanggadhvi/Desktop/48V microgrid/simulations/grid_tie')
run('design_lcl_filter.m')
run('run_lcl_grid_model.m')

cd('/Users/hemanggadhvi/Desktop/48V microgrid/simulations/grid_sync')
run('run_sogi_pll_tests.m')

cd('/Users/hemanggadhvi/Desktop/48V microgrid/simulations/grid_tie')
run('run_grid_following_model.m')
```

Validate the PV source and P&O MPPT:

```matlab
cd('/Users/hemanggadhvi/Desktop/48V microgrid/simulations/pv_model')
run('run_pv_validation.m')

cd('/Users/hemanggadhvi/Desktop/48V microgrid/simulations/mppt')
run('run_po_mppt_validation.m')
```

Run the end-to-end PV, four-switch buck-boost, dynamic 48 V DC-link, switching
inverter, LCL filter, and grid validation:

```matlab
cd('/Users/hemanggadhvi/Desktop/48V microgrid/simulations/system')
report = run_solar_grid_validation();
```

See [`docs/phase1_simulation_report.md`](docs/phase1_simulation_report.md) for
the retained metrics, acceptance criteria, and limits of the result. The next
execution stage is the isolated Phase 2 power-electronics testbench defined in
[`docs/phase2_hardware_specification.md`](docs/phase2_hardware_specification.md).

Run the battery and microgrid-transition regression suite:

```matlab
addpath('/Users/hemanggadhvi/Desktop/48V microgrid/simulations')
summary = run_phase3_validation();
```

See [`docs/phase3_simulation_report.md`](docs/phase3_simulation_report.md) for
the validated scope and the limits of the dynamic-phasor transition evidence.

Validate the Phase 4 Modbus, SunSpec, logging, and InfluxDB gateway code:

```sh
python3 -m unittest discover -s comms/tests -v
python3 comms/simulate_gateway.py
```

See [`docs/phase4_telemetry_report.md`](docs/phase4_telemetry_report.md) for the
implemented data path and remaining physical commissioning gates.
