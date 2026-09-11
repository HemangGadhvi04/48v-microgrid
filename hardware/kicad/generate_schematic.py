#!/usr/bin/env python3
"""Generate the reviewable KiCad schematic from the checked connectivity table.

Requires kiutils==1.4.8. All symbols are embedded project symbols with named
pins, so the artifact has no dependency on a workstation symbol library.
"""
import csv
import pathlib
import re
import uuid
from collections import defaultdict

from kiutils.schematic import Schematic
from kiutils.symbol import Symbol, SymbolPin
from kiutils.items.syitems import SyRect
from kiutils.items.schitems import (GlobalLabel, NoConnect, SchematicSymbol,
                                    SymbolProjectInstance, SymbolProjectPath)
from kiutils.items.common import (Effects, Fill, Font, PageSettings, Position,
                                  Property, Stroke, TitleBlock)

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = pathlib.Path(__file__).resolve().parent
PROJECT = "microgrid_48v"


_uid_counter = 0


def uid():
    """Return stable UUIDs so regeneration produces reviewable diffs."""
    global _uid_counter
    _uid_counter += 1
    return str(uuid.uuid5(uuid.NAMESPACE_URL,
                          f"microgrid-48v-schematic/{_uid_counter}"))


def natural(text):
    return [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", text)]


def candidate(reference, description):
    fixed = {
        "Q": "CSD19536KCS", "U1": "UCC27211A", "U2": "UCC27211A",
        "U3": "UCC27211A", "U4": "UCC27211A", "U5": "LAUNCHXL-F28379D",
        "U6": "TMCS1123B2AQDVGRQ1", "U7": "TMCS1123B2AQDVGRQ1",
        "U8": "TMCS1123B2AQDVGRQ1",
        "U9": "OPA320AQDBVRQ1G4", "U10": "OPA320AQDBVRQ1G4",
        "U11": "AMC3330QDWERQ1 + OPA320", "U12": "AMC3330QDWERQ1 + OPA320",
        "U13": "TMP235AEDBZRQ1",
        "LDC": "500uH / 3x E65 / 28T", "L1": "150uH / 2x E65 / 19T",
        "L2": "75uH / 1x E65 / 19T", "CDC": "3x ALS31A103KE100",
        "CF": "C4AQUBW5200A3MJ 20uF", "RD": "HSC100R56J 0R56",
        "RPRE": "HSC10047RJ 47R", "F1": "JLLN030.T 30A",
        "K1": "Albright SW80B", "KAC": "G9KA-1A1B-E DC12",
        "URS485": "ISO1410", "U13": "TMP235", "UTRIP": "SN74HCS02-Q1",
    }
    if reference in fixed:
        return fixed[reference]
    if re.fullmatch(r"Q[1-8]", reference):
        return fixed["Q"]
    if reference.startswith("UEN"):
        return "PWM safety AND channel"
    if reference.startswith("RG"):
        return "5R-15R tuning footprint"
    if reference.startswith("RGS"):
        return "10k"
    if reference.startswith("CB"):
        return "100nF 50V C0G"
    if reference.startswith("QK"):
        return "PMV37ENEA"
    if reference.startswith("DK"):
        return "MURS120T3G"
    return description[:48]


def pin_type(reference, pin):
    """Map functional pins to KiCad ERC electrical types."""
    if re.fullmatch(r"U[1-4]", reference):
        if pin in {"HI", "LI"}:
            return "input"
        if pin in {"HO", "LO"}:
            return "output"
        if pin in {"VDD", "VSS", "HB", "HS"}:
            return "power_in"
    if reference in {"U6", "U7", "U8"}:
        return {
            "VOUT": "output", "VREF": "output", "OC": "open_collector",
            "ALERT": "open_collector", "VOC": "input", "VS": "power_in",
            "GND": "power_in", "NC": "no_connect",
        }.get(pin, "passive")
    if reference in {"U9", "U10", "U14", "U15", "UREF", "UREF2"}:
        return {
            "IN+": "input", "IN-": "input", "OUT": "output",
            "VS": "power_in", "GND": "power_in",
        }.get(pin, "passive")
    if reference in {"U11", "U12"}:
        if pin in {"INP", "INN"}:
            return "input"
        if pin in {"OUTP", "OUTN", "DCDC_OUT", "HLDO_OUT", "LDO_OUT"}:
            return "output"
        if pin == "DIAG":
            return "open_collector"
        if pin == "NC":
            return "no_connect"
        return "power_in"
    if reference == "U13":
        return {"OUT": "output", "VS": "power_in", "GND": "power_in"}.get(pin, "passive")
    if reference.startswith("UEN"):
        return "output" if pin == "OUT" else "input"
    if reference == "UTRIP":
        return "output" if pin == "OUT_N" else "input"
    if reference == "UBIAS":
        return "open_collector" if pin in {"OUT", "OUT_N", "PGOOD"} else "input"
    if reference == "URS485":
        if pin in {"DI", "DE"}:
            return "input"
        if pin == "RO":
            return "output"
        if pin in {"VCC", "VCC_ISO", "GND", "GND_ISO"}:
            return "power_in"
        return "bidirectional"
    return "passive"


def footprint(reference):
    """Return footprints only where the orderable package is already frozen."""
    if re.fullmatch(r"Q[1-8]", reference):
        return "Package_TO_SOT_THT:TO-220-3_Vertical"
    if reference in {"U9", "U10", "U14", "U15", "UREF", "UREF2"}:
        return "Package_TO_SOT_SMD:SOT-23-5"
    if reference in {"U11", "U12"}:
        return "Package_SO:SOIC-16W_7.5x10.3mm_P1.27mm"
    if reference == "U13":
        return "Package_TO_SOT_SMD:SOT-23"
    return ""


def datasheet(reference):
    if re.fullmatch(r"Q[1-8]", reference):
        return "https://www.ti.com/lit/ds/symlink/csd19536kcs.pdf"
    if reference in {"U9", "U10", "U14", "U15", "UREF", "UREF2"}:
        return "https://www.ti.com/lit/ds/symlink/opa320-q1.pdf"
    if reference in {"U11", "U12"}:
        return "https://www.ti.com/lit/ds/symlink/amc3330-q1.pdf"
    if reference == "U13":
        return "https://www.ti.com/lit/ds/symlink/tmp235-q1.pdf"
    if reference in {"U6", "U7", "U8"}:
        return "https://www.ti.com/lit/ds/symlink/tmcs1123.pdf"
    return ""


def make_lib_symbol(reference, pins, value):
    lib = Symbol.create_new(f"MG:{reference}", reference.rstrip("0123456789") or "U", value)
    lib.pinNames = True
    lib.pinNamesOffset = 0.8
    half_height = max(5.08, (len(pins) - 1) * 1.27 + 2.54)
    unit = Symbol()
    unit.libId = f"{reference}_1_1"
    unit.graphicItems = [SyRect(start=Position(-10.16, -half_height),
                                    end=Position(10.16, half_height),
                                    stroke=Stroke(width=0.254),
                                    fill=Fill(type="background"))]
    for index, row in enumerate(pins):
        y = (index - (len(pins) - 1) / 2.0) * 2.54
        unit.pins.append(SymbolPin(
            electricalType=pin_type(reference, row["pin"]), graphicalStyle="line",
            position=Position(-12.70, y, 0), length=2.54,
            name=row["pin"], number=row["pin"],
            nameEffects=Effects(font=Font(width=1.0, height=1.0)),
            numberEffects=Effects(font=Font(width=1.0, height=1.0))))
    lib.units = [unit]
    return lib


def make_instance(schematic, reference, pins, value, x, y):
    symbol = SchematicSymbol()
    symbol.libId = f"MG:{reference}"
    symbol.position = Position(x, y, 0)
    symbol.unit = 1
    symbol.inBom = True
    symbol.onBoard = True
    symbol.uuid = uid()
    font = Effects(font=Font(width=1.27, height=1.27))
    hidden = Effects(font=Font(width=1.27, height=1.27), hide=True)
    symbol.properties = [
        Property("Reference", reference, 0, Position(x, y - 8, 0), font),
        Property("Value", value, 1, Position(x, y + 8, 0), font),
        Property("Footprint", footprint(reference), 2, Position(0, 0, 0), hidden),
        Property("Datasheet", datasheet(reference), 3, Position(0, 0, 0), hidden),
    ]
    symbol.instances = [SymbolProjectInstance(
        name=PROJECT,
        paths=[SymbolProjectPath(
            sheetInstancePath=f"/{schematic.uuid}/{symbol.uuid}",
            reference=reference, unit=1)])]
    for index, row in enumerate(pins):
        pin_uuid = uid()
        symbol.pins[row["pin"]] = pin_uuid
        py = y + (index - (len(pins) - 1) / 2.0) * 2.54
        if row["net"].startswith("NC_"):
            schematic.noConnects.append(NoConnect(
                position=Position(x - 12.70, py), uuid=uid()))
        else:
            schematic.globalLabels.append(GlobalLabel(
                text=row["net"], shape="passive", position=Position(x - 12.70, py, 180),
                effects=Effects(font=Font(width=1.0, height=1.0)), uuid=uid()))
    return symbol


def main():
    with (ROOT / "connectivity_netlist.csv").open(encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    grouped = defaultdict(list)
    for row in rows:
        grouped[row["reference"]].append(row)
    refs = sorted(grouped, key=natural)
    schematic = Schematic.create_new()
    schematic.uuid = uid()
    schematic.paper = PageSettings(paperSize="A0")
    schematic.titleBlock = TitleBlock(
        title="48 V / 500 W Microgrid Power and Control Connectivity",
        date="2026-09-11", revision="A (engineering prototype)",
        company="Research prototype",
        comments={1: "Generated from hardware/connectivity_netlist.csv",
                  2: "Low-voltage isolated laboratory bus; bench release pending"})
    for index, reference in enumerate(refs):
        pins = grouped[reference]
        value = candidate(reference, pins[0]["description"])
        schematic.libSymbols.append(make_lib_symbol(reference, pins, value))
        col, row = index % 10, index // 10
        x, y = 45 + col * 112, 55 + row * 98
        schematic.schematicSymbols.append(
            make_instance(schematic, reference, pins, value, x, y))
    schematic.to_file(OUT / f"{PROJECT}.kicad_sch", encoding="utf-8")
    (OUT / f"{PROJECT}.kicad_pro").write_text("{}\n", encoding="utf-8")
    print(f"Generated {len(refs)} symbols, {len(rows)} pins and "
          f"{len(set(r['net'] for r in rows))} named nets")


if __name__ == "__main__":
    main()
