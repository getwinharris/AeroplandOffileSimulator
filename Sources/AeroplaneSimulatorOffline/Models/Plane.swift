import SwiftUI

/// Real-aircraft catalogue. Every entry loads an actual 3D model FILE
/// (.obj + .mtl + textures) from Sources/.../Resources/Planes/ — no
/// three.js, no web views, everything bundled and fully offline.
///
/// Licences (all sellable — see docs/FreeAssets.md):
/// - cessna: CC-BY 3.0 by wobba89 (OpenGameArt) — credit in HelpView.
/// - everything else: CC0, no attribution required.
struct KidPlane: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let tagline: String
    let modelFile: String   // e.g. "cessna" → Planes/cessna.obj
    let forceTexture: String? // texture to paint on when the MTL ships none
    let yawCorrection: Float // radians to rotate file so its nose faces -Z (we fly -Z)
    let credit: String?     // shown in Help for CC-BY assets
    let topSpeed: Float     // m/s base
    let turnSpeed: Float    // multiplier
    let style: PlaneStyle   // only used by the emergency procedural fallback
}

enum PlaneStyle: String, Hashable {
    case jet, prop, biplane, glider, jumbo, rocket, heli
}

extension KidPlane {
    static let all: [KidPlane] = [
        KidPlane(id: "cessna-trainer", name: "Skyhawk Trainer", emoji: "🛩️",
                 tagline: "Just like a real flying lesson!",
                 modelFile: "cessna", forceTexture: nil, yawCorrection: 0,
                 credit: "Cessna-style model by wobba89 (CC-BY 3.0)",
                 topSpeed: 26, turnSpeed: 1.6, style: .prop),
        KidPlane(id: "jumbo-jet", name: "Sky Jumbo", emoji: "✈️",
                 tagline: "A giant airliner, king of the sky!",
                 modelFile: "paxjet", forceTexture: nil, yawCorrection: 1.5708,
                 credit: nil,
                 topSpeed: 30, turnSpeed: 1.1, style: .jumbo),
        KidPlane(id: "twin-prop", name: "Twin Otter", emoji: "🛫",
                 tagline: "Two propellers, double power!",
                 modelFile: "twinprop", forceTexture: nil, yawCorrection: 0,
                 credit: nil,
                 topSpeed: 32, turnSpeed: 1.3, style: .prop),
        KidPlane(id: "retro-biplane", name: "Retro Biplane", emoji: "🎪",
                 tagline: "A red WWI stunt flyer!",
                 modelFile: "ww1", forceTexture: nil, yawCorrection: 0,
                 credit: nil,
                 topSpeed: 24, turnSpeed: 1.5, style: .biplane),
        KidPlane(id: "bush-plane", name: "Bushmaster", emoji: "🌲",
                 tagline: "Lands anywhere — forests love it!",
                 modelFile: "an2", forceTexture: nil, yawCorrection: -1.5708,
                 credit: nil,
                 topSpeed: 22, turnSpeed: 1.2, style: .prop),
        KidPlane(id: "rescue-heli", name: "Rescue Heli", emoji: "🚁",
                 tagline: "Whirly rescue to the sky!",
                 modelFile: "heli", forceTexture: "heli", yawCorrection: 1.5708,
                 credit: nil,
                 topSpeed: 28, turnSpeed: 1.4, style: .heli),
    ]
}
