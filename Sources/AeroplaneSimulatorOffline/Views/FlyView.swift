import SwiftUI
import SceneKit
import AppKit

/// Fly screen: SceneKit view + mouse-steer + SHIFT boost + kid HUD.
struct FlyView: View {
    @EnvironmentObject var game: GameState
    @State private var scene: FlightScene?
    @State private var scnView: SCNView?

    var body: some View {
        ZStack {
            SceneKitFlyView(scene: $scene, scnView: $scnView, game: game)
                .ignoresSafeArea()
                .onAppear {
                    let s = FlightScene(plane: game.selectedPlane)
                    s.sensitivity = Float(game.sensitivity)
                    s.invertY = game.invertY
                    s.onStar = { game.collectStar() }
                    s.onRing = { game.flyThroughRing() }
                    s.onStats = { speed, alt, boosting in
                        game.speedKnots = speed
                        game.altitude = alt
                        game.isBoosting = boosting
                    }
                    scene = s
                }
                .onChange(of: game.selectedPlane) { scene?.plane = $0 }
                .onChange(of: game.sensitivity) { scene?.sensitivity = Float($0) }
                .onChange(of: game.invertY) { scene?.invertY = $0 }

            VStack {
                // Top HUD — big and readable for kids
                HStack(spacing: 14) {
                    HudPill(emoji: game.selectedPlane.emoji, text: game.selectedPlane.name)
                    HudPill(emoji: "⭐", text: "\(game.stars)")
                    HudPill(emoji: "🟠", text: "\(game.rings)")
                    HudPill(emoji: "💨", text: "\(game.speedKnots)")
                    if game.isBoosting {
                        Text("⚡ BOOST!").font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.pink, in: Capsule())
                    }
                    Spacer()
                    Button("Menu 🔙") { SoundManager.shared.click(); game.screen = .menu }
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                }.padding()

                Spacer()

                // Bottom hint bar
                HStack(spacing: 16) {
                    Text("🖱️ Move mouse to steer")
                    Text("⚡ Hold SHIFT to BOOST!")
                    Slider(value: $game.sensitivity, in: 0.5...2.0).frame(width: 120)
                }
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Color.black.opacity(0.35), in: Capsule())
                .padding(.bottom, 16)
            }

            if game.showCelebration {
                CelebrationView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BackToMenu"))) { _ in
            game.screen = .menu
        }
    }
}

struct HudPill: View {
    let emoji: String; let text: String
    var body: some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 22))
            Text(text).font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.black.opacity(0.35), in: Capsule())
    }
}

struct CelebrationView: View {
    var body: some View {
        VStack {
            Text("🎉🎉🎉").font(.system(size: 80))
            Text("HURRAY! 10 STARS!").font(.system(size: 54, weight: .black, design: .rounded))
                .foregroundColor(.yellow).shadow(radius: 10)
            Text("You're a super pilot! ✈️").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white)
        }
        .padding(30).background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 30))
    }
}

// MARK: - NSViewRepresentable with mouse + shift tracking
struct SceneKitFlyView: NSViewRepresentable {
    @Binding var scene: FlightScene?
    @Binding var scnView: SCNView?
    var game: GameState

    func makeNSView(context: Context) -> FlySCNView {
        let v = FlySCNView()
        v.allowsCameraControl = false
        v.showsStatistics = false
        v.backgroundColor = .clear
        v.delegate = scene
        v.isPlaying = true
        v.preferredFramesPerSecond = 60
        context.coordinator.view = v
        return v
    }

    func updateNSView(_ nsView: FlySCNView, context: Context) {
        if nsView.scene !== scene {
            nsView.scene = scene
            nsView.delegate = scene
        }
        context.coordinator.game = game
        nsView.gameScene = scene
    }

    func makeCoordinator() -> Coordinator { Coordinator(game: game) }

    final class Coordinator: NSObject {
        var game: GameState
        weak var view: FlySCNView?
        init(game: GameState) { self.game = game }
    }
}

/// SCNView that turns mouse position into steering + SHIFT / mouse-down into boost.
final class FlySCNView: SCNView {
    weak var gameScene: FlightScene?
    private var tracking: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        tracking = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited], owner: self, userInfo: nil)
        addTrackingArea(tracking!)
        window?.makeFirstResponder(self)
    }

    override func mouseMoved(with event: NSEvent) { steer(with: event) }
    override func mouseDragged(with event: NSEvent) { steer(with: event); gameScene?.boostHeld = true }
    override func mouseDown(with event: NSEvent) { gameScene?.boostHeld = true }
    override func mouseUp(with event: NSEvent) { gameScene?.boostHeld = event.modifierFlags.contains(.shift) }
    override func flagsChanged(with event: NSEvent) {
        gameScene?.boostHeld = event.modifierFlags.contains(.shift)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC → menu (handled via notification)
            NotificationCenter.default.post(name: .init("BackToMenu"), object: nil)
        } else {
            super.keyDown(with: event)
        }
    }

    private func steer(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard bounds.width > 0, bounds.height > 0 else { return }
        // -1…1, centre = straight
        let dx = (loc.x / bounds.width) * 2 - 1
        let dy = (loc.y / bounds.height) * 2 - 1
        gameScene?.mouseSteer = CGVector(dx: dx, dy: dy)
        if event.modifierFlags.contains(.shift) { gameScene?.boostHeld = true }
    }
}
