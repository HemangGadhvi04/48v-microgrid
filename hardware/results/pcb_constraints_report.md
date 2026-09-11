# PCB Constraint Baseline

The first prototype uses four layers with 70 um outer copper and 35 um inner
copper. High-current switching loops stay on the outer layers as copper pours or
bus structures. They are not permitted to depend on plated vias as their primary
current path.

| Class | Design current | IPC-2221 external width at 20 C rise | Selected minimum | Margin |
|---|---:|---:|---:|---:|
| DC_POWER_30A | 30.00 A | 10.75 mm | 12.00 mm | 1.12x |
| AC_POWER_18A | 18.00 A | 5.31 mm | 6.00 mm | 1.13x |
| GATE_DRIVE | 0.20 A (4.5 A pulse) | 0.01 mm | 0.50 mm | 46.68x |
| ANALOG_SENSE | 0.05 A | 0.00 mm | 0.25 mm | 157.95x |
| DIGITAL_CONTROL | 0.05 A | 0.00 mm | 0.25 mm | 157.95x |

The legacy IPC-2221 equation is used only as a conservative pre-layout screen.
Final temperature rise requires the fabricator's stackup, actual polygon geometry,
connector transitions, and thermal test data.

## Mandatory placement and separation

- Keep switch-node copper at least 5.0 mm from analog sensing.
- Keep power copper at least 2.0 mm from controller routing.
- Preserve 4.0 mm across the isolated RS-485 barrier.
- Keep power copper 2.0 mm from the board edge.
- Place each driver within 15 mm of its MOSFET gates and each bootstrap/commutation loop within 10 mm.
- If a power-layer transition cannot be avoided, use at least 12 vias with 0.4 mm finished drill and validate the transition thermally.
