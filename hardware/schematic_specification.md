# Phase 2 Schematic Connectivity Specification

This connectivity document is the reviewable source for schematic capture. It
defines power domains, required nets, connector interfaces, and interlocks.
Reference designators match `hardware/reference_bom.csv` where assigned.

The pin-level source is `hardware/connectivity_netlist.csv`. Running
`python3 hardware/validate_connectivity.py` checks unique pin assignment,
non-dangling nets, all eight ADC paths, independent bus/utility sensing, eight
MOSFET gate-resistor and pulldown chains, eight four-term hardware PWM
interlocks, the trip combiner, and three low-side relay drivers with flyback
diodes. This table is the import/capture checklist for the KiCad schematic.

## Power domains

| Domain | Nets | Source | Boundary |
|---|---|---|---|
| PV input | `PV+`, `PV-` | Current-limited PV emulator, 0 to 60 V | Fuse, reverse-polarity block, disconnect and input capacitor |
| DC link | `DC48+`, `PGND` | Four-switch buck-boost output | Precharge, 30 mF capacitor bank, discharge and 60 V hardware OV trip |
| AC power | `AC_INV`, `AC_PCC`, `AC_RETURN` | H-bridge through LCL filter | Contactor to isolated 28.85 V RMS emulator only |
| Gate drive | `GD12V`, `PGND` | Current-limited 12 V bias supply | Four UCC27211A driver domains, local ceramic bypass |
| Digital | `3V3`, `DGND` | LaunchPad | Connected to power ground at one controlled measurement point |
| Communications | `RS485_A`, `RS485_B`, `COM_GND_ISO` | Isolated transceiver supply | No galvanic path to power ground through cable |

## Four-switch buck-boost path

`PV+` feeds the input half-bridge Q1/Q2. Its switch node `SW_PV` connects through
LDC to `SW_DC`, the output half-bridge Q3/Q4 switch node. Q3/Q4 connect to
`DC48+` and `PGND`. Place ceramic commutation capacitors directly across each
half-bridge supply loop. Route `SW_PV` and `SW_DC` away from ADC and comparator
nodes.

LDC current sensor U7 sits in series with the inductor path and exposes both
`ADC_IL_DC` and active-low `OC_DC_N`. The sensor ALERT and an optional external
comparator feed the trip-combine logic.

## H-bridge and LCL path

Q5/Q6 and Q7/Q8 form two synchronized half bridges across `DC48+` and `PGND`.
Their switch nodes feed the differential inverter output. The 150 uH
inverter-side inductor L1 connects to `AC_INV`; the 20 uF capacitor CF and 0.56
ohm series damping resistor RD connect from `AC_INV` to `AC_RETURN`; the 75 uH
board-side grid inductor L2 connects `AC_INV` to `AC_PCC`. Grid-emulator series
inductance remains external and must be recorded for every test.

The grid-current sensor sits after L2. The bus voltage channel measures the
inverter side of the AC contactor and the utility voltage channel measures its
emulator side, both relative to `AC_RETURN`. The AC contactor remains open until
the two independent PLL measurements pass phase, frequency, and voltage checks.

## Gate-driver interlocks

- Each UCC27211A gets independent high-side and low-side PWM inputs, series gate
  resistors with diode footprints for asymmetric turn-on/off tuning, gate-source
  pulldowns, external bootstrap capacitor using the driver's internal diode, and
  Kelvin driver return.
- Driver enable is the wired result of `PWM_ARM`, `ESTOP_N`, bias-power-good,
  and `TRIP_LATCH_N`. Firmware cannot override a false hardware term.
- `SN74HCS21QPWRQ1` forms the shared four-input permission and two
  `SN74LVC08AQPWRG4Q1` devices gate the eight raw PWM signals. A TPS3700-Q1
  window detector generates bias-power-good independently of the controller.
- `SN74HCS02QPWRQ1` forms the asynchronous trip latch. Overcurrent or emergency
  stop sets it; a manual reset can clear it only while every fault input is inactive.
- All ePWM outputs default low during reset. Hardware dead-time insertion remains
  enabled even if firmware compare values are malformed.
- Test points expose every gate-source voltage and switch node for the staged
  single-leg test. Differential probes are required for high-side measurements.

## Precharge and discharge

RPRE charges the 30 mF bus through the precharge relay. When `VDC_SENSE` reaches
43 V and remains plausible, K1 closes; only then may the precharge relay open.
A normally connected discharge resistor must bring the bus below the defined
service voltage after shutdown. Its resistance and thermal rating remain open
until the required discharge time is selected.

## Controller connector signals

The power board exposes four complementary PWM pairs, eight analog outputs,
`TRIP_LATCH_N`, `ESTOP_N`, contactor and precharge commands, contactor feedback,
bias-power-good, isolated UART TX/RX, 3.3 V reference, and grounds. PWM and trip
signals get adjacent returns. Analog outputs are grouped away from switch nodes
and driver outputs.

Physical connector pin numbers are intentionally not assigned here. They must
be frozen from the LAUNCHXL-F28379D board files and checked for ePWM, ADC,
Input-XBAR, comparator, and SCI mux compatibility before schematic release.
