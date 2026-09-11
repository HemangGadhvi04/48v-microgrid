# Gate 0: Hardware/Firmware Interface Contract

This document explicitly defines the electrical and logical boundary between the F28379D control software and the physical power/converter hardware. This contract freezes the interface to ensure PCB routing and C2000 firmware configuration remain synchronized.

## Signal Mapping Table

| Function | C2000 Peripheral | LaunchPad Pin | Electrical Interface | Sampling/Control Requirement |
|---|---|---|---|---|
| DC/DC input leg (High) | ePWM1A / GPIO0 | J4:40 | Gate driver (UCC27211A) | 20 kHz, complementary |
| DC/DC input leg (Low) | ePWM1B / GPIO1 | J4:39 | Gate driver (UCC27211A) | 20 kHz, hardware dead-band |
| DC/DC output leg (High)| ePWM2A / GPIO2 | J4:38 | Gate driver (UCC27211A) | 20 kHz, complementary |
| DC/DC output leg (Low) | ePWM2B / GPIO3 | J4:37 | Gate driver (UCC27211A) | 20 kHz, hardware dead-band |
| H-Bridge Leg A (High) | ePWM3A / GPIO4 | J4:36 | Gate driver (UCC27211A) | 20 kHz, complementary |
| H-Bridge Leg A (Low) | ePWM3B / GPIO5 | J4:35 | Gate driver (UCC27211A) | 20 kHz, hardware dead-band |
| H-Bridge Leg B (High) | ePWM4A / GPIO6 | J8:80 | Gate driver (UCC27211A) | 20 kHz, complementary |
| H-Bridge Leg B (Low) | ePWM4B / GPIO7 | J8:79 | Gate driver (UCC27211A) | 20 kHz, hardware dead-band |
| PV Voltage | ADCA / ADCIN14 | J3:23 | Conditioned 0-3.3V | EPWM1_SOCA_ZERO triggered |
| DC Bus Voltage | ADCC / ADCINC3 | J3:24 | Conditioned 0-3.3V | EPWM1_SOCA_ZERO triggered |
| PV Current | ADCB / ADCINB3 | J3:25 | TMCS1123, centered | EPWM1_SOCA_ZERO triggered |
| DC Inductor Current | ADCA / ADCINA3 | J3:26 | TMCS1123, centered | EPWM1_SOCA_ZERO triggered |
| Grid (Microgrid) Voltage| ADCC / ADCINC2 | J3:27 | Isolated sensing, centered | EPWM1_SOCA_ZERO triggered |
| Utility (PCC) Voltage | ADCB / ADCINB2 | J3:28 | Isolated sensing, centered | EPWM1_SOCA_ZERO triggered |
| Grid Current (Inverter) | ADCA / ADCINA2 | J3:29 | TMCS1123, centered | EPWM1_SOCA_ZERO triggered |
| Heatsink Temperature | ADCA / ADCINA0 | J3:30 | NTC / conditioned 0-3.3V | EPWM1_SOCA_ZERO triggered |
| Overcurrent Trip | TZ1 / GPIO24 | J4:34 | Hardware comparator | Active-low async shutdown (OSHT) |
| Emergency Stop | INPUTXBAR2 / GPIO25 | J4:33 | Mechanical button/latch | Active-low, tied to hardware enable chain |
| Precharge Relay | GPIO10 | J4:32 | Relay coil driver | Active-high |
| Main Contactor | GPIO11 | J4:31 | Relay coil driver | Active-high |
| Grid Breaker | GPIO67 | J1:5 | Contactor coil driver | Active-high, interlocked |
| PWM Gate Enable (ARM) | GPIO111 | J1:6 | Driver EN pin AND logic | Active-high, safe default OFF |
| Bias Power Good | GPIO32 | J1:2 | Supervisor / UVLO | Active-high |
| RS-485 TX | SCIB_TX / GPIO18| J1:4 | Isolated Transceiver | Modbus RTU, 9600 baud |
| RS-485 RX | SCIB_RX / GPIO19| J1:3 | Isolated Transceiver | Modbus RTU, 9600 baud |
| RS-485 Driver Enable | GPIO22 | J1:8 | Transceiver DE pin | Active-high |
| ISR Timing Marker | GPIO60 | J1:7 | Oscilloscope probe | Toggled at start/end of control ISR |


