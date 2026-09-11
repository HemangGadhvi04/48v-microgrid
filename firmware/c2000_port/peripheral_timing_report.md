# F28379D Peripheral Timing

| Item | Frozen value |
|---|---:|
| CPU clock | 200 MHz |
| ePWM clock | 100 MHz |
| Center-aligned switching | 20 kHz |
| TBPRD | 2500 counts |
| Dead time | 100 ns / 10 counts |
| ADC acquisition | 200 ns / ACQPS 39 |
| Estimated coherent set completion | 1.68 us |
| Control deadline | 35 us |
| Period reserve after acquisition and deadline | 13.32 us |

All eight SOCs use ePWM1 SOCA at counter zero. ADCA has the longest sequence
with four conversions; ADCA SOC3 raises ADCINT1 after the other modules have
completed their two-conversion sequences. The estimate uses the configured
acquisition and conservative conversion-cycle budget. Target oscilloscope and
timer measurements remain the release evidence.
