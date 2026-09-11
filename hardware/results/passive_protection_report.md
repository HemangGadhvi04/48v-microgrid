# Passive and Protection Candidate Check

Generated from `hardware/passive_protection_inputs.json`.

| Function | Candidate | Calculated result | Status |
|---|---|---:|---|
| DC-link bank | 3 x ALS31A103KE100 | 24.0 mF minimum; 1.23 V p-p; 4.6x ripple margin | Electrical check passed |
| Precharge | HSC10047RJ | 62.0 W initial; 3.25 s to 90%; 43.7 J | Pass with specified heatsink |
| LCL capacitor | C4AQUBW5200A3MJ | 0.181 Arms; 5.23 var | Electrical check passed |
| Damping resistor | HSC100R56J | 100x allocated-loss margin | Pass with specified heatsink |
| DC fuse | JLLN030.T | 2.96x voltage margin | Coordination test pending |
| Power connector | Anderson SB50 | 2.0x current margin | Crimp and temperature-rise test pending |
| Main DC contactor | Albright SW80B | 1.78x voltage; 4.0x thermal current | Ordering code and break test pending |
| AC contactor | G9KA-1A1B-E DC12 | Auxiliary mirror contact included | PCB/coil hold-drive design pending |

The capacitor bank is deliberately 30 mF nominal: its -20% tolerance value is
24 mF, above the analytical requirement of 14.7 mF.
The 43.7 J maximum bus energy sets discharge,
precharge, enclosure, and servicing requirements. Fuse selection remains provisional
until cable ampacity and measured semiconductor let-through coordination are known.
