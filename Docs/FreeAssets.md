# Free 3D assets — how to stay legal when selling on the Mac App Store

This app ships with **procedurally-built cartoon planes** (see
`Sources/.../Game/PlaneFactory.swift`), so it is 100% yours to sell.
No attribution required, works fully offline.

## If you want "real" downloadable 3D planes instead

Only use **CC0 / public-domain** packs (commercial use allowed, no attribution):

1. **Kenney — Planes pack (CC0)** — https://kenney.nl/assets/planes
   Download → `File → Export → .usdz` (via Blender or Reality Converter)
   Drop into `Resources/Planes/red-jet.usdz`, etc.
2. **Quaternius — Ultimate Air + Nature packs (CC0)** — https://quaternius.com
3. **Apple Reality Composer sample .usdz** (free for developers)

### Wiring a .usdz into the game (5 minutes)
```swift
// In PlaneFactory.makePlaneNode, first try loading a usdz:
if let url = Bundle.main.url(forResource: plane.id, withExtension: "usdz") {
    if let node = try? SCNScene(url: url)?.rootNode.clone() {
        node.scale = SCNVector3(0.5, 0.5, 0.5)
        return node
    }
}
// …else fall back to the built-in cartoon plane
```

### What NOT to do
- ❌ Don't drag random Sketchfab / TurboSquid models in — most forbid resale.
- ❌ Don't hot-link http models at runtime — breaks "Offline" promise + App Store sandbox.
- ✅ Keep everything bundled + offline → passes Kids-category review faster.

## macOS controls (as requested)
- **Mouse move** = steer (left/right turn, up/down climb & dive)
- **SHIFT hold** (or mouse-button hold, or Space) = BOOST + rainbow trail
- **ESC** = back to menu
