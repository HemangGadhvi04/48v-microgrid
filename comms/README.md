# Communication & Monitoring: SunSpec Modbus & SCADA Dashboard

This directory implements the telecommunications and telemetry infrastructure for the 48V Microgrid Research Platform.

## Architecture
```
[ TI C2000 Inverter Controller ]
             │  (SCI / UART)
             ▼
      [ MAX485 Transceiver ]
             │  (RS-485 Differential A/B lines)
             ▼
[ USB-RS485 Dongle / Raspberry Pi 4 / 5 ]
             │  (Python pymodbus client daemon)
             ▼
      [ InfluxDB v2.x ] (Time-series database)
             │  (Flux query / REST API)
             ▼
      [ Grafana Dashboard ] (Real-time telemetry & historical metrics)
```

## SunSpec Inverter Information Model
The controller responds to standard SunSpec Modbus register blocks:
- **Common Model (Model 1)**: Manufacturer, model string, firmware version, serial number.
- **Single-Phase Inverter Model (Model 101)**:
  - `A`: AC Current [A]
  - `PhVph`: Phase Voltage [V]
  - `W`: Active Power [W]
  - `Hz`: Line Frequency [Hz]
  - `VA`: Apparent Power [VA]
  - `VAr`: Reactive Power [VAr]
  - `PF`: Power Factor
  - `WH`: Lifetime Energy Yield [Wh]
  - `DCA`: DC Current [A]
  - `DCV`: DC Bus Voltage [V]
  - `TmpCab`: Heat Sink / Ambient Temperature [°C]
  - `St`: Operating Status (Off, Sleeping, Starting, MPPT, Throttled, Fault)

## Implemented files

- `sunspec_map.json`: SunSpec Common Model 1 and single-phase inverter Model 101 image, including scale factors.
- `microgrid_modbus.py`: Dependency-free Modbus RTU CRC, framing, exception handling, server image, two-block client read, and SunSpec decoding.
- `serial_transport.py`: Optional `pyserial` RS-485 transport using even parity and the specified RTU frame gap.
- `gateway.py`: Polling, durable JSON-lines logging, error accounting, and stale-data detection.
- `modbus_poller.py`: 100 ms physical-device polling loop with optional InfluxDB batching.
- `influx_writer.py`: InfluxDB v2 line protocol and authenticated HTTP writes.
- `grafana_dashboard.json`: Importable dashboard for power, voltage, frequency, temperature, state, events, and polling health.
- `../firmware/modbus_sunspec/`: Matching allocation-free C register image and RTU slave for the inverter controller.

Run the protocol and gateway tests without serial hardware or external services:

```sh
python3 -m unittest discover -s comms/tests -v
python3 comms/simulate_gateway.py
make -C firmware/modbus_sunspec test
```

For a physical adapter, install `pyserial`, copy `config.example.json`, export
the token as `INFLUX_TOKEN`, and run `modbus_poller.py --port <serial-device>`.
The token is read from the environment and is never written into telemetry.

This is an interoperable implementation candidate derived from the official
SunSpec model definitions. SunSpec certification and tests against an
independent client remain separate release gates.
