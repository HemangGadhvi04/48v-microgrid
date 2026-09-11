#!/usr/bin/env python3
"""Verify that the generated KiCad artifact covers the authoritative CSV."""

import csv
import re
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
HARDWARE = HERE.parent
schematic = (HERE / "microgrid_48v.kicad_sch").read_text(encoding="utf-8")
with (HARDWARE / "connectivity_netlist.csv").open(encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))

depth = 0
quoted = False
escaped = False
for character in schematic:
    if quoted:
        if escaped:
            escaped = False
        elif character == "\\":
            escaped = True
        elif character == '"':
            quoted = False
    elif character == '"':
        quoted = True
    elif character == "(":
        depth += 1
    elif character == ")":
        depth -= 1
        assert depth >= 0, "unexpected closing parenthesis"
assert not quoted and depth == 0, "unbalanced KiCad S-expression"

references = {row["reference"] for row in rows}
for reference in references:
    marker = f'(reference "{reference}")'
    assert schematic.count(marker) == 1, f"missing or duplicate instance {reference}"

expected_nets = Counter(row["net"] for row in rows if not row["net"].startswith("NC_"))
actual_nets = Counter(re.findall(r'\(global_label "([^"]+)"', schematic))
assert actual_nets == expected_nets, "schematic labels do not match connectivity table"
assert schematic.count("(no_connect ") == sum(
    row["net"].startswith("NC_") for row in rows)
assert len(re.findall(r'^\s+\(pin "[^"]+" \(uuid ', schematic, re.MULTILINE)) == len(rows)
assert "DB1" not in schematic and "DB2" not in schematic
assert schematic.count('(lib_id "MG:') == len(references)

print(f"Verified KiCad schematic: {len(references)} symbols, {len(rows)} pins, "
      f"{len(expected_nets)} nets")
