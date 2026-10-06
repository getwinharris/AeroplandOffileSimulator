import SwiftUI

/// Kid-friendly plane catalogue.
/// All 3D models are built procedurally in code (PlaneFactory) so the app
/// is 100% offline and App-Store-safe (no third-party licence issues).
/// To use free CC0 assets instead, drop .usdz files into
/// `Resources/Planes/` named e.g. `red-jet.usdz` — see Docs/FreeAssets.md.
struct KidPlane: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let tagline: String
    let bodyColor: UInt32
    let wingColor: UInt32
    let topSpeed: Float   // m/s base
    let turnSpeed: Float  // multiplier
    let style: PlaneStyle
}

enum PlaneStyle: String, Hashable {
    case jet, prop, biplane, glider, jumbo, rocket
}

extension KidPlane {
    static let all: [KidPlane] = [
        KidPlane(id: "red-jet", name: "Ruby Jet", emoji: "🛩️",
                 tagline: "Super fast and zoomy!",
                 bodyColor: 0xE84040, wingColor: 0xFFD23F,
                 topSpeed: 38, turnSpeed: 1.2, style: .jet),
        KidPlane(id: "blue-prop", name: "Blue Buddy", emoji: "✈️",
                 tagline: "Easy to steer for little pilots!",
                 bodyColor: 0x3FA7FF, wingColor: 0xFFFFFF,
                 topSpeed: 26, turnSpeed: 1.6, style: .prop),
        KidPlane(id: "yellow-biplane", name: "Sunny Biplane", emoji: "🛫",
                 tagline: "Two wings, double fun!",
                 bodyColor: 0xFFC93C, wingColor: 0xE84040,
                 topSpeed: 24, turnSpeed: 1.5, style: .biplane),
        KidPlane(id: "green-glider", name: "Gerry Glider", emoji: "🪂",
                 tagline: "Floats soft and slow.",
                 bodyColor: 0x4CC96F, wingColor: 0xD8F3DC,
                 topSpeed: 20, turnSpeed: 1.1, style: .glider),
        KidPlane(id: "pink-jumbo", name: "Pinky Jumbo", emoji: "🎀",
                 tagline: "Big, friendly and cuddly!",
                 bodyColor: 0xFF8FAB, wingColor: 0xFFF0F3,
                 topSpeed: 22, turnSpeed: 1.0, style: .jumbo),
        KidPlane(id: "orange-rocket", name: "Rocket Rory", emoji: "🚀",
                 tagline: "To the stars! Hold SHIFT to BOOST!",
                 bodyColor: 0xFF7B2E, wingColor: 0x5A189A,
                 topSpeed: 46, turnSpeed: 1.35, style: .rocket),
    ]
}
