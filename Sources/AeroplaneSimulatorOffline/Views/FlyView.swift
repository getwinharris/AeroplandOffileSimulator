import SwiftUI
import SceneKit
import AppKit

/// GTA VI-styled flight screen with Leonida radar minimap, telemetry, and GTA V keyboard controls.
struct FlyView: View {
    @EnvironmentObject var game: GameState
    @State private var scene: FlightScene?
    @State private var scnView: SCNView?
    @State private var lastZone: String = ""
    @State private var showZoneBanner: Bool = false

    var body: some View {
        ZStack {
            SceneKitFlyView(scene: $scene, scnView: $scnView, game: game)
                .ignoresSafeArea()
                .onAppear {
                    let s = FlightScene(plane: game.selectedPlane)
                    s.sensitivity = Float(game.sensitivity)
                    s.invertY = game.invertY
                    s.gearDown = game.gearDown
                    s.cameraMode = game.cameraMode

                    s.onStar = { game.collectStar() }
                    s.onRing = { game.flyThroughRing() }

                    s.onTouchdown = { notice in
                        game.notify(notice)
                    }

                    s.onTelemetry = { t in
                        game.speedKnots = t.airspeed
                        game.altitude = t.altitude
                        game.heading = t.headingDeg
                        game.pitchDeg = t.pitchDeg
                        game.bankDeg = t.bankDeg
                        game.isBoosting = t.isBoosting
                        game.throttlePercent = t.throttlePct
                        game.gForce = t.gForce
                        game.gearDown = t.gearDown
                        game.cameraMode = t.cameraMode
                        game.planePosX = t.posX
                        game.planePosZ = t.posZ

                        if t.zone != game.currentZone {
                            game.currentZone = t.zone
                            game.currentSubzone = t.subzone
                            showZoneBanner = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                                showZoneBanner = false
                            }
                        }
                    }

                    s.onStats = { alt, verticalSpeed, airspeed, hdgNorm, isBoosting, pitchDeg, bankDeg in
                        game.speedKnots = CGFloat(airspeed * 1.94)
                        game.altitude = alt
                        game.isBoosting = isBoosting
                        game.heading = Double(hdgNorm)
                        game.pitchDeg = Double(pitchDeg)
                        game.bankDeg = Double(bankDeg)
                    }

                    scene = s
                }
                .onChange(of: game.selectedPlane) { scene?.plane = $0 }
                .onChange(of: game.sensitivity) { scene?.sensitivity = Float($0) }
                .onChange(of: game.invertY) { scene?.invertY = $0 }
                .onChange(of: game.gearDown) { scene?.gearDown = $0 }
                .onChange(of: game.cameraMode) { scene?.cameraMode = $0 }

            VStack {
                // Top bar: plane + stars + zone indicator + menu
                HStack(spacing: 12) {
                    HudPill(emoji: game.selectedPlane.emoji, text: game.selectedPlane.name)
                    HudPill(emoji: "⭐", text: "\(game.stars)")
                    HudPill(emoji: "🟠", text: "\(game.rings)")

                    // Current Zone Pill
                    HStack(spacing: 6) {
                        Text("📍").font(.system(size: 16))
                        Text(game.currentZone)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.pink)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .overlay(Capsule().stroke(Color.pink.opacity(0.6), lineWidth: 1))

                    if game.isBoosting {
                        Text("⚡ BOOST!").font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 7)
                            .background(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing), in: Capsule())
                            .shadow(color: .pink, radius: 8)
                    }

                    Spacer()

                    // Quick Camera & Gear toggles
                    Button(action: { game.cycleCamera() }) {
                        Text(cameraName(game.cameraMode))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.black.opacity(0.65), in: Capsule())
                    }.buttonStyle(.plain)

