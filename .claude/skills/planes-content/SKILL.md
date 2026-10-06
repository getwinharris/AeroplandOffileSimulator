---
name: planes-content
description: Use when editing the plane catalogue, PlaneFactory looks, speed/handling balance, or adding a plane.
---
# Planes Content

- Follow the root `AGENTS.md` repository contract.
- Catalogue: `Sources/AeroplaneSimulatorOffline/Models/Plane.swift`
  (`KidPlane.all`, exactly 6 entries). Looks: `Game/PlaneFactory.swift`
  (`makePlaneNode(for:)`). Menu cards read colours/emoji from the catalogue —
  keep them in sync.
- Balance contract: `topSpeed` 20…46 m/s, `turnSpeed` 1.0…1.6. The slowest
  plane must stay controllable for a 3-year-old at sensitivity 0.5.
- Adding a 7th plane: append one `KidPlane`, add one `PlaneStyle` case (or reuse),
  extend the `switch` in `PlaneFactory` only if the silhouette needs it.
  Then run `./aero index` (concept count changes) + `./aero ci`.
- NEVER drop downloaded 3D files into the repo without updating
  `docs/FreeAssets.md` with the licence. Procedural art is what makes this app
  sellable — see `doc:free-assets` in `index.yaml`.
