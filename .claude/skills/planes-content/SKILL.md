---
name: planes-content
description: Use when editing the plane catalogue, PlaneFactory looks, speed/handling balance, or adding a plane.
---
# Planes Content

- Follow the root `AGENTS.md` repository contract.
- Catalogue: `Sources/AeroplaneSimulatorOffline/Models/Plane.swift`
  (`KidPlane.all`, exactly 6 entries). Each entry points at a real model file
  in `Resources/Planes/` via `modelFile` (+ `yawCorrection` so its nose faces
  -Z, `forceTexture` when the MTL ships none). Loading + auto-centre/scale in
  `Game/PlaneFactory.swift` (`loadRealPlane`). Menu cards read name/emoji from
  the catalogue — keep them in sync.
- Balance contract: `topSpeed` 20…46 m/s, `turnSpeed` 1.0…1.6. The slowest
  plane must stay controllable for a 3-year-old at sensitivity 0.5.
- Adding a 7th plane: drop the `.obj` (+`.mtl`+textures) into `Resources/Planes/`,
  append one `KidPlane` with the right `yawCorrection` (verify nose direction
  with the offscreen harness pattern from the v1.1.0 build), then run
  `./aero index` (concept + asset counts change) + `./aero ci`.
- NEVER drop downloaded 3D files into the repo without updating
  `docs/FreeAssets.md` with the licence (CC0 or CC-BY + credit; never GPL /
  CC-BY-SA / NC). Clean licences are what make this app sellable — see
  `doc:free-assets` in `index.yaml`.
