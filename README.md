# ✈️ Aeroplane Simulator Offline
**A super-simple, kid-safe (3–5 yrs) aeroplane game for Mac — 100% offline, no ads.**

Move the **mouse to steer**, hold **SHIFT to BOOST**. Pick from 6 cute planes,
collect ⭐ stars, fly through 🟠 rings. You can't crash — the plane just bounces and giggles!

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![SwiftUI](https://img.shields.io/badge/SwiftUI-SceneKit-orange) ![Offline](https://img.shields.io/badge/offline-yes-green)

## 🎮 Play in 30 seconds
```bash
gh repo clone getwinharris/AeroplandOffileSimulator
cd AeroplandOffileSimulator
./run.sh
# then: open Package.swift in Xcode → ▶ Run
```
> `swift build` verifies logic anywhere; full 3D play needs Xcode Run (SceneKit window).

## 🛩️ The 6 planes (menu → tap to pick)
| Plane | Vibe | Speed |
|---|---|---|
| Ruby Jet 🛩️ | super fast + zoomy | ●●● |
| Blue Buddy ✈️ | easiest steering | ●● |
| Sunny Biplane 🛫 | double wings | ●● |
| Gerry Glider 🪂 | floats soft + slow | ● |
| Pinky Jumbo 🎀 | big + cuddly | ● |
| Rocket Rory 🚀 | to the stars! | ●●● |

## 🖱️ Controls (Mac)
- **Mouse move** — steer (no clicking needed!)
- **SHIFT hold / mouse hold / Space** — BOOST ⚡ with rainbow trail
- **ESC** — back to menu
- Sensitivity slider at the bottom for tiny hands

## 📦 Repo layout
```
Package.swift                          # swift-tools 5.9, macOS 13+
Sources/AeroplaneSimulatorOffline/
  Views/App.swift                      # @main, ContentView, BigKidButton
  Views/MainMenuView.swift             # menu + How-to-Fly
  Views/PlaneSelectionView.swift       # 6-plane picker
  Views/FlyView.swift                  # SceneKit host + HUD + mouse/shift
  Models/Plane.swift                   # catalogue
  Models/GameState.swift               # stars/rings/sound
  Game/PlaneFactory.swift              # procedural cute 3D planes (sellable!)
  Game/FlightScene.swift               # island/ocean/clouds/stars/rings
  Game/SoundManager.swift              # synthesised offline sounds
Docs/FreeAssets.md                     # how to swap in CC0 .usdz legally
AppStore/                              # listing text, privacy, screenshots checklist
```

## 🏪 Sell on the Mac App Store
- **Name:** `Aeroplane Simulator Offline`
- **Bundle ID suggestion:** `com.getwinharris.aeroplane-simulator-offline`
- **Category:** Games → Family / Kids 5 & Under
- **Steps:** Open `Package.swift` in Xcode → set Signing (your Team) →
  bump version → Product → Archive → Distribute → App Store Connect.
  See `AppStore/Listing.md` for title, subtitle, keywords, privacy answers
  (no data collected, fully offline → trivial review).
- **Why this passes review:** sandboxed, no network entitlement,
  no third-party assets (all art + sound generated in code), no ads/IAP,
  no fail state — ideal for Kids category.

## 🔧 Version control (gh cli)
```bash
gh repo clone getwinharris/AeroplandOffileSimulator
git checkout -b feature/my-tweak
git add -A && git commit -m "feat: my tweak" && git push -u origin feature/my-tweak
gh pr create --fill && gh pr merge --squash
```

## 📄 Licence
© 2026 GetWinHarris. All code + procedural art in this repo is yours to sell.
If you add CC0 packs (Kenney / Quaternius), they remain CC0 — see `Docs/FreeAssets.md`.
