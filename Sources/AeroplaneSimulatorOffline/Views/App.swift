import SwiftUI

@main
struct AeroplaneSimulatorOfflineApp: App {
    @StateObject private var game = GameState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .frame(minWidth: 1000, minHeight: 700)
                .onAppear {
                    SoundManager.shared.enabled = game.soundOn
                }
                .onChange(of: game.soundOn) { SoundManager.shared.enabled = $0 }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        ZStack {
            LinearGradient(colors: [.skyTop, .skyBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            switch game.screen {
            case .menu: MainMenuView()
            case .planes: PlaneSelectionView()
            case .fly: FlyView()
            case .help: HelpView()
            }
        }
        .onAppear {
            // Dev launch args (screenshots, smoke tests): e.g.
            //   open ... --args --fly --plane jumbo-jet
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "--plane"), i + 1 < args.count,
               let p = KidPlane.all.first(where: { $0.id == args[i + 1] }) {
                game.selectedPlane = p
            }
            if args.contains("--fly") { game.screen = .fly }
        }
    }
}

extension Color {
    static let skyTop = Color(red: 0.35, green: 0.7, blue: 1.0)
    static let skyBottom = Color(red: 0.85, green: 0.95, blue: 1.0)
    static let kidYellow = Color(red: 1.0, green: 0.82, blue: 0.25)
    static let kidPink = Color(red: 1.0, green: 0.55, blue: 0.65)
    static let kidGreen = Color(red: 0.35, green: 0.8, blue: 0.45)
}

struct BigKidButton: View {
    let title: String
    let emoji: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: { SoundManager.shared.click(); action() }) {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 34))
                Text(title).font(.system(size: 26, weight: .heavy, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 36).padding(.vertical, 18)
            .background(color, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: color.opacity(0.5), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}
