---
name: macos-swiftui
description: Use when editing SwiftUI screens, HUD, menu, plane picker, navigation, or kid-safe UI patterns.
---
# macOS SwiftUI Screens

- Follow the root `AGENTS.md` repository contract: `./aero map` first, check
  `docs/project-index.json` before claiming a screen exists.
- Screens live in `Sources/AeroplaneSimulatorOffline/Views/`. One file per
  screen: `MainMenuView.swift`, `PlaneSelectionView.swift`, `FlyView.swift`.
  Shared chrome (`ContentView`, `BigKidButton`, colour tokens) lives in `App.swift`.
- Navigation is `GameState.screen` (`menu/planes/fly/help`) — extend the enum,
  never add a parallel router.
- Kid-safe rules: buttons ≥ 64pt targets, rounded heavy fonts, emoji + words,
  no text-only flows, no fail states.
- State flows one way: views read `@EnvironmentObject GameState`; the 3D scene
  reports back via `onStar/onRing/onStats` closures.
- Verify: `swift build`, then launch the `.app` and click through the changed
  screen (see `docs/observability.md`).