## Frozen Definitions & Conventions

*   **PWM Frequency:** Nominal 20 kHz (100 MHz ePWM clock, `TBPRD` = 2500, up-down count).
*   **ADC Trigger Point:** `EPWM1_SOCA_ZERO` (Triggers on ePWM1 counter = 0).
*   **Control ISR:** CPU1 PIE (Mapped to ADCINT1, triggered by ADCA end-of-conversion). Target execution budget is <35 μs.
*   **Current Polarity:** Positive direction convention is flowing *out* of the node towards the load/grid (generator convention).
*   **Voltage Polarity:** Positive referenced to the common system ground rail (0V).
*   **PWM Polarity:** Active-high at the F28379D GPIO. (High = logic 1 = upper FET ON).
*   **Gate-Enable Polarity:** Active-high `PWM_ARM`. Default state is LOW (gates disabled).
*   **Fault Polarity:** Active-low hardware trips (`TRIP_LATCH_N`, `ESTOP_N`).
*   **Trip-Zone Routing:** Hardware comparators route via `INPUTXBAR1` to `TZ1` and `ESTOP_N` routes via `INPUTXBAR2` to `TZ2`. Triggers One-Shot (OSHT) force on ePWM1-4, forcing all pins to logic LOW immediately.
*   **Modbus UART:** `SCI-B` mapped to GPIO18/19.
*   **Debugging:** LaunchPad JTAG.

**Digital interface exit criterion achieved.** Analog-interface release remains
open for the voltage and temperature channels listed as `BLOCKED` below.

## Analog Calibration & Scaling

For every ADC input, the table below derives scaling **only** from the actual selected hardware BOM and schematic values (per `hardware/sensing_inputs.json`). Any channel lacking an exact frozen part number or schematic circuit is marked BLOCKED pending Gate 2 completion.

| Signal | Exact Component | Schematic Network | ADC Channel | Physical Range | ADC Range | Equation (Counts to Physical) | Status |
|---|---|---|---|---:|---:|---|---|
| PV Voltage | TBD (Buffer IC) | 200k/10k divider + 100mV offset | ADCA_14 | 0 - 65 V | 0.1 - 3.2V | TBD (Blocked pending Buffer P/N) | **BLOCKED** |
| DC Bus Voltage | TBD (Buffer IC) | 200k/10k divider + 100mV offset | ADCC_3 | 0 - 60 V | 0.1 - 2.95V | TBD (Blocked pending Buffer P/N) | **BLOCKED** |
| PV Current | TMCS1123B2AQDVGRQ1 | direct / 1kΩ + 4.7nF filter | ADCB_3 | ±25 A | 0.4 - 2.9V | `I = ((counts / 4095) * 3.3 - 1.65) / 0.05` | **PASS** |
| DC Inductor Current| TMCS1123B2AQDVGRQ1 | direct / 1kΩ + 4.7nF filter | ADCA_3 | ±25 A | 0.4 - 2.9V | `I = ((counts / 4095) * 3.3 - 1.65) / 0.05` | **PASS** |
| Grid Current | TMCS1123B2AQDVGRQ1 | direct / 1kΩ + 4.7nF filter | ADCA_2 | ±30 A | 0.15 - 3.15V| `I = ((counts / 4095) * 3.3 - 1.65) / 0.05` | **PASS** |
| PCC Voltage | TBD (Iso Amp IC) | TBD (Gain = 30 mV/V) | ADCC_2 | ±45 V | 0.3 - 3.0V | TBD (Blocked pending Iso Amp P/N) | **BLOCKED** |
| Utility Voltage | TBD (Iso Amp IC) | TBD (Gain = 30 mV/V) | ADCB_2 | ±45 V | 0.3 - 3.0V | TBD (Blocked pending Iso Amp P/N) | **BLOCKED** |
| Heatsink Temp | TBD (Sensor IC) | 500mV @ 0°C, 10mV/°C | ADCA_0 | -20 - 125 °C| 0.3 - 1.75V | TBD (Blocked pending Sensor P/N) | **BLOCKED** |
