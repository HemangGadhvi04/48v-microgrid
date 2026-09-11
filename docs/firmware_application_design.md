# Integrated Real-Time Firmware Application

## Data path

`ADC result set -> calibration -> plausibility/freshness -> supervisor -> dual PLLs -> relay mode supervisor -> grid-following current control or grid-forming droop -> bounded PWM -> SunSpec telemetry`

`firmware/application/` joins the portable controller and protection library,
the generated ADC scaling constants, and the embedded SunSpec/Modbus server.
The application is called once per completed 20 kHz ADC result set. It performs
no allocation, blocking I/O, file access, or peripheral register access.

## Scheduling

| Rate | Work |
|---:|---|
| 20 kHz | ADC conversion, range/freshness checks, protection, bus and utility SOGI-PLLs, relay state machine, DC-inductor PI, PR grid-current control or droop-based voltage synthesis, and PWM output |
| 1 kHz | Cascaded PV-voltage outer loop inside the DC-DC controller |
| 100 Hz | P&O MPPT and SunSpec telemetry snapshot |
| Continuous hardware | Emergency stop, sensor ALERT/comparator and ePWM Trip Zone |

The application uses the control core's rating-normalized P-frequency/Q-voltage
droop and AC relay supervisor. The relay requires independent microgrid-bus and
utility-side voltage channels, detects loss after a fixed qualification period,
holds the breaker open in islanded mode, applies bounded frequency and voltage
synchronization biases after utility return, and closes only after continuous
phase/frequency/voltage qualification.

The C2000 hardware abstraction must copy a coherent ADC set into
`mg_app_raw_input_t`, call `mg_app_step`, then transfer the returned duty values
to ePWM shadow registers. It must send complete received RTU frames to
`mg_sunspec_handle_rtu` outside the hard real-time control path.

The implemented RTU transport detects frame boundaries with the Modbus
3.5-character silent interval, bounds requests and responses to 256 bytes,
rejects overflow and bad-CRC frames, and controls half-duplex transmission in
the target SCI-B adapter. SunSpec telemetry uses an ISR generation counter and
a retrying volatile snapshot so a background response cannot mix two telemetry
updates.

## Fault behavior

Emergency stop, hardware trip, voltage/current/temperature limits, ADC values
outside plausible ranges, three repeated ADC sequence numbers, and a reported
deadline miss all enter the same latched supervisor. A fault immediately returns
zero power-stage duties and disables PWM authorization. Reset is accepted only
after the active fault clears and the start request is removed.

## Host evidence

The integrated tests drive calibrated synthetic ADC counts through precharge,
PLL lock, and RUN. They check both converter and inverter duty bounds, confirm
measured RMS telemetry, inject a 30 A grid overcurrent, and verify that the
fault is latched and all PWM commands become inactive. A separate test holds the
ADC sequence constant through a telemetry period and verifies both the sensor
fault and its published SunSpec state. A utility-loss test verifies that PWM
continues in grid-forming mode while the AC breaker opens, that voltage and
frequency references stay bounded, and that the application synchronizes and
recloses after utility return. Optimized, AddressSanitizer, and undefined-behavior
builds pass.

## Remaining target evidence

- F28379D peripheral initialization and verified physical pin mux
- Coherent ADC SOC/result timing and calibrated acquisition windows
- ePWM shadow load, dead band, global trip and safe-reset behavior
- SCI receive framing, RS-485 direction timing and watchdog integration
- Measured worst-case execution time below the 35 microsecond release gate
- Hardware-in-loop fault injection and power-disabled startup tests