                    Button(action: { game.toggleGear() }) {
                        Text(game.gearDown ? "⚙️ GEAR: DOWN" : "⚙️ GEAR: UP")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(game.gearDown ? .green : .orange)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Color.black.opacity(0.65), in: Capsule())
                    }.buttonStyle(.plain)

                    Button("Menu 🔙") { SoundManager.shared.click(); game.screen = .menu }
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                }.padding(.horizontal, 16).padding(.top, 12)

                // GTA VI Location Discovery Title Card
                if showZoneBanner {
                    VStack(spacing: 2) {
                        Text(game.currentZone)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .tracking(3)
                            .foregroundColor(.white)
                            .shadow(color: .pink.opacity(0.8), radius: 8)
                        Text(game.currentSubzone.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 9)
                    .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LinearGradient(colors: [.pink, .cyan], startPoint: .leading, endPoint: .trailing), lineWidth: 1.5))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 6)
                }

                if let notice = game.activeNotice {
                    Text(notice)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(Color.black.opacity(0.8), in: Capsule())
                        .overlay(Capsule().stroke(Color.yellow, lineWidth: 1.5))
                        .padding(.top, 4)
                }

                Spacer()

                // Bottom HUD: GTA VI Radar Minimap (Left) + Flight Controls Pill (Center) + Flight Tapes (Right)
                HStack(alignment: .bottom, spacing: 16) {
                    // GTA VI Radar Minimap
                    GTA6RadarMinimap(
                        heading: game.heading,
                        posX: game.planePosX,
                        posZ: game.planePosZ,
                        altitude: game.altitude,
                        airfields: GameState.airfields,
                        currentZone: game.currentZone
                    )

                    Spacer()

                    // Center: Controls hint & Flight stats badge
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Text("THR: \(game.throttlePercent)%")
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))

                            Text(String(format: "%.1f G", game.gForce))
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))

                            Button(action: { scene?.respawnAtNearestRunway() }) {
                                Text("🛬 RESPAWN RUNWAY [R]")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundColor(.pink)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain)
                        }

                        // GTA V keyboard controls cheat sheet
                        HStack(spacing: 10) {
                            Text("W/S: Pitch/Gas")
                            Text("•")
                            Text("A/D: Roll")
                            Text("•")
                            Text("Q/E: Rudder")
                            Text("•")
                            Text("Shift: Throttle")
                            Text("•")
                            Text("G: Gear")
                            Text("•")
                            Text("C: Cam")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .background(Color.black.opacity(0.65), in: Capsule())
                        .overlay(Capsule().stroke(LinearGradient(colors: [.cyan.opacity(0.5), .pink.opacity(0.5)], startPoint: .leading, endPoint: .trailing), lineWidth: 1))
                    }

                    Spacer()

                    // Right: MSFS-style instruments
                    HStack(alignment: .bottom, spacing: 10) {
                        SpeedTape(knots: Int(game.speedKnots))
                        Horizon(pitch: game.pitchDeg, bank: game.bankDeg)
                        AltitudeTape(feet: Int(game.altitude))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

            if game.showCelebration {
                CelebrationView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BackToMenu"))) { _ in
            game.screen = .menu
        }
    }

    private func cameraName(_ mode: Int) -> String {
        switch mode {
        case 0: return "🎥 CHASE"
        case 1: return "🎥 WIDE"
        case 2: return "🎥 COCKPIT"
        default: return "🎥 CAM"
        }
    }
}

// MARK: - GTA VI Radar Minimap

struct GTA6RadarMinimap: View {
    let heading: Double
    let posX: CGFloat
    let posZ: CGFloat
    let altitude: CGFloat
    let airfields: [LeonidaAirfield]
    let currentZone: String

