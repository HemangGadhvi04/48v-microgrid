#!/usr/bin/env python3
import json
import pathlib
import tempfile

from gateway import TelemetryGateway
from microgrid_modbus import SunSpecImage


def main():
    device = SunSpecImage()
    device.update({
        "ac_current_a": 17.32, "ac_voltage_v": 28.85,
        "active_power_w": 499, "frequency_hz": 50.01,
        "apparent_power_va": 500, "reactive_power_var": 15,
        "power_factor_percent": 99.8, "lifetime_energy_wh": 12345,
        "dc_current_a": 10.8, "dc_voltage_v": 48.02,
        "dc_power_w": 519, "cabinet_temperature_c": 31.2,
        "heatsink_temperature_c": 42.6, "operating_state": 4,
        "event_bits": 0,
    })
    destination = pathlib.Path(__file__).resolve().parent / "results" / "telemetry.jsonl"
    destination.parent.mkdir(exist_ok=True)
    destination.unlink(missing_ok=True)
    gateway = TelemetryGateway(device.handle_rtu, destination)
    record = gateway.poll()
    print(json.dumps(record, indent=2))
    print(f"Record written to {destination}")


if __name__ == "__main__":
    main()
