"""Transport-neutral telemetry poller and durable JSON-lines logger."""

import json
import time

from microgrid_modbus import read_complete_image


class TelemetryGateway:
    def __init__(self, exchange, log_path, stale_after_s=0.5, clock=None):
        self.exchange = exchange
        self.log_path = log_path
        self.stale_after_s = stale_after_s
        self.clock = clock or time.time
        self.last_success_s = None
        self.poll_errors = 0

    def poll(self):
        timestamp = self.clock()
        try:
            decoded = read_complete_image(self.exchange)
        except Exception:
            self.poll_errors += 1
            raise
        self.last_success_s = timestamp
        record = {
            "timestamp_unix_s": timestamp,
            "poll_errors": self.poll_errors,
            **decoded["inverter_single_phase"],
        }
        with open(self.log_path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, separators=(",", ":")) + "\n")
            handle.flush()
        return record

    def is_stale(self):
        return self.last_success_s is None or self.clock() - self.last_success_s > self.stale_after_s
