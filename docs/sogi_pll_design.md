# Single-Phase SOGI-PLL

The grid-synchronization model runs at the intended 20 kHz control rate. A
second-order generalized integrator creates orthogonal voltage components, and
a normalized synchronous-reference-frame PI loop estimates phase and frequency.
The frequency estimate is limited to 45–55 Hz with conditional integration.

The repeatable validation source applies a 50–52 Hz step, a 20-degree phase
jump, a 30% voltage sag, 3% fifth harmonic, 2% seventh harmonic, and a small
deterministic high-frequency disturbance. Automated acceptance checks require
startup and frequency-step settling within 60 ms, phase-jump settling within
40 ms, less than four degrees of settled sag phase error, and less than 0.05 Hz
final mean frequency error. These limits apply to the combined harmonic and
disturbance test; they are project validation limits, not grid-code settings.

This PLL is a synchronization subsystem. Breaker permission still requires a
separate supervisor that checks voltage magnitude, frequency, phase difference,
hold time, and faults. The next integration milestone uses its angle to create
the grid-current reference and replaces the LCL testbench's open-loop voltage
step with a bounded current controller.
