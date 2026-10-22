import SwiftUI
import Combine

/// Shared game state — simple enough for a 3-5 year old:
/// no lives, no game-over, only stars and smiles.
final class GameState: ObservableObject {
    enum Screen { case menu, planes, fly, help }
    @Published var screen: Screen = .menu
    @Published var selectedPlane: KidPlane = KidPlane.all[1]
    @Published var stars: Int = 0
    @Published var rings: Int = 0
    @Published var speedKnots: CGFloat = 0
    @Published var altitude: CGFloat = 0
    @Published var heading: Double = 0
    @Published var pitchDeg: Double = 0
    @Published var bankDeg: Double = 0
    @Published var isBoosting: Bool = false
    @Published var showCelebration: Bool = false
    @Published var soundOn: Bool = true
    @Published var sensitivity: Double = 1.0   // 0.5 … 2.0
    @Published var invertY: Bool = false

    // GTA VI Leonida Telemetry & State
    @Published var currentZone: String = "VICE CITY"
    @Published var currentSubzone: String = "Metro International"
    @Published var gearDown: Bool = true
    @Published var throttlePercent: Int = 60
    @Published var gForce: Double = 1.0
    @Published var cameraMode: Int = 0 // 0: Close Chase, 1: Far Chase, 2: Cockpit
    @Published var planePosX: CGFloat = 220
    @Published var planePosZ: CGFloat = 120
    @Published var activeNotice: String? = nil

    static let airfields: [LeonidaAirfield] = [
        LeonidaAirfield(id: "vcia", code: "VCIA", name: "Vice City International", zone: "VICE CITY", position: CGPoint(x: 220, y: 120), elevation: 1.0, runwayHeading: 90, runwayLength: 260, emoji: "✈️"),
        LeonidaAirfield(id: "keys", code: "KEYS", name: "Leonida Keys Airstrip", zone: "LEONIDA KEYS", position: CGPoint(x: 80, y: 420), elevation: 1.0, runwayHeading: 120, runwayLength: 160, emoji: "🏝️"),
        LeonidaAirfield(id: "kalaga", code: "KLGA", name: "Mount Kalaga Ridge", zone: "MOUNT KALAGA", position: CGPoint(x: -80, y: -360), elevation: 48.0, runwayHeading: 0, runwayLength: 180, emoji: "⛰️"),
        LeonidaAirfield(id: "gellhorn", code: "PORT", name: "Port Gellhorn Airfield", zone: "PORT GELLHORN", position: CGPoint(x: -320, y: -60), elevation: 1.0, runwayHeading: 90, runwayLength: 200, emoji: "⚓"),
        LeonidaAirfield(id: "ambrosia", code: "AMBR", name: "Ambrosia Dustoff Strip", zone: "AMBROSIA", position: CGPoint(x: 40, y: -100), elevation: 6.0, runwayHeading: 30, runwayLength: 150, emoji: "🌾"),
        LeonidaAirfield(id: "everglades", code: "EVRG", name: "Grassrivers Bush Strip", zone: "GRASSRIVERS", position: CGPoint(x: -160, y: 200), elevation: 1.0, runwayHeading: 150, runwayLength: 140, emoji: "🐊")
    ]

    func toggleGear() {
        gearDown.toggle()
        SoundManager.shared.gear()
        notify(gearDown ? "⚙️ LANDING GEAR: DOWN" : "⚙️ LANDING GEAR: UP")
    }

    func cycleCamera() {
        cameraMode = (cameraMode + 1) % 3
        SoundManager.shared.click()
        let names = ["🎥 CHASE (CLOSE)", "🎥 CHASE (WIDE)", "🎥 COCKPIT / NOSE"]
        notify(names[cameraMode])
    }

    func notify(_ text: String) {
        activeNotice = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.activeNotice == text {
                self.activeNotice = nil
            }
        }
    }

    func collectStar() {
        stars += 1
        SoundManager.shared.pickup()
        if stars % 10 == 0 {
            showCelebration = true
            SoundManager.shared.fanfare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                self.showCelebration = false
            }
        }
    }

    func flyThroughRing() {
        rings += 1
        SoundManager.shared.ring()
    }

    func startFlying(with plane: KidPlane) {
        selectedPlane = plane
        stars = 0
        rings = 0
        screen = .fly
    }
}

struct LeonidaAirfield: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let zone: String
    let position: CGPoint
    let elevation: CGFloat
    let runwayHeading: Double
    let runwayLength: CGFloat
    let emoji: String
}
