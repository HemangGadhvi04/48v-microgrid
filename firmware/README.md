# Embedded Firmware: TI C2000 TMS320F28379D

This directory contains embedded C/C++ firmware projects developed in Code Composer Studio (CCS) for digital control of the 48V microgrid platform.

## Architecture
- **Target MCU**: Texas Instruments TMS320F28379D Dual-Core Delfino Microcontroller (200 MHz, Floating-Point Unit, TMU, VCU)
- **Toolchain**: Code Composer Studio (CCS), C2000Ware SDK
- **Key Peripherals**:
  - `ePWM`: High-resolution PWM generation with complementary outputs and dead-band insertion
  - `ADC`: 12-bit/16-bit differential/single-ended ADCs triggered at PWM carrier peaks for noise-free current/voltage acquisition
  - `TripZone (TZ)`: Cycle-by-cycle hardware overcurrent trip
  - `SCI / UART`: Modbus RTU interface over RS-485 transceiver
  - `CLA (Control Law Accelerator)`: Offloading the inner current control loop and SOGI-PLL math to execute concurrently with Core 0

## Submodules
- `firmware/control_core/`: Portable C control and protection foundation with host tests
- `firmware/application/`: Integrated 20 kHz ADC-to-control-to-PWM and telemetry application
- `firmware/c2000_port/`: Frozen LaunchPad pin allocation and host-tested ISR
  boundary for coherent ADC sets, outputs, timing, watchdog, hardware trip, and
  complete Modbus frames
- `firmware/buck_boost_ctrl/`: Future C2000 peripheral binding for the DC-DC converter
- `firmware/inverter_ctrl/`: Future C2000 peripheral binding for SPWM, SOGI-PLL, and PR control
- `firmware/modbus_sunspec/`: Allocation-free embedded SunSpec 1/101 register image and Modbus RTU slave

## Implemented control core

The portable core currently includes bounded PI control with conditional
integration, serializable P&O MPPT state, cascaded PV-voltage and inductor-current
control for the four-switch buck-boost stage, duty-cycle limits, and a latched
supervisor for precharge, PLL authorization, PWM enable, emergency stop,
overvoltage, undervoltage, overcurrent, overtemperature, and precharge timeout.

Run its host-side checks without CCS or C2000Ware:

```sh
make -C firmware/control_core test
make -C firmware/modbus_sunspec test
make -C firmware/application test
```

The core contains no dynamic allocation or operating-system dependency. The
next firmware step is to bind these functions to ePWM, ADC SOC, Trip Zone, and
SCI drivers after the exact C2000 board and pin allocation are fixed.

The embedded Modbus module accepts complete RTU frames from an SCI receive
buffer and returns a bounded response for transmission. It contains no UART or
RS-485 direction-control assumptions, allowing the same protocol code to remain
host-testable while the C2000 port owns peripheral timing.
