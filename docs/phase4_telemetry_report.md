# Phase 4 Communications and SCADA Report

## Implemented data path

`SunSpec register image -> Modbus RTU -> RS-485 transport -> gateway -> JSONL / InfluxDB v2 -> Grafana`

The register image begins at holding-register address 40000 with the `SunS`
identifier. It implements Common Model 1 with its official 66-register length,
single-phase inverter Model 101 with its official 50-register length, and the
SunSpec end marker. Model 101 exports AC current and voltage, real/reactive and
apparent power, frequency, power factor, accumulated energy, DC measurements,
temperatures, operating state, and event bits with explicit scale factors.

The schema derives from the [official SunSpec Model 1](https://github.com/sunspec/models/blob/master/json/model_1.json)
and [Model 101](https://github.com/sunspec/models/blob/master/json/model_101.json)
definitions. The RTU implementation follows the Modbus Organization's Serial
Line Protocol and Implementation Guide V1.02 framing and CRC conventions.

## Validated behavior

- Known Modbus CRC vector and low-byte-first CRC transmission
- Silent discard of corrupted RTU frames
- Function 03 holding-register reads split at the 125-register protocol limit
- Illegal-address and illegal-function exception responses
- SunSpec signature, model headers, strings, signed values, scale factors,
  accumulated energy, states, and 32-bit events
- Durable JSON-lines logging and 500 ms stale-data detection
- InfluxDB v2 line-protocol field units and nanosecond timestamps
- Authenticated HTTP request construction without storing the token in payloads
- Importable Grafana JSON with five initial operational panels

All tests use an in-memory simulated inverter. No network service or serial
device is contacted by the test suite.

The target-independent embedded implementation is in
`firmware/modbus_sunspec/`. It uses a fixed 124-register image, no heap
allocation, bounded request and response buffers, SunSpec sentinel-aware
scaling, CRC validation, and Function 03 exception responses. Its host test
covers the official model headers, negative reactive power, accumulated energy,
event bits, illegal addresses, unsupported functions, corrupted requests, and
undersized response buffers.

## Remaining Phase 4 evidence

- SCI/UART, driver-enable, and RS-485 direction control on the selected C2000 pins
- Fault injection with dropped, delayed, truncated, duplicated, and noisy frames
- Long-duration Raspberry Pi logging and restart/data-loss tests
- Live InfluxDB and Grafana commissioning with clock synchronization
- Independent SunSpec client discovery and formal conformance testing

The present result establishes protocol behavior in software. It does not claim
SunSpec certification, cybersecurity hardening, or reliable field operation.
