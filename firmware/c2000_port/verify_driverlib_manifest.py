#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
manifest = json.loads((ROOT / "driverlib_api_manifest.json").read_text())
target = "".join((ROOT / f).read_text() for f in ["f28379d_driverlib_hal.c", "board.c", "adc.c", "pwm.c", "protection.c", "communications.c", "interrupts.c", "main_cpu1.c"])
contract = (ROOT / "f28379d_board_contract.h").read_text()
assert manifest["device"] == "f2837xd"
assert re.fullmatch(r"[0-9a-f]{40}", manifest["revision"])
for name, signature in manifest["apis"].items():
    assert signature and re.search(rf"\b{re.escape(name)}\s*\(", target), name
for name in manifest["constants"]:
    assert re.search(rf"\b{re.escape(name)}\b", target + contract), name
print(f"Verified {len(manifest['apis'])} core safety APIs against {manifest['revision'][:12]}")
