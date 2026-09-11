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

**Exit Criterion Achieved**: No remaining TBD on safety-critical or PCB-routing-critical signals.

## Analog Calibration & Scaling

| ADC Channel | Signal | Sensor | Range | Scaling Factor | ADC Voltage | ADC Equation (Counts to Physical) |
|---|---|---|---|---|---|---|
| ADCA_14 | PV Voltage | Divider + Buffer | 0 - 100V | 1/33.33 | 0 - 3.0V | `V = (counts / 4095) * 3.3 * 33.33` |
| ADCC_3  | DC Bus Voltage | Divider + Buffer | 0 - 100V | 1/33.33 | 0 - 3.0V | `V = (counts / 4095) * 3.3 * 33.33` |
| ADCB_3  | PV Current | TMCS1123 (50mV/A) | ±30A | 50 mV/A (Offset: 1.65V) | 0.15 - 3.15V | `I = ((counts / 4095) * 3.3 - 1.65) / 0.05` |
| ADCA_3  | DC Inductor Current | TMCS1123 (50mV/A) | ±30A | 50 mV/A (Offset: 1.65V) | 0.15 - 3.15V | `I = ((counts / 4095) * 3.3 - 1.65) / 0.05` |
| ADCC_2  | Grid Voltage | AMC1301 + AMC3330 | ±400V peak | 1/150 (Offset: 1.65V) | 0.31 - 2.98V | `V = ((counts / 4095) * 3.3 - 1.65) * 150` |
| ADCB_2  | Utility Voltage | AMC1301 + AMC3330 | ±400V peak | 1/150 (Offset: 1.65V) | 0.31 - 2.98V | `V = ((counts / 4095) * 3.3 - 1.65) * 150` |
| ADCA_2  | Grid Current | TMCS1123 (50mV/A) | ±30A | 50 mV/A (Offset: 1.65V) | 0.15 - 3.15V | `I = ((counts / 4095) * 3.3 - 1.65) / 0.05` |
| ADCA_0  | Heatsink Temp | 10k NTC | 0 - 100°C | Non-linear | 0 - 3.3V | `T = SteinhartHart(counts)` |

*Note: These scale equations are initial design targets to freeze the analog chain design. Final fine-tuning offsets must be written to calibration EEPROM.*
