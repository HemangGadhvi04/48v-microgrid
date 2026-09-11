# KiCad engineering schematic

`microgrid_48v.kicad_sch` is the first capture of the complete validated
connectivity table. It embeds project-specific rectangular symbols so every
named functional pin remains visible without relying on a workstation library.
The current capture contains 156 symbols and 502 pins across 132 logical nets:
127 connected global-label nets and five intentional no-connect pins. It
includes the complete TMCS1123 and AMC3330 support networks, ADC filters,
analog reference buffers, and isolated RS-485 supply connection.

Regenerate it in an isolated Python environment:

```sh
python3 -m venv /tmp/microgrid-kicad
/tmp/microgrid-kicad/bin/pip install -r hardware/kicad/requirements.txt
/tmp/microgrid-kicad/bin/python hardware/kicad/generate_schematic.py
python3 hardware/kicad/verify_schematic.py
```

The capture is suitable for connectivity and design review. Production symbols
and footprints are left
blank deliberately because PCB placement, thermal copper, current-loop geometry,
and mechanical interfaces have not passed their release gates. Assigning generic
footprints before those choices would create false manufacturing readiness.
