"""InfluxDB v2 line-protocol encoder and HTTP batch writer."""

import json
import urllib.parse
import urllib.request


def _escape_measurement(value):
    return str(value).replace("\\", "\\\\").replace(" ", "\\ ").replace(",", "\\,")


def _escape_tag(value):
    return _escape_measurement(value).replace("=", "\\=")


def telemetry_line(record, device="microgrid-01"):
    numeric_fields = {
        "ac_current_a": record["A"],
        "ac_voltage_v": record["PhVphA"],
        "active_power_w": record["W"],
        "frequency_hz": record["Hz"],
        "apparent_power_va": record["VA"],
        "reactive_power_var": record["VAr"],
        "power_factor_percent": record["PF"],
        "energy_wh": record["WH"],
        "dc_current_a": record["DCA"],
        "dc_voltage_v": record["DCV"],
        "dc_power_w": record["DCW"],
        "cabinet_temperature_c": record["TmpCab"],
        "heatsink_temperature_c": record["TmpSnk"],
        "operating_state": int(record["St"]),
        "event_bits": int(record["Evt1"]),
        "poll_errors": int(record.get("poll_errors", 0)),
    }
    fields = []
    for name, value in numeric_fields.items():
        suffix = "i" if isinstance(value, int) else ""
        fields.append(f"{name}={value}{suffix}")
    timestamp_ns = int(float(record["timestamp_unix_s"]) * 1_000_000_000)
    return f"microgrid,device={_escape_tag(device)} {','.join(fields)} {timestamp_ns}"


class InfluxWriter:
    def __init__(self, url, org, bucket, token, opener=None, timeout_s=5.0):
        self.url = url.rstrip("/")
        self.org = org
        self.bucket = bucket
        self.token = token
        self.opener = opener or urllib.request.urlopen
        self.timeout_s = timeout_s

    def write(self, records, device="microgrid-01"):
        body = "\n".join(telemetry_line(record, device) for record in records).encode("utf-8")
        query = urllib.parse.urlencode({"org": self.org, "bucket": self.bucket, "precision": "ns"})
        request = urllib.request.Request(
            f"{self.url}/api/v2/write?{query}", data=body, method="POST",
            headers={"Authorization": f"Token {self.token}", "Content-Type": "text/plain; charset=utf-8"},
        )
        with self.opener(request, timeout=self.timeout_s) as response:
            status = getattr(response, "status", 204)
            if status not in (200, 204):
                raise RuntimeError(f"InfluxDB returned HTTP {status}")
        return len(records)


def writer_from_config(path, token):
    with open(path, encoding="utf-8") as handle:
        config = json.load(handle)["influxdb"]
    return InfluxWriter(config["url"], config["org"], config["bucket"], token)
