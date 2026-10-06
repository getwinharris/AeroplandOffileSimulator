# ✈️ Aeroplane Simulator Offline
**A super-simple, kid-safe (3–5 yrs) aeroplane game for Mac — 100% offline, no ads.**

Move the **mouse to steer**, hold **SHIFT to BOOST**. Pick from 6 cute planes,
collect ⭐ stars, fly through 🟠 rings. You can't crash — the plane just bounces and giggles!

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![SwiftUI](https://img.shields.io/badge/SwiftUI-SceneKit-orange) ![Offline](https://img.shields.io/badge/offline-yes-green)

## 💾 Install (no Xcode needed)

1. Download **`Aeroplane-Simulator-Offline-1.0.0.dmg`** from
   [Releases](https://github.com/getwinharris/AeroplandOffileSimulator/releases).
2. Open it → drag **Aeroplane Simulator Offline** to **Applications**.
3. Double-click to play! (First launch: right-click → Open, since the free
   version is ad-hoc signed — silent install needs a paid Developer cert.)

Or build the installer yourself:

```bash
gh repo clone getwinharris/AeroplandOffileSimulator
cd AeroplandOffileSimulator
./aero build-app 1.0.0   # → dist/*.app + dist/*.dmg
open "dist/Aeroplane Simulator Offline.app"
```

## 🛩️ The 6 planes — real 3D model files, MSFS-style (menu → tap to pick)
| Plane | Real model | Speed |
|---|---|---|
| Skyhawk Trainer 🛩️ | Cessna-style high-wing (CC-BY wobba89) | ●● |
| Sky Jumbo ✈️ | passenger airliner | ●● |
| Twin Otter 🛫 | twin-turboprop | ●●● |
| Retro Biplane 🎪 | red WWI Fokker-style biplane | ●● |
| Bushmaster 🌲 | Antonov An-2, Aeroflot livery | ● |
| Rescue Heli 🚁 | cartoon rescue helicopter | ●● |

All models are real `.obj` files in `Sources/.../Resources/Planes/` (CC0 except
the Cessna, credited in-game) rendered natively with SceneKit — no three.js,
no web tech, fully offline. Cockpit instruments included: airspeed tape,
altitude tape, compass strip + artificial horizon. See `docs/FreeAssets.md`.

## 🖱️ Controls (Mac)
- **Mouse move** — steer (no clicking needed!)
- **SHIFT hold / mouse hold** — BOOST ⚡ with rainbow trail
- **ESC** — back to menu
- Sensitivity slider at the bottom for tiny hands

## 🛠️ For developers / agents

`CLAUDE.md` is the binding contract (`AGENTS.md` points to it). The workflow
mirrors our web repos: **map → change → gate → release**.

```bash
./aero map     # prints wiring (map.mmd + docs/systematic-map.mmd)
./aero index   # regenerate docs/project-index.json + index.yaml
./aero ci      # Verification Gate: build → tests → drift checks → bundle smoke
./aero logs    # unified-log tail for the bundle id + crash reports
```

Queryable knowledge: `index.yaml` (read `discovery` first, 3-hop budget:
entry → index match → source). Inventory: `docs/project-index.json`.
Skills: `.claude/skills/<name>/SKILL.md`. Observability: `docs/observability.md`.

```bash
git checkout -b feat/my-tweak
git add -A && git commit -m "feat: my tweak" && git push -u origin feat/my-tweak
gh pr create --fill   # CI runs ./aero ci on macos-14
```

## 📦 Repo layout
```
aero / cli/                        # project CLI + generators (like bapXphp)
index.yaml                         # queryable knowledge index (generated)
map.mmd / docs/systematic-map.mmd  # wiring diagrams (generated)
docs/project-index.json            # inventory of what exists (generated)
docs/observability.md              # logs, crash reports, launch-smoke steps
.claude/skills/                    # macos-swiftui, scenekit-world, planes-content, release
Package.swift                      # swift-tools 5.9, macOS 13+
Sources/AeroplaneSimulatorOffline/
  Views/  (App, MainMenu, PlaneSelection, Fly + mouse/SHIFT input)
  Models/ (Plane catalogue, GameState)
  Game/   (PlaneFactory, FlightScene, SoundManager)
Tests/                             # XCTest (full Xcode/CI) + cli/check_catalogue.py (everywhere)
aero                           # the ONLY entry point: map/index/ci/build-app/verify/logs
AppStore/Listing.md                # store text, keywords, privacy, review notes
docs/FreeAssets.md                 # which free 3D packs are resale-safe
```

## 🏪 Sell on the Mac App Store
- **Name:** `Aeroplane Simulator Offline` · **Bundle ID:**
  `com.getwinharris.aeroplane-simulator-offline` · **Category:** Games → Family
- Open `Package.swift` in full Xcode → Signing → Archive → App Store Connect.
  Listing + privacy answers in `AppStore/Listing.md` (no data collected,
  fully offline → trivial review).

## 📄 Licence
© 2026 GetWinHarris. All code in this repo is yours to sell. 3D models:
CC0 except Cessna-style (CC-BY 3.0 wobba89, credited in-game) — see `docs/FreeAssets.md`.
CC0 packs stay CC0 — see `docs/FreeAssets.md`.
