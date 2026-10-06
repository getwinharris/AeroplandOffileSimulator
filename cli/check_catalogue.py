#!/usr/bin/env python3
"""Stdlib-only catalogue + game-rule checks (runs on CLT where XCTest is absent).

Parses Sources/ and asserts the contracts the XCTest suite also enforces.
Usage: check_catalogue.py   (exit 0 = pass)
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLANE = ROOT / "Sources/AeroplaneSimulatorOffline/Models/Plane.swift"
STATE = ROOT / "Sources/AeroplaneSimulatorOffline/Models/GameState.swift"

fails = []

def check(cond, msg):
    print(("PASS " if cond else "FAIL ") + msg)
    if not cond:
        fails.append(msg)

plane_src = PLANE.read_text()
ids = re.findall(r'id:\s*"([^"]+)"', plane_src)
speeds = [float(x) for x in re.findall(r"topSpeed:\s*([\d.]+)", plane_src)]
turns = [float(x) for x in re.findall(r"turnSpeed:\s*([\d.]+)", plane_src)]

check(len(ids) == 6, f"exactly 6 planes (found {len(ids)})")
check(len(set(ids)) == len(ids), "plane ids unique")
check(all(20 <= s <= 46 for s in speeds), f"topSpeeds in 20…46 {speeds}")
check(all(1.0 <= t <= 1.6 for t in turns), f"turnSpeeds in 1.0…1.6 {turns}")

state_src = STATE.read_text()
check("stars % 10 == 0" in state_src, "celebration threshold present (every 10 stars)")
check("screen" in state_src and ".menu" in state_src and ".fly" in state_src,
      "screen router covers menu + fly")

sys.exit(1 if fails else 0)
