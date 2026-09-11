# PV Model and Perturb-and-Observe MPPT

The project PV source is a five-parameter single-diode array solved by
Newton-Raphson iteration. The default effective array is scaled to approximately
500 W at standard test conditions and has a nominal open-circuit voltage of
58 V. Validation sweeps irradiance from 200–1000 W/m2 and temperature from
10–60 degrees C, checks finite physical curves, and verifies the expected
irradiance-current and temperature-voltage trends.

The P&O implementation exposes its state rather than relying on hidden globals.
Its dynamic test applies irradiance steps from 1000 to 600 to 900 W/m2 and a
temperature step from 25 to 45 degrees C. Extracted power is compared with a
dense voltage-sweep MPP reference for each condition. Settled windows must
exceed 98% mean tracking efficiency and remain within 1 V mean MPP-voltage
error.

This MPPT validation assumes that the DC/DC converter can impose the requested
PV operating voltage. Converter dynamics, current limiting, the 48 V DC-link
controller, and power balance are the next integration milestone.