    private let radarRadius: CGFloat = 85

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ZStack {
                // Background dark tinted glass disc
                Circle()
                    .fill(Color(red: 0.05, green: 0.08, blue: 0.15).opacity(0.88))
                    .frame(width: radarRadius * 2, height: radarRadius * 2)

                // Range circles
                Circle().stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                    .frame(width: radarRadius * 1.2, height: radarRadius * 1.2)
                Circle().stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                    .frame(width: radarRadius * 0.6, height: radarRadius * 0.6)

                // Crosshair lines
                Path { p in
                    p.move(to: CGPoint(x: radarRadius, y: 15))
                    p.addLine(to: CGPoint(x: radarRadius, y: radarRadius * 2 - 15))
                    p.move(to: CGPoint(x: 15, y: radarRadius))
                    p.addLine(to: CGPoint(x: radarRadius * 2 - 15, y: radarRadius))
                }.stroke(Color.cyan.opacity(0.18), lineWidth: 1)

                // Airfield Blips on Radar
                ForEach(airfields) { af in
                    let dx = (af.position.x - posX) * 0.16
                    let dz = (af.position.y - posZ) * 0.16
                    let dist = sqrt(dx * dx + dz * dz)
                    let clampedDist = min(radarRadius - 14, dist)
                    let angle = atan2(dz, dx)

                    // Rotate according to heading so radar is heading-up
                    let radHdg = heading * Double.pi / 180.0
                    let rx = cos(angle - CGFloat(radHdg)) * clampedDist
                    let ry = sin(angle - CGFloat(radHdg)) * clampedDist

                    VStack(spacing: 0) {
                        Text(af.emoji).font(.system(size: 11))
                        Text(af.code)
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundColor(.pink)
                    }
                    .offset(x: rx, y: ry)
                }

                // Player Aircraft Icon in center (pointing UP)
                VStack(spacing: 0) {
                    Image(systemName: "airplane")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: .cyan, radius: 4)
                }

                // North Indicator on the perimeter
                let northAngle = -heading * Double.pi / 180.0 - Double.pi / 2
                let nx = cos(northAngle) * Double(radarRadius - 10)
                let ny = sin(northAngle) * Double(radarRadius - 10)
                Text("N")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.pink)
                    .offset(x: CGFloat(nx), y: CGFloat(ny))

                // Signature GTA VI double neon border
                Circle()
                    .stroke(
                        LinearGradient(colors: [.pink, .purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2.5
                    )
                    .frame(width: radarRadius * 2, height: radarRadius * 2)
            }

            // Radar Altitude Ladder
            VStack(spacing: 0) {
                Text("ALT").font(.system(size: 9, weight: .black, design: .rounded)).foregroundColor(.cyan)
                ZStack(alignment: .bottom) {
                    Capsule().fill(Color.black.opacity(0.65)).frame(width: 8, height: radarRadius * 1.6)
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .pink], startPoint: .bottom, endPoint: .top))
                        .frame(width: 8, height: min(radarRadius * 1.6, altitude * 0.25))
                }
            }
        }
    }
}

// MARK: - HUD Components

struct HudPill: View {
    let emoji: String; let text: String
    var body: some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 20))
            Text(text).font(.system(size: 18, weight: .black, design: .rounded)).foregroundColor(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(Color.black.opacity(0.6), in: Capsule())
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

/// Airspeed Tape (knots)
struct SpeedTape: View {
    let knots: Int
    var body: some View {
        VStack(spacing: 2) {
            Text("SPEED").font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.8))
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.7)).frame(width: 78, height: 160)
                VStack(spacing: 6) {
                    ForEach([-20, -10, 10, 20], id: \.self) { d in
                        Text("\(max(0, knots + d))").font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                HStack(spacing: 2) {
                    Text("\(knots)").font(.system(size: 24, weight: .black, design: .rounded)).foregroundColor(.green)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
            }
            Text("KTS").font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.8))
        }
    }
}

/// Altitude Tape (feet)
struct AltitudeTape: View {
    let feet: Int
    var body: some View {
        VStack(spacing: 2) {
            Text("ALTITUDE").font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.8))
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.7)).frame(width: 86, height: 160)
                VStack(spacing: 6) {
                    ForEach([-200, -100, 100, 200], id: \.self) { d in
                        Text("\(max(0, feet + d))").font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                Text("\(feet)").font(.system(size: 24, weight: .black, design: .rounded)).foregroundColor(.cyan)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
            }
            Text("FEET").font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(.white.opacity(0.8))
        }
    }
}

