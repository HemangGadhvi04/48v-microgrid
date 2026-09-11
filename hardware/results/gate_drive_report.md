# Gate Drive and Hardware Interlock Check

Generated from `hardware/gate_drive_inputs.json`.

Four UCC27211A half-bridge drivers use their internal 120 V bootstrap diodes.
Each external HB-to-HS capacitor is 100 nF, 5%, and each VDD-to-VSS local
decoupler is 4.7 uF. At 98% maximum high-side duty, the conservative charge
budget predicts 1.30 V droop and
9.65 V minimum bootstrap voltage,
1.75 V above the maximum rising UVLO threshold.

| Check | Result |
|---|---:|
| Gate-charge power per half bridge | 0.057 W |
| Maximum hardware-disable latency | 85 ns |
| Minimum dead time after worst delay mismatch | 83 ns |

`SN74HCS21QPWRQ1` combines `PWM_ARM`, `ESTOP_N`, `TRIP_LATCH_N`, and
`BIAS_POWER_GOOD` into the shared safety enable. Two `SN74LVC08AQPWRG4Q1`
devices gate the eight raw PWM channels with that enable. A
`SN74HCS02QPWRQ1` implements the asynchronous set/reset trip latch; reset is
permitted only from the manual reset input while all fault inputs are inactive.
The logic is powered from the supervised 3.3 V safety rail and its outputs have
10 kohm pulldowns at every driver input, so unpowered or false enable states
command both UCC27211A outputs low.

The calculation establishes component and static timing feasibility. Double-pulse
testing must still tune gate resistance and confirm switch-node overshoot,
false-turn-on immunity, and actual dead time at temperature.
