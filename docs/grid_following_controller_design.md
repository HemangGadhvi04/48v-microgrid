# Grid-Following Current Controller

This switching-level milestone combines the 20 kHz SOGI-PLL, a 500 W
active/reactive current reference, a stationary-frame proportional-resonant
controller, unipolar SPWM, the damped LCL filter, variable grid impedance, and
a PLL-authorized PCC breaker.

The controller includes one sample of current-measurement latency, grid-voltage
feedforward, resistance and inductance feedforward, modulation limiting, and
conditional resonant-state integration during saturation. The current-reference
angle compensates 2.5 control samples of measured ADC/control/PWM delay. The power command
ramps from zero only after the synchronization interval.

The automated runner first validates 500 W at unity power factor, then commands
150 var while holding real power. It accepts the baseline when real power is
90–105% of the 500 W command, power factor exceeds 0.99 in the unity-power-factor
window, current THD is below 5%, steady-state
modulation saturation is below 1%, and breaker-close peak current is below 5 A.

This remains a low-voltage simulated grid. It does not authorize connection to
the 230 V utility supply and does not claim regulatory compliance.
