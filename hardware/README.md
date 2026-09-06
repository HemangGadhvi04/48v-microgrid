# Hardware Design: 48V Microgrid Research Platform

This directory contains hardware schematics, PCB layouts, Bill of Materials (BOM), and mechanical design files for Phase 2 and Phase 3 of the project.

## Hardware Roadmap
1. **Synchronous Buck-Boost DC-DC Converter (Phase 2)**:
   - Input: $20\text{V} - 60\text{V}$ (Solar PV emulator / array)
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
