#!/usr/bin/env python3
"""Poll the physical inverter and optionally batch records to InfluxDB."""

import argparse
import os
import pathlib
import time

from gateway import TelemetryGateway
from influx_writer import writer_from_config
from serial_transport import SerialRtuTransport


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", required=True, help="RS-485 serial device")
    parser.add_argument("--baudrate", type=int, default=115200)
    parser.add_argument("--period", type=float, default=0.1)
    parser.add_argument("--log", type=pathlib.Path, default=pathlib.Path("comms/results/telemetry.jsonl"))
    parser.add_argument("--config", type=pathlib.Path)
    parser.add_argument("--batch-size", type=int, default=10)
    return parser.parse_args()


def main():
    args = parse_args()
    args.log.parent.mkdir(parents=True, exist_ok=True)
    transport = SerialRtuTransport(args.port, args.baudrate)
    gateway = TelemetryGateway(transport.exchange, args.log)
    influx = None
    if args.config:
        token = os.environ.get("INFLUX_TOKEN")
        if not token:
            raise RuntimeError("INFLUX_TOKEN is required when --config is used")
        influx = writer_from_config(args.config, token)
    batch = []
    next_poll = time.monotonic()
    try:
        while True:
            try:
                record = gateway.poll()
                batch.append(record)
                if influx and len(batch) >= args.batch_size:
                    influx.write(batch)
                    batch.clear()
            except Exception as exception:
                print(f"poll failed: {exception}", flush=True)
            next_poll += args.period
            time.sleep(max(0.0, next_poll - time.monotonic()))
    except KeyboardInterrupt:
        if influx and batch:
            influx.write(batch)
    finally:
        transport.close()


if __name__ == "__main__":
    main()