/// Artificial Horizon Gyro
struct Horizon: View {
    let pitch: Double
    let bank: Double

    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.75)).frame(width: 130, height: 130)
            ZStack {
                Rectangle().fill(Color.blue.opacity(0.7)).frame(width: 130, height: 65).offset(y: -32.5)
                Rectangle().fill(Color.brown.opacity(0.7)).frame(width: 130, height: 65).offset(y: 32.5)
                Rectangle().fill(Color.white).frame(width: 130, height: 2)
            }
            .clipShape(Circle())
            .offset(y: CGFloat(pitch.clamped(to: -30...30)) * 1.5)
            .rotationEffect(.degrees(-bank))

            // Airplane reticle
            HStack(spacing: 12) {
                Rectangle().fill(Color.yellow).frame(width: 25, height: 3)
                Circle().fill(Color.yellow).frame(width: 6, height: 6)
                Rectangle().fill(Color.yellow).frame(width: 25, height: 3)
            }

            Circle().stroke(Color.white.opacity(0.6), lineWidth: 2).frame(width: 130, height: 130)
        }
    }
}

// MARK: - SceneKit NSView Representable & GTA V Input Controller

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

        let args = CommandLine.arguments
        if !context.coordinator.shotDone,
           let i = args.firstIndex(of: "--shot"), i + 1 < args.count {
            context.coordinator.shotDone = true
            let path = args[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
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

/// GTA V Style Keyboard & Mouse Flight Controller SCNView
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

    // Mouse steering
    override func mouseMoved(with event: NSEvent) { steer(with: event) }
    override func mouseDragged(with event: NSEvent) { steer(with: event); gameScene?.boostHeld = true }
    override func mouseDown(with event: NSEvent) { gameScene?.boostHeld = true }
    override func mouseUp(with event: NSEvent) { gameScene?.boostHeld = event.modifierFlags.contains(.shift) }

    override func flagsChanged(with event: NSEvent) {
        let shift = event.modifierFlags.contains(.shift)
        let ctrl = event.modifierFlags.contains(.control)

        gameScene?.boostHeld = shift
        if shift {
            gameScene?.throttleChange = 1.0
        } else if ctrl {
            gameScene?.throttleChange = -1.0
        } else {
            gameScene?.throttleChange = 0
        }
    }

    // GTA V Keyboard Controls
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // ESC → menu
            NotificationCenter.default.post(name: .init("BackToMenu"), object: nil)
        case 13, 126: // W or Up Arrow → Pitch Down (dive)
            gameScene?.pitchInput = -1.0
        case 1, 125:  // S or Down Arrow → Pitch Up (climb)
            gameScene?.pitchInput = 1.0
        case 0, 123:  // A or Left Arrow → Roll Left
            gameScene?.rollInput = -1.0
        case 2, 124:  // D or Right Arrow → Roll Right
            gameScene?.rollInput = 1.0
        case 12:      // Q → Rudder Left (yaw left)
            gameScene?.rudderInput = -1.0
        case 14:      // E → Rudder Right (yaw right)
            gameScene?.rudderInput = 1.0
        case 5:       // G → Toggle Landing Gear
            if let gs = gameScene {
                gs.gearDown.toggle()
                SoundManager.shared.gear()
            }
        case 8, 9:    // C or V → Cycle Camera Modes
            if let gs = gameScene {
                gs.cameraMode = (gs.cameraMode + 1) % 3
                SoundManager.shared.click()
            }
        case 15:      // R → Respawn / Reset to nearest runway
            gameScene?.respawnAtNearestRunway()
            SoundManager.shared.fanfare()
        case 49:      // Spacebar → Emergency Boost
            gameScene?.boostHeld = true
        default:
            super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 13, 1, 126, 125: // W, S, Up, Down
            gameScene?.pitchInput = 0
        case 0, 2, 123, 124:  // A, D, Left, Right
            gameScene?.rollInput = 0
        case 12, 14:          // Q, E
            gameScene?.rudderInput = 0
        case 49:              // Spacebar
            gameScene?.boostHeld = event.modifierFlags.contains(.shift)
        default:
            super.keyUp(with: event)
        }
    }

    private func steer(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let dx = (loc.x / bounds.width) * 2 - 1
        let dy = (loc.y / bounds.height) * 2 - 1
        gameScene?.mouseSteer = CGVector(dx: dx, dy: dy)
        if event.modifierFlags.contains(.shift) { gameScene?.boostHeld = true }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
