# Final Deterministic Gate 0 / Gate 1A Pre-Hardware Audit Report

This report audits the Gate 0 and Gate 1A source configuration. Physical timing,
Driverlib compatibility and shutdown behavior remain unverified until the TI
target build and LaunchPad measurements are complete.

| Item | Requirement | Status | Verification Evidence |
|---|---|---|---|
| **1** | Verify module headers | **PASS** | Headers contain full prototypes and `#ifndef` include guards. |
| **2** | Hardware Trip-Zone paths | **SOURCE COMPLETE / TARGET PENDING** | `protection.c` configures `TRIP_LATCH_N` on `XBAR_INPUT1` (`TZ1`) and `ESTOP_N` on `XBAR_INPUT2` (`TZ2`) with `OSHT1|OSHT2`. Target compilation and measured asynchronous shutdown remain required. |
| **3** | Remove assumed scaling | **PASS** | `docs/hardware_firmware_interface.md` was rewritten. Generic assumptions were purged and marked `BLOCKED`. |
| **4** | Derive scaling from HW | **PASS** | `TMCS1123B2AQDVGRQ1` (from `hardware/sensing_inputs.json`) correctly supplies the 50mV/A offset math for a ±31 A linear range. All unresolved analog channels remain `BLOCKED`. |
| **5** | Deterministic ADC SOC & Timing | **ANALYSIS PASS / TARGET PENDING** | `ADC_setSOCPriority()` requests high-priority execution. The calculated conversion schedule fits the 20 kHz period, but result-read latency and actual ISR timing require TI compilation and scope profiling. |
| **6** | Deterministic PWM / DB Timing | **SOURCE COMPLETE / TARGET PENDING** | The source explicitly requests a 100 MHz ePWM clock, divide-by-one TBCLK and full-cycle dead-band clock. The intended result is 20 kHz PWM and 100 ns dead time; confirm the APIs and waveform on the target. |
| **7** | CPU1 startup sequence | **PASS** | `main_cpu1.c` forces strict order: `Device_init` → `Device_initGPIO` → `Interrupt_initModule` → `Interrupt_initVectorTable` → Peripherals (ADC/PWM/TZ/SCI) → `EINT` → `ERTM`. |
| **8** | Verify CMake configuration | **PASS** | `CMakeLists.txt` configures `2837xD_FLASH_lnk_cpu1.cmd`, links `driverlib.lib`, targets `ti-cgt-c2000` via `toolchain-tic2000.cmake`, and defines `MG_C2000_TARGET`. |
| **9** | Run host tests | **PASS** | `make test` executed; API verifier, pin allocation, and peripheral timing tests pass. |
| **10** | TI CGT compile/link | **BLOCKED** | TI Code Generation Tools are unavailable in this environment. Must be run locally by user via CCS. |

### Conclusion
Gate 0 digital mapping is **FROZEN**. Gate 0 analog scaling is **PARTIALLY
BLOCKED**. Gate 1A source structure is present, while TI target compilation,
profiling and physical shutdown verification are **PENDING**.
