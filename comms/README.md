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

## Files (To be developed in Phase 4)
- `comms/sunspec_map.json`: JSON specification of holding registers and scale factors.
- `comms/modbus_poller.py`: Async Python daemon using `pymodbus` to poll inverter every $100\text{ms}$.
- `comms/influx_writer.py`: Batched writes into InfluxDB bucket `microgrid_telemetry`.
- `comms/grafana_dashboard.json`: Exported Grafana panel layout for immediate import.
