# Real 3D assets in this game — sources, licences, how to stay legal

The game loads **actual 3D model files** (`.obj` + `.mtl` + `.png`) from
`Sources/AeroplaneSimulatorOffline/Resources/Planes/`, rendered natively with
SceneKit + ModelIO. No three.js, no web views — everything is bundled and the
game is fully offline.

## The fleet (all verified sellable on the Mac App Store)

| File | Aircraft | Source | Licence |
|---|---|---|---|
| `cessna.obj` | Cessna-style trainer | [OpenGameArt "Cesna Airplane"](https://opengameart.org/content/cesna-airplane) by wobba89, converted with Blender | **CC-BY 3.0** — credit kept in HelpView + below |
| `paxjet.obj` | Passenger jet | [OpenGameArt "Jet airplane"](https://opengameart.org/content/jet-airplane), converted with Blender | CC0 |
| `twinprop.obj` | Twin turboprop | [OpenGameArt "Twin turboprop rigged airplane"](https://opengameart.org/content/twin-turboprop-rigged-airplane-low-poly), converted with Blender | CC0 |
| `ww1.obj` | WWI biplane | [OpenGameArt "WW1 Airplane model obj"](https://opengameart.org/content/ww1-wwi-airplane-model-obj) (paint `WWIairplane.mtl` authored by us — file shipped without materials) | CC0 |
| `an2.obj` | Antonov An-2 | [OpenGameArt "An-2 Airplane Lowpoly"](https://opengameart.org/content/an-2-airplane-lowpoly), FBX→DAE via assimp → OBJ | CC0 |
| `heli.obj` | Cartoon helicopter | [OpenGameArt "Cartoon Helicopter"](https://opengameart.org/content/cartoon-helicopter-0), FBX→DAE via assimp → OBJ | CC0 |

**CC-BY 3.0 credit (legally required, also shown in-game under How to Fly):**
Cessna-style 3D model by wobba89, https://opengameart.org/content/cesna-airplane,
licensed CC-BY 3.0.

Conversion notes: `.blend` files were exported with Blender 5.2 headless
(`bpy.ops.wm.obj_export`, triangulated + materials); `.fbx` files converted
with assimp 6 (`assimp export x.fbx x.dae`, then to OBJ — ModelIO reads OBJ
deterministically, while SceneKit's `.dae` path needs an XPC service).

## Rules for adding more aircraft
- ✅ CC0 or CC-BY (with credit added here + in HelpView).
- ❌ No GPL / CC-BY-SA / NC / ND — copyleft and non-commercial terms conflict
  with App Store distribution.
- ❌ No Sketchfab/TurboSquid "free" models unless the licence page says
  commercial resale is allowed.
- ❌ Don't hot-link http models at runtime — breaks the Offline promise.
- After adding files: `./aero index` (assets are inventoried) + `./aero ci`.

## macOS controls
- **Mouse move** = steer (left/right turn, up/down climb & dive)
- **SHIFT hold** (or mouse-button hold) = BOOST + rainbow trail
- **ESC** = back to menu
