# Hardware Design: 48V Microgrid Research Platform

This directory contains hardware schematics, PCB layouts, Bill of Materials (BOM), and mechanical design files for Phase 2 and Phase 3 of the project.

## Hardware Roadmap
1. **Synchronous Buck-Boost DC-DC Converter (Phase 2)**:
   - Input: $0\text{V} - 60\text{V}$ startup envelope; $35\text{V} - 58\text{V}$ full-power design range
   - Output: Regulated $48\text{V}$ DC bus
   - Power Rating: $500\text{W}$
   - Switches: Dual N-channel MOSFETs or GaN Half-Bridge evaluation module
   - Gate Driver: Isolated half-bridge gate driver (e.g., TI UCC21520 or UCC27211)
   - Controller: TI C2000 LaunchPad (TMS320F28379D)

2. **Single-Phase Full-Bridge Inverter (Phase 2/3)**:
   - 4-switch H-bridge configuration
   - Wide-bandgap semiconductor option (GaN Systems / EPC GaN FETs or Cree/Wolfspeed SiC)
   - DC bus decoupling: low-ESR electrolytic + film capacitors
   - Filter board: LCL filter inductor modules and film capacitors

3. **Sensing & Protection**:
   - Isolated voltage sensing (AMC1301 / AMC1311 delta-sigma / analog isolation)
   - Hall-effect current transducers (LEM or Allegro ACS730/ACS724)
   - Hardware overcurrent comparator protection latching to PWM trip zones (TZ)

4. **Tools**:
   - KiCad 8.x / Altium Designer
   - Gerber generation following standard 4-layer stackup (Signal - GND - Power - Signal)

## Executable sizing package

The initial power-stage assumptions live in `design_inputs.json`. Recalculate
all voltage/current corners, first-pass losses, DC-link ripple, LCL resonance,
and precharge stress with:

```sh
python3 hardware/calculate_power_stage.py
python3 hardware/calculate_sensing.py
python3 hardware/calculate_magnetics.py
python3 -m unittest discover -s hardware/tests -v
```

Outputs are retained in `hardware/results/`. The `reference_bom.csv` file
separates selected prototype items, reference candidates, and parts that cannot
be frozen until magnetic, thermal, mechanical, or measured overshoot work is
complete. A candidate designation is not purchasing approval.

Candidate device claims and official source links are recorded in
`component_sources.md`. The logical PWM, ADC, protection, and ISR interface is
defined in `firmware/c2000_port/README.md`.

The schematic capture source is `schematic_specification.md`; it defines power
domains, named nets, gate interlocks, sensing placement, precharge, and the
controller connector before physical pin numbers are committed.
