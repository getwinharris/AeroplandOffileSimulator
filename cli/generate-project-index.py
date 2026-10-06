#!/usr/bin/env python3
"""Scan Sources/ + Tests/ and write docs/project-index.json (the committed inventory).

If it is not in this file, it does not exist — check it before claiming a feature.
Usage: generate-project-index.py [--check]   (--check = drift check for ./aero ci)
Stdlib only.
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Sources" / "AeroplaneSimulatorOffline"
TESTS = ROOT / "Tests"
OUT = ROOT / "docs" / "project-index.json"

TYPE_RE = re.compile(r"^(?:public|private|final|open)?\s*(struct|class|enum|protocol)\s+(\w+)", re.M)
FUNC_RE = re.compile(r"^\s*(?:public|private)?\s*(?:static\s+)?func\s+(\w+)", re.M)

def scan_swift(path: Path):
    text = path.read_text()
    types = [{"kind": m.group(1), "name": m.group(2)} for m in TYPE_RE.finditer(text)]
    funcs = sorted({m.group(1) for m in FUNC_RE.finditer(text)})
    return types, funcs

def main():
    check = "--check" in sys.argv
    files = sorted(SRC.rglob("*.swift"))
    assert files, "no Swift sources found"
    units, screens = [], set()
    for f in files:
        rel = str(f.relative_to(ROOT))
        area = f.relative_to(SRC).parts[0]  # Views / Models / Game
        types, funcs = scan_swift(f)
        units.append({"file": rel, "area": area, "types": types, "functions": funcs})
        if area == "Views":
            screens.update(t["name"] for t in types if t["name"].endswith("View"))
    test_files = sorted(str(p.relative_to(ROOT)) for p in TESTS.rglob("*.swift")) if TESTS.exists() else []
    planes = ["red-jet", "blue-prop", "yellow-biplane", "green-glider", "pink-jumbo", "orange-rocket"]
    data = {
        "generated_by": "cli/generate-project-index.py",
        "note": "Authoritative inventory of what exists. If it is not here, it does not exist — do not assume, add it first.",
        "summary": {
            "swift_files": len(files),
            "types": sum(len(u["types"]) for u in units),
            "screens": sorted(screens),
            "planes": planes,
            "test_files": len(test_files),
        },
        "units": units,
        "tests": test_files,
        "entry": "Sources/AeroplaneSimulatorOffline/Views/App.swift",
        "bundle_id": "com.getwinharris.aeroplane-simulator-offline",
    }
    rendered = json.dumps(data, indent=2) + "\n"
    if check:
        current = OUT.read_text() if OUT.exists() else ""
        if current != rendered:
            print("DRIFT: docs/project-index.json is stale — run ./aero index", file=sys.stderr)
            return 1
        print("project-index.json: in sync")
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(rendered)
    print(f"wrote {OUT} ({len(files)} files, {data['summary']['types']} types)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
