# Analog Measurement Design

Generated from `hardware/sensing_inputs.json`.

The 12-bit, 3.3 V conversion is
0.8059 mV/count. A 1000
ohm and 4.7 nF output filter has a
33.86 kHz cutoff and
4.70 microsecond time constant.

| Channel | Required plant range | ADC range | Nominal resolution | Minimum rail headroom |
|---|---:|---:|---:|---:|
| pv_voltage | 0.0 to 65.0 V | 0.100 to 3.195 V | 0.01692 V/count | 0.100 V |
| dc_bus_voltage | 0.0 to 60.0 V | 0.100 to 2.957 V | 0.01692 V/count | 0.100 V |
| pv_current | -2.0 to 25.0 A | 1.550 to 2.900 V | 0.01612 A/count | 0.400 V |
| dc_inductor_current | -25.0 to 25.0 A | 0.400 to 2.900 V | 0.01612 A/count | 0.400 V |
| grid_voltage | -45.0 to 45.0 V | 0.300 to 3.000 V | 0.02686 V/count | 0.300 V |
| utility_voltage | -45.0 to 45.0 V | 0.300 to 3.000 V | 0.02686 V/count | 0.300 V |
| grid_current | -30.0 to 30.0 A | 0.150 to 3.150 V | 0.01612 A/count | 0.150 V |
| heatsink_temperature | -20.0 to 125.0 degC | 0.300 to 1.750 V | 0.08059 degC/count | 0.300 V |

## Current sensor implementation

U6-U8 use the TI TMCS1123B2AQDVGRQ1 3.3 V, 50 mV/A
variant. Its specified linear range is +/-31 A.
Set VOC to 0.600 V for the
30.0 A hardware threshold;
the specified maximum sensor response is
250 ns.

At the design RMS currents, estimated internal-conductor loss is
0.159 W in the PV sensor,
0.159 W in the DC-inductor sensor,
and 0.210 W in the grid sensor.

## Calibration and validation

1. Keep PWM disabled and record at least 4096 samples for every zero or known
   reference condition. Store mean offset and noise RMS.
2. Apply two traceable calibration points spanning at least 70% of each channel
   range. Store gain and offset with a version and CRC in nonvolatile memory.
3. Reject readings outside the required plant range plus 5% tolerance and fault
   any channel that remains unchanged across the stale-sample limit.
4. Compare software overcurrent thresholds against sensor ALERT and external
   comparator thresholds. The external path must trip all PWM channels without
   CPU execution.
5. Verify phase delay of grid-voltage and grid-current paths together because
   unmatched delay creates active/reactive power error.

The generated header `firmware/c2000_port/generated/adc_scaling.h` provides
nominal commissioning constants. Stored calibration values supersede these
nominal constants during operation.
