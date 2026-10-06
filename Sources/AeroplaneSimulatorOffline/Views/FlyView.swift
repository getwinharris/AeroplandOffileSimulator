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
                    s.onStats = { speed, alt, boosting, hdg, pitch, bank in
                        game.speedKnots = speed
                        game.altitude = alt
                        game.isBoosting = boosting
                        game.heading = Double(hdg)
                        game.pitchDeg = Double(pitch)
                        game.bankDeg = Double(bank)
                    }
                    scene = s
                }
                .onChange(of: game.selectedPlane) { scene?.plane = $0 }
                .onChange(of: game.sensitivity) { scene?.sensitivity = Float($0) }
                .onChange(of: game.invertY) { scene?.invertY = $0 }

            VStack {
                // Top bar: plane + stars + compass + menu
                HStack(spacing: 14) {
                    HudPill(emoji: game.selectedPlane.emoji, text: game.selectedPlane.name)
                    HudPill(emoji: "⭐", text: "\(game.stars)")
                    HudPill(emoji: "🟠", text: "\(game.rings)")
                    CompassStrip(heading: game.heading)
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

                // MSFS-style tapes: speed left, horizon + altitude right
                HStack {
                    SpeedTape(knots: game.speedKnots)
                    Spacer()
                    HStack(alignment: .bottom, spacing: 10) {
                        Horizon(pitch: game.pitchDeg, bank: game.bankDeg)
                        AltitudeTape(feet: game.altitude)
                    }
                }.padding(.horizontal, 16)

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

// MARK: - MSFS-style instruments (big + kid-readable)

/// Vertical scrolling airspeed tape (knots).
struct SpeedTape: View {
    let knots: Int
    var body: some View {
        VStack(spacing: 2) {
            Text("SPEED").font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.8))
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.55)).frame(width: 86, height: 190)
                VStack(spacing: 7) {
                    ForEach([-20, -10, 10, 20], id: \.self) { d in
                        Text("\(max(0, knots + d))").font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                HStack(spacing: 0) {
                    Text("💨").font(.system(size: 18))
                    Text("\(knots)").font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(.green)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 9))
            }
            Text("KTS").font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.8))
        }
    }
}

/// Vertical scrolling altitude tape (feet).
struct AltitudeTape: View {
    let feet: Int
    var body: some View {
        VStack(spacing: 2) {
            Text("ALTITUDE").font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.8))
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.55)).frame(width: 96, height: 190)
                VStack(spacing: 7) {
                    ForEach([-200, -100, 100, 200], id: \.self) { d in
                        Text("\(max(0, feet + d))").font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                Text("\(feet)").font(.system(size: 26, weight: .black, design: .rounded)).foregroundColor(.cyan)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 9))
            }
            Text("FEET").font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.8))
        }
    }
}

/// Heading compass strip (N/NE/E/… + degrees).
struct CompassStrip: View {
    let heading: Double
    private static let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Capsule().fill(Color.black.opacity(0.55)).frame(width: 210, height: 34)
                HStack(spacing: 14) {
                    ForEach(-1...1, id: \.self) { off in
                        let h = Int((heading + Double(off) * 15).truncatingRemainder(dividingBy: 360))
                        let norm = (h + 360) % 360
                        let label = norm % 45 == 0 ? Self.points[norm / 45] : "\(norm)"
                        Text(label).font(.system(size: off == 0 ? 17 : 13, weight: off == 0 ? .black : .semibold, design: .rounded))
                            .foregroundColor(off == 0 ? .yellow : .white.opacity(0.7))
                            .frame(width: 44)
                    }
                }
                Text("▲").font(.system(size: 12)).foregroundColor(.yellow).offset(y: -13)
            }
            Text("\(Int(heading))°").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.85))
        }
    }
}

/// Artificial horizon: sky/ground split, moves with pitch, rolls with bank.
struct Horizon: View {
    let pitch: Double
    let bank: Double
    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.55)).frame(width: 110, height: 110)
            VStack(spacing: 0) {
                Color(red: 0.3, green: 0.65, blue: 1.0)
                Color(red: 0.55, green: 0.38, blue: 0.2)
            }
            .frame(width: 92, height: 92)
            .rotationEffect(.degrees(-bank))
            .offset(y: CGFloat(-pitch * 1.1))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 2).frame(width: 92, height: 92))
            // fixed wings
            HStack(spacing: 26) {
                RoundedRectangle(cornerRadius: 3).fill(Color.yellow).frame(width: 26, height: 5)
                RoundedRectangle(cornerRadius: 3).fill(Color.yellow).frame(width: 26, height: 5)
            }
        }.frame(width: 110, height: 110)
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
        if scnView == nil { scnView = nsView }
        context.coordinator.game = game
        nsView.gameScene = scene
        // Dev screenshot: open ... --args --fly --plane X --shot /tmp/shot.png
        let args = CommandLine.arguments
        if !context.coordinator.shotDone,
           let i = args.firstIndex(of: "--shot"), i + 1 < args.count {
            context.coordinator.shotDone = true
            let path = args[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                let img = nsView.snapshot()
                if let tiff = img.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: path))
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(game: game) }

    final class Coordinator: NSObject {
        var game: GameState
        var shotDone = false
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
