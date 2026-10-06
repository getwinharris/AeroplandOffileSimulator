---
name: scenekit-world
description: Use when editing the flight loop, mouse/SHIFT steering, clouds, stars, rings, camera, or any 3D world behavior.
---
# SceneKit World + Flight Loop

- Follow the root `AGENTS.md` repository contract: `./aero map` first.
- The world is `Sources/AeroplaneSimulatorOffline/Game/FlightScene.swift`:
  `buildWorld()` runs once (sky, ocean, island, clouds, stars, rings, balloons,
  plane + chase camera); `renderer(_:updateAtTime:)` runs at 60fps.
- Steering contract: `FlyView.FlySCNView` writes `mouseSteer` (-1…1) and
  `boostHeld`; the renderer converts them to `yaw/pitch/velocity`. Keep input
  mapping in `FlyView.swift`, physics in `FlightScene.swift` — never duplicate.
- Kid-proof invariants (keep them): speed auto-forward always; `pos.y` clamped
  to 4…150 with a `boing` bounce (never crash); world bounds steer home;
  `pitch` auto-levels (`*= 1 - dt*0.6`).
- Collectibles: stars hide + respawn after 6s (`onStar`); rings teleport on
  fly-through (`onRing`). Both callbacks hop to main thread.
- Verify: `swift build`, then `./aero build-app` + launch smoke and watch
  `./aero logs` during a 10-second flight (see `docs/observability.md`).
