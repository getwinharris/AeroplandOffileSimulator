#!/usr/bin/env python3
"""Emit map.mmd (code graph) + docs/systematic-map.mmd (screen→view→model→game wiring).
Usage: generate-maps.py [--check]
Stdlib only. Deterministic output.
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Sources" / "AeroplaneSimulatorOffline"
MAP = ROOT / "map.mmd"
SMAP = ROOT / "docs" / "systematic-map.mmd"

# Fixed wiring — the game's architecture contract. Update when files move.
EDGES = [
    ("App/ContentView", "MainMenuView"),
    ("App/ContentView", "PlaneSelectionView"),
    ("App/ContentView", "FlyView"),
    ("App/ContentView", "HelpView"),
    ("MainMenuView", "GameState"),
    ("PlaneSelectionView", "GameState"),
    ("PlaneSelectionView", "KidPlane"),
    ("FlyView", "GameState"),
    ("FlyView", "FlightScene"),
    ("FlightScene", "PlaneFactory"),
    ("FlightScene", "KidPlane"),
    ("FlightScene", "SoundManager"),
    ("GameState", "SoundManager"),
    ("GameState", "KidPlane"),
    ("package_app.sh", "AppBundle"),
    ("AppBundle", "DMG"),
]

def node_id(f: Path) -> str:
    return f.relative_to(SRC).with_suffix("").as_posix().replace("/", "_")

def main():
    check = "--check" in sys.argv
    files = sorted(SRC.rglob("*.swift"))
    lines = ["graph TD"]
    for f in files:
        nid = node_id(f)
        area = f.relative_to(SRC).parts[0]
        lines.append(f'  {nid}["{f.name}<br/>{area}"]')
    type_names = set()
    for f in files:
        for m in re.finditer(r"(?:struct|class|enum)\s+(\w+)", f.read_text()):
            type_names.add(m.group(1))
    lines.append("  %% wiring (contracted — see docs/systematic-map.mmd)")
    sm = ["graph LR", "  %% Screens → Views → Models → Game systems"]
    screens = ["menu", "planes", "fly", "help"]
    for s in screens:
        sm.append(f"  screen_{s}({s})")
    for a, b in EDGES:
        aid, bid = a.replace("/", "_"), b.replace("/", "_")
        sm.append(f"  {aid} --> {bid}")
    sm += [
        "  GameState -.->|stars/rings/speed| FlyView_HUD",
        "  FlyView -.->|mouse+SHIFT| FlightScene",
        "  FlightScene -.->|collect| GameState",
    ]
    map_text = "\n".join(lines) + "\n"
    sm_text = "\n".join(sm) + "\n"
    if check:
        ok = True
        for path, text in ((MAP, map_text), (SMAP, sm_text)):
            cur = path.read_text() if path.exists() else ""
            if cur != text:
                print(f"DRIFT: {path.relative_to(ROOT)} stale — run ./aero map", file=sys.stderr)
                ok = False
        if ok:
            print("maps: in sync")
        return 0 if ok else 1
    MAP.write_text(map_text)
    SMAP.parent.mkdir(parents=True, exist_ok=True)
    SMAP.write_text(sm_text)
    print(f"wrote {MAP} + {SMAP}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
