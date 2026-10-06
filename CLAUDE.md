# CLAUDE.md

Binding contract for coding agents in this repository. `AGENTS.md` carries the same
contract for non-Claude tooling; if the two ever disagree, this file wins and
`AGENTS.md` must be corrected in the same change.

## Repository

- `getwinharris/AeroplandOffileSimulator` is the only working repository and the
  Mac App Store distribution source. Issues, branches, PRs and releases all live there.
- The repository is independent and unforked. Do not add an upstream remote or
  synchronise from any other copy.
- Canonical project skills live in `.claude/skills/`. Do not create a duplicate
  `.agents/skills/` tree.
- The product has exactly one agent surface: none at runtime. This is a fully
  offline kids' game — no chat, no network, no accounts. Agent guidance here is
  for *development-time* coding agents only.

## Work order

### Navigation budget

For repository questions, use at most three discovery hops before answering:

1. Read this file and only the `discovery`, `query_examples`, and `summary` block at
   the top of `index.yaml`.
2. Narrow-search `index.yaml` or `docs/project-index.json` for the exact screen,
   view, concept, filename, class, or skill.
3. Open the returned original source and answer with its path/symbol.

Do not run broad directory listings, recursive globs, Git history, or read the whole
generated index when the indexed path answers the question. Broaden only when a
target is absent, and state that absence as a finding.

1. `./aero map` before proposing any change.
2. Read this file.
3. **Check `docs/project-index.json` before claiming any feature exists.** It is the
   generated, committed inventory of every screen, view, model and game system.
   If something is not in it, it does not exist — add it rather than
   assuming it is there. Read `docs/systematic-map.mmd` for the wiring diagram.
   Use root `index.yaml` to query original project concepts and relationships.
   Read its `discovery` section first and query narrowly; never load the entire
   generated file into context.
4. Search existing GitHub issues, then open an evidence-backed one (reproduction,
   affected paths, pinpointed cause, acceptance checks). Skip this for read-only
   diagnosis or when the user declines tracking.
5. Read the matching `.claude/skills/<name>/SKILL.md`.
6. Inspect existing implementations before creating any file, screen, view, plane
   or game system.

### Verification Gate (must pass before any PR / release)

`./aero ci` is the gate. It runs, in order:

1. `swift build` (debug) — must compile with zero errors.
2. Tests — `swift test` (XCTest, runs on full Xcode + CI) plus
   `cli/check_catalogue.py` (stdlib-only plane/state rules, runs everywhere
   including CLT-only Macs).
3. Index drift check — `./aero index` output must match committed
   `index.yaml` + `docs/project-index.json` (regenerate, don't hand-edit).
4. Map drift check — `./aero map:gen` output must match `map.mmd` +
   `docs/systematic-map.mmd`.
5. Bundle smoke — release `.app` bundle layout valid, `Info.plist` lints,
   ad-hoc signature verifies, DMG checksum valid (see `docs/observability.md`).

A red gate blocks merging to `main`. `main` is the release branch, so a red
build can still ship — never push red to `main`.

## Architecture

- **Frontend:** SwiftUI views in `Sources/.../Views/` (`App.swift`,
  `MainMenuView.swift`, `PlaneSelectionView.swift`, `FlyView.swift`).
  Big buttons, rounded fonts, no reading required — follow the kid-safe pattern.
- **Game world:** SceneKit in `Sources/.../Game/` (`FlightScene.swift` is the
  world + per-frame flight loop; `PlaneFactory.swift` builds all 3D planes
  procedurally in code; `SoundManager.swift` synthesises all audio offline).
- **State:** `Sources/.../Models/` (`GameState.swift` is the single
  `ObservableObject`; `Plane.swift` is the 6-plane catalogue).
- **Runtime store:** none. No files written at runtime, no network, no database.
  All 3D art and sound are generated in code — this is what makes the app
  legally sellable (see `docs/FreeAssets.md` before adding any downloaded asset).
- **Distribution:** `scripts/package_app.sh` wraps the release binary into
  `dist/Aeroplane Simulator Offline.app` + drag-to-install `.dmg`.

## Environment

- macOS 13+ SDK, Swift 5.9+, SwiftPM. Full Xcode (not just CLT) is required
  for Run/Archive; `swift build` on CLT verifies logic only.
- Bundle ID: `com.getwinharris.aeroplane-simulator-offline`.
- Ad-hoc signing (`codesign -s -`) is for local/dev installs; downloaded copies
  trigger a Gatekeeper malware warning. The fix is Developer ID signing +
  `./scripts/notarize.sh` (paid Developer Program required). App Store
  distribution requires a paid Developer ID + notarization (see
  `.claude/skills/release/SKILL.md`).

## Testing

This is a Mac GUI app. **Verify by building AND launching**, not just compiling:

```bash
./aero ci                  # Verification Gate: build → test → drift → smoke
./scripts/package_app.sh   # click-to-install .app + .dmg in dist/
open "dist/Aeroplane Simulator Offline.app"   # launch smoke: must stay alive, no crash
```

Check `./aero logs` (unified log, last 2 min for the bundle id) rather than
trusting "it built". A successful `swift build` alone does not prove the game
runs — the launch smoke + log check is the proof. Attach launch evidence to
the original issue after any flight-loop, input, or scene change.

## Rules

- Extend existing views, scenes and factories. No parallel implementations.
- Kid-safe UI: big touch targets, no fail states, no text-only flows.
- Never add network entitlements, analytics, ads, or third-party 3D/audio
  assets without a licence note in `docs/FreeAssets.md`.
- Secrets are never committed. (There are none in this repo — keep it that way.)
- Before pushing to `main`: run `./aero ci` and confirm it is green.
- Branch, push, open a PR. Never commit directly to `main`.
