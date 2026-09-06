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
- `firmware/buck_boost_ctrl/`: Digital PI voltage and average current mode control
- `firmware/inverter_ctrl/`: Single-phase SPWM, SOGI-PLL, and Proportional-Resonant (PR) current controller
- `firmware/modbus_sunspec/`: SunSpec standard Modbus slave map implementation
