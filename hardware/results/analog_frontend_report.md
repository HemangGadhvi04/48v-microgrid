# Analog Front-End Design

The PV and DC-bus dividers use OPA320AQDBVRQ1G4
buffers. A 200 kohm / 10 kohm divider referenced to 105 mV produces a nominal
100 mV live-zero offset and 0.047619048 V/V gain.

| Channel | Plant range | ADC range | Divider loss at maximum |
|---|---:|---:|---:|
| PV voltage | 0 to 65 V | 0.100 to 3.195 V | 20.12 mW |
| DC bus voltage | 0 to 60 V | 0.100 to 2.957 V | 17.14 mW |

The PCC and utility channels use AMC3330QDWERQ1
reinforced isolated amplifiers followed by
OPA320AQDBVRQ1G4 differential-to-single-ended
drivers. The 498 kohm / 10 kohm divider limits the isolator input to
0.886 V at +/-45 V. Overall gain is
0.029527559 V/V and the ADC range is
0.321 to 2.979 V.

The heatsink channel uses TMP235AEDBZRQ1;
-20 to 125 C maps to 0.300 to 1.750 V.
All ADC paths retain the 1 kohm / 4.7 nF output filter
(33.86 kHz).
