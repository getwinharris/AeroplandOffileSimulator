import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var game: GameState
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("✈️").font(.system(size: 110))
            Text("Aeroplane Simulator")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(radius: 8)
            Text("Offline • Just for Fun!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 20).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            BigKidButton(title: "FLY NOW!", emoji: "🛫", color: .green) {
                game.startFlying(with: game.selectedPlane)
            }
            HStack(spacing: 20) {
                BigKidButton(title: "Planes", emoji: "🛩️", color: .orange) { game.screen = .planes }
                BigKidButton(title: "How to Fly", emoji: "❓", color: .purple) { game.screen = .help }
            }
            Spacer()
            HStack {
                Toggle(isOn: $game.soundOn) { Text("🔊 Sound").font(.title2.bold()) }
                    .toggleStyle(.switch).padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                Text("v1.0 • Offline • No ads • Kid-safe").foregroundColor(.white).font(.headline)
            }.padding(.bottom, 20)
        }
        .padding()
    }
}

struct HelpView: View {
    @EnvironmentObject var game: GameState
    var body: some View {
        VStack(spacing: 16) {
            Text("How to Fly 🧸").font(.system(size: 48, weight: .black, design: .rounded)).foregroundColor(.white)
            VStack(alignment: .leading, spacing: 14) {
                HelpRow(emoji: "🖱️", text: "Move the MOUSE to steer — left / right to turn, up / down to go up & down!")
                HelpRow(emoji: "⚡", text: "Hold SHIFT (or hold the mouse button) to BOOST super fast with a rainbow trail!")
                HelpRow(emoji: "⭐", text: "Fly into shiny STARS to collect them. Get 10 for a big HURRAY!")
                HelpRow(emoji: "🟠", text: "Fly through ORANGE RINGS for bonus cheers!")
                HelpRow(emoji: "😊", text: "You can't crash! The plane just bounces and giggles.")
                HelpRow(emoji: "🔙", text: "Press ESC anytime to come back to the menu.")
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 40)
            BigKidButton(title: "Back", emoji: "🔙", color: .blue) { game.screen = .menu }
            Spacer()
        }.padding(.top, 30)
    }
}

struct HelpRow: View {
    let emoji: String; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 32))
            Text(text).font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundColor(.primary)
        }
    }
}
