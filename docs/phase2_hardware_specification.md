# Phase 2 Hardware Kickoff Specification

## Testbench boundary

The first prototype remains an isolated, extra-low-voltage laboratory system:
42 V to 54 V DC and a 28.85 V RMS, 50 Hz AC research bus. It must use an
isolated programmable AC source or an isolated four-quadrant emulator. Direct
connection to a public utility is outside this build stage.

## Electrical requirements

| Item | Initial requirement |
|---|---|
| Continuous power | 500 W |
| PV input | 0 V to 60 V startup envelope; 35 V to 58 V at full power |
| DC bus | 42 V to 54 V; 48 V nominal |
| DC input current | Design for at least 15 A continuous and 25 A protected peak |
| AC research bus | 28.85 V RMS, 50 Hz |
| AC output current | 17.33 A RMS at 500 W unity power factor |
| Control carrier | 20 kHz first prototype; raise only after loss and thermal tests |
| Controller | TI C2000 TMS320F28379D LaunchPad or controlCARD |
| PWM protection | Hardware cycle-by-cycle overcurrent independent of firmware |
| Measurements | PV voltage/current, DC-link voltage, inductor current, grid voltage/current, temperatures |
| Communications | Isolated RS-485 reserved for SunSpec Modbus RTU |

## Staged prototypes

1. Build and characterize one low-side switching leg with a current-limited DC
   supply, isolated gate power, differential voltage probes, and a current
   probe. Establish switching-node overshoot, dead time, and gate resistance.
2. Assemble the four-switch buck-boost stage. Validate open-loop conversion at
   low power, then inner current control, then outer PV-voltage control using a
   programmable DC source or PV emulator.
3. Assemble the H-bridge and LCL filter. First drive a resistor load in islanded
   mode, then connect through a contactor and precharge path to an isolated grid
   emulator.
4. Integrate both converters through the 48 V bus. Repeat the simulation
   irradiance profile at reduced power before increasing to 500 W.

Each stage gets its own emergency stop, DC fuse, precharge or inrush control,
discharge path, overvoltage trip, hardware overcurrent trip, temperature trip,
and fault-latched PWM shutdown.

## Design work required before schematic capture

- Select MOSFETs from measured switching and conduction loss estimates at the
  chosen carrier frequency; include voltage-overshoot margin from the leg test.
- Select isolated or bootstrap gate drivers after confirming duty-cycle and
  startup constraints in both buck and boost modes.
- Size inductors from saturation current, copper loss, core loss, and measured
  temperature rise. Simulation inductance alone is insufficient for selection.
- Size DC-link and filter capacitors from RMS ripple current, voltage derating,
  lifetime, and fault energy.
- Define isolated sensing gains and anti-alias filters so ADC range, offset, and
  latency match the controller calculations.
- Complete creepage, clearance, grounding, connector, enclosure, and thermal
  reviews for the actual construction method.

## Phase 2 exit evidence

Phase 2 is complete only when the converter runs at 500 W continuously without
thermal or protection faults, measured efficiencies and temperatures are
reported, oscilloscope captures show acceptable switching stress and dead time,
the DC link remains within limits during reference steps, hardware trips are
demonstrated, and the measurement chain is calibrated against bench instruments.

## Firmware baseline available now

`firmware/control_core/` contains the target-independent algorithms needed for
early hardware commissioning. Its host tests cover bounded PI control, P&O
tracking, buck/boost modulation, precharge and fault latching, a 20 kHz
SOGI-PLL, and PR control of an RL current plant. C2000Ware peripheral bindings
remain dependent on the selected board revision and pin allocation.

## Calculated hardware baseline

The executable hardware package now covers all buck/boost voltage corners,
first-pass hot losses, DC-link energy ripple, precharge stress, seven analog
measurement channels, and magnetic energy, copper, manufacturer DC-bias, and
switching-ripple core-loss estimates. Generated
reports and machine-readable metrics are stored in `hardware/results/`. These
calculations define requirements; component release still needs window/termination
fit and measured thermal and switching evidence.
