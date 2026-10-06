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
    @Published var speedKnots: Int = 0
    @Published var altitude: Int = 0
    @Published var isBoosting: Bool = false
    @Published var showCelebration: Bool = false
    @Published var soundOn: Bool = true
    @Published var sensitivity: Double = 1.0   // 0.5 … 2.0
    @Published var invertY: Bool = false

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
