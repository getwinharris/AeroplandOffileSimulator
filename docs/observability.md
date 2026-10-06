# Observability — Aeroplane Simulator Offline

Local-first debugging for an offline kids' game. No analytics, no telemetry —
everything below runs on your Mac.

## 1. Live logs (the game writes nothing itself — watch the system log)

```bash
./aero logs              # unified log, bundle id, last 2 min
./aero logs --last 10m   # wider window after a play session
```

What good looks like: process starts, stays alive, no `EXC_` / `SceneKit`
errors. A clean 10-second flight with zero error lines = pass.

## 2. Crash reports

```bash
ls -lt ~/Library/Logs/DiagnosticReports/ | grep -i aero
```

Open the newest `.ips`, read `Exception Type` + `Triggered by Thread` backtrace,
top 5 frames point at the guilty file (usually `FlightScene.swift` renderer or
`FlyView.swift` input). Attach the `.ips` path + those 5 frames to the issue.

## 3. Launch-smoke evidence (required after flight/input/scene changes)

```bash
./aero ci                                   # gate green first
./scripts/package_app.sh 1.0.0             # fresh bundle
open "dist/Aeroplane Simulator Offline.app" # must open, stay alive ≥10s
./aero logs                                # confirm no errors
```

Record: app opened (yes/no), seconds alive, stars collected in-session,
log errors (none/list). Paste this block into the issue/PR.

## 4. Verification Gate recap

| Step | Command | Proves |
|---|---|---|
| Build | `swift build` | compiles, zero errors |
| Tests | `swift test` + `cli/check_catalogue.py` | XCTest on full Xcode/CI; stdlib catalogue rules everywhere |
| Index drift | `./aero index` vs committed | inventory matches code |
| Map drift | `./aero map:gen` vs committed | wiring matches code |
| Bundle smoke | `./aero verify` | installable artifact is valid |

`./aero ci` runs all five. Red = do not merge to `main`, do not release.
