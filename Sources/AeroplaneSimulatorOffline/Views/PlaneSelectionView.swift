import SwiftUI

struct PlaneSelectionView: View {
    @EnvironmentObject var game: GameState
    let columns = [GridItem(.adaptive(minimum: 260), spacing: 20)]

    var body: some View {
        VStack {
            Text("Pick Your Plane! 🛩️")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(.white).padding(.top, 24)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(KidPlane.all) { plane in
                        PlaneCard(plane: plane, isSelected: plane.id == game.selectedPlane.id) {
                            game.selectedPlane = plane
                            SoundManager.shared.click()
                            SoundManager.shared.speak("\(plane.name)! Yay!")
                        }
                    }
                }.padding(24)
            }
            HStack(spacing: 20) {
                BigKidButton(title: "Back", emoji: "🔙", color: .gray) { game.screen = .menu }
                BigKidButton(title: "FLY THIS ONE!", emoji: "🚀", color: .green) {
                    game.startFlying(with: game.selectedPlane)
                }
            }.padding(.bottom, 24)
        }
    }
}

struct PlaneCard: View {
    let plane: KidPlane
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(plane.emoji).font(.system(size: 72))
                Text(plane.name).font(.system(size: 24, weight: .black, design: .rounded))
                Text(plane.tagline).font(.headline).multilineTextAlignment(.center).opacity(0.8)
                HStack {
                    Label("Fast", systemImage: "gauge.high")
                    SpeedDots(level: speedLevel)
                }.font(.subheadline.bold())
                if isSelected {
                    Text("✅ YOUR PLANE!").font(.headline.bold()).foregroundColor(.green)
                }
            }
            .foregroundColor(.primary)
            .padding(20)
            .frame(minHeight: 250)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(isSelected ? Color.green : Color.clear, lineWidth: 5))
            .shadow(radius: isSelected ? 12 : 4)
        }.buttonStyle(.plain)
    }
    var speedLevel: Int {
        if plane.topSpeed > 40 { return 3 } else if plane.topSpeed > 25 { return 2 } else { return 1 }
    }
}

struct SpeedDots: View {
    let level: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(i < level ? Color.orange : Color.gray.opacity(0.3)).frame(width: 12, height: 12)
            }
        }
    }
}
