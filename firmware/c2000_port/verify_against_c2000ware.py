#!/usr/bin/env python3
import argparse
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("sdk", type=Path, help="root of a c2000ware-core-sdk checkout")
args = parser.parse_args()
driverlib = args.sdk / "driverlib" / "f2837xd" / "driverlib"
assert driverlib.is_dir(), driverlib
headers = "\n".join(path.read_text(errors="ignore") for path in driverlib.rglob("*.h"))
target_dir = Path(__file__).resolve().parent / "target"
source = "\n".join(path.read_text() for path in target_dir.glob("*.[ch]"))
calls = set(re.findall(r"\b((?:ADC|EPWM|GPIO|XBAR|SCI|SysCtl|CPUTimer|Interrupt)_[A-Za-z0-9_]+)\s*\(", source))
constants = set(re.findall(r"\b(?:ADC|EPWM|GPIO|XBAR|SCI|SYSCTL|CPUTIMER|INTERRUPT)_[A-Z0-9_]+\b", source))
missing = sorted(symbol for symbol in calls | constants if symbol not in headers)
assert not missing, f"symbols missing from F2837xD Driverlib: {missing}"
revision = subprocess.check_output(["git", "-C", str(args.sdk), "rev-parse", "HEAD"], text=True).strip()
report = target_dir.parent / "driverlib_validation_report.md"
report.write_text(f"""# Driverlib API Validation

- Upstream: `TexasInstruments/c2000ware-core-sdk`
- Revision: `{revision}`
- Device headers: `driverlib/f2837xd/driverlib`
- Target calls checked: {len(calls)}
- Target constants checked: {len(constants)}
- Missing symbols: 0

This is a header-level compatibility check. A TI C28x compiler build and a
flashed LAUNCHXL-F28379D remain required because the C28x ABI and keywords are
not compatible with the host C compiler.
""")
print(f"Verified {len(calls)} calls and {len(constants)} constants against {revision[:12]}")
