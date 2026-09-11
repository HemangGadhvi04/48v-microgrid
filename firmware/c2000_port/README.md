# C2000 Real-Time Integration Contract

Target: TI LAUNCHXL-F28379D, one 20 kHz control interrupt, 200 MHz nominal CPU.
This file freezes logical assignments and timing. The controller-side physical
allocation is captured in `pin_allocation.csv` and checked by
`validate_pin_allocation.py`. The mating power-board connector orientation must
still be checked during schematic review.

## PWM resources

| Logical channel | Initial ePWM allocation | Outputs | Behavior |
|---|---|---|---|
| DC-DC input leg | ePWM1 | A/B complementary | Center-aligned, shadow-loaded, 100 ns initial dead time |
| DC-DC output leg | ePWM2 | A/B complementary | Center-aligned, shadow-loaded, 100 ns initial dead time |
| Inverter leg A | ePWM3 | A/B complementary | Unipolar SPWM, center-aligned, synchronized with ePWM4 |
| Inverter leg B | ePWM4 | A/B complementary | Unipolar SPWM, 180-degree command relationship |

At 200 MHz SYSCLK, the F28379D ePWM clock is divided to its 100 MHz limit.
Center-aligned 20 kHz PWM therefore uses TBPRD 2500. An initial 100 ns dead time
corresponds to 10 time-base counts. `calculate_peripheral_timing.py` derives and
checks both values from `peripheral_config.json`.

All four ePWM modules receive the same hardware Trip Zone source. A trip forces
every gate command inactive without waiting for the control ISR. Firmware may
record and latch the cause, but it may not mask the hardware path.

## Logical ADC channels

| Signal | Range at plant | ADC representation | Use |
|---|---:|---:|---|
| PV voltage | 0 to 65 V | 0.1 to 3.2 V unipolar | MPPT and PV-voltage loop |
| PV current | -2 to 25 A | centered bipolar | MPPT and protection |
| DC-link voltage | 0 to 60 V | 0.1 to 3.2 V unipolar | energy control and protection |
| DC-inductor current | -25 to 25 A | centered bipolar | inner DC-DC loop and hardware trip |
| Microgrid-bus voltage | -45 to 45 V peak nominal | centered bipolar | Bus SOGI-PLL, grid-forming control and feedforward |
| Utility-side voltage | -45 to 45 V peak nominal | centered bipolar | Utility SOGI-PLL, loss detection and open-breaker synchronization |
| Grid current | -30 to 30 A peak | centered bipolar | PR loop and hardware trip |
| Temperatures | -20 to 125 deg C | unipolar | derating and trip |

The ADC start-of-conversion event occurs at a PWM point away from switching
edges. Final placement follows measured ringing and sensor delay. Every channel
requires offset/gain calibration, plausibility bounds, and stale-sample
detection. Raw ADC counts never enter a control law directly.

The frozen first target configuration uses 12-bit single-ended conversion,
200 ns acquisition windows (`ACQPS=39`), and simultaneous ePWM1 SOCA triggers
on ADC modules A, B, and C. ADCA converts four channels while ADCB and ADCC each
convert two. The conservative calculated coherent-set completion is 1.68 us;
ADCA SOC3 raises the control interrupt after all eight results are available.

## 50 microsecond interrupt schedule

1. Confirm no hardware trip and copy the completed ADC result set.
2. Apply stored offset/gain calibration and plausibility checks.
3. Run the protection supervisor. If PWM is not authorized, write inactive
   shadow values and skip control outputs.
4. Run SOGI-PLL and grid-validity logic.
5. Every 200 interrupts (100 Hz), update P&O MPPT.
6. Every 20 interrupts (1 kHz), update the outer PV-voltage controller.
7. Run the DC-inductor controller and buck/boost modulator.
8. Run DC-link energy control, active/reactive current-reference limiting, and
   PR grid-current control.
9. Write bounded compare values to ePWM shadow registers, service diagnostics,
   clear the interrupt, and record execution time.

The release gate is a measured worst-case ISR time below 35 microseconds,
leaving 15 microseconds for interrupt latency and variation. A missed-deadline
counter becomes a latched fault after the configured consecutive limit.

## Implemented target boundary

`microgrid_c2000_port.c` owns the deterministic ISR boundary around the portable
application. It copies one coherent ADC result set, merges digital interlocks,
assigns the sample sequence, applies outputs through one callback, measures ISR
ticks, forces inactive outputs immediately above the 35 microsecond deadline,
latches the diagnostic on the next application step, services the watchdog only
outside FAULT, acknowledges the interrupt, and routes complete RTU frames to the
allocation-free SunSpec server. Host mocks verify normal RUN, hardware trip,
incomplete ADC, deadline overrun, watchdog, and interrupt acknowledgement paths.

The frozen LaunchPad allocation uses GPIO0 through GPIO7 for ePWM1 through
ePWM4, J3 pins 23 through 30 for the eight analog measurements, GPIO24 through
Input X-Bar 1 for the asynchronous trip, GPIO18/GPIO19 for SCI-B, and separate
GPIOs for relays, enable, RS-485 direction, and the ISR timing marker. It follows
the TI LAUNCHXL-F28379D header assignment; pin mux and analog channel constants
must be checked against the installed C2000Ware release during the first target
build.

`f28379d_driverlib_hal.c` is the CPU1 binding for C2000Ware. It reads the
eight frozen result registers, converts application duties into shadow compare
counts, keeps one-shot trip asserted whenever PWM is unauthorized, rechecks the
trip, emergency-stop, and bias-good inputs before clearing it, drives the three
relay/contactor outputs, measures execution with CPU Timer 0, services the
watchdog, and acknowledges ADCINT1. The project startup must call the generated
`Board_init()` first and `mg_f28379d_bind_runtime()` second. Target compilation
and flashing remain dependent on installing C2000Ware/CCS.

For a local C2000Ware checkout, verify every target API and constant against
the actual F2837xD headers:

```sh
python3 firmware/c2000_port/verify_against_c2000ware.py /path/to/c2000ware-core-sdk
```

Run the portable boundary verification with:

```sh
make -C firmware/c2000_port test
```

## Peripheral work still required

- Create and target-build the C2000Ware/SysConfig `Board_init()` definitions for
  the frozen GPIO, SOC, Input X-Bar, Trip Zone, ePWM and SCI settings.
- Confirm comparator routing and validate the selected 12-bit, 200 ns ADC
  acquisition window against measured source settling.
- Implement startup self-tests, flash calibration storage,
  dual-core ownership, and debugger-safe trip behavior.
- Measure ISR and CLA execution time using GPIO markers and device counters.

The target-independent schedule and state machine are implemented in
`firmware/application/`. The C2000 port must now supply coherent raw samples and
apply its bounded outputs according to this contract.
