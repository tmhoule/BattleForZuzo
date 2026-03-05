import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Controls") {
                        bulletPoint("Tap a unit to select it")
                        bulletPoint("Tap a blue hex to move")
                        bulletPoint("Tap a red hex to attack")
                        bulletPoint("Tap a city to see info / set production")
                        bulletPoint("Long-press a hex for terrain info")
                        bulletPoint("Pinch to zoom, drag to pan")
                        bulletPoint("Map wraps east-west (cylindrical)")
                    }

                    section("Unit Types") {
                        unitRow(symbol: "T", name: "Tank", stats: "HP 6 | ATK 3 | MOV 2 | Land only")
                        unitRow(symbol: "A", name: "Artillery", stats: "HP 3 | ATK 5 | MOV 1 | Range 3 | Land")
                        unitRow(symbol: "P", name: "Airplane", stats: "HP 2 | ATK 2 | MOV 5 | Any terrain")
                        unitRow(symbol: "S", name: "Submarine", stats: "HP 3 | ATK 4 | MOV 4 | Water only")
                        unitRow(symbol: "C", name: "Carrier", stats: "HP 3 | ATK 0 | MOV 3 | Water, carries 2 land units")
                        unitRow(symbol: "R", name: "Construction", stats: "HP 2 | ATK 0 | MOV 4 | Builds roads | All but deep water")
                    }

                    section("Terrain") {
                        terrainRow("Plains", cost: 1, defense: 0)
                        terrainRow("Forest", cost: 2, defense: 1)
                        terrainRow("Marsh", cost: 2, defense: 0)
                        terrainRow("Mountain", cost: "Impassable", defense: 2)
                        terrainRow("Water/Deep Water", cost: 1, defense: 0)
                        terrainRow("City", cost: 1, defense: 2)
                        bulletPoint("Roads reduce movement cost to 1")
                    }

                    section("Combat") {
                        bulletPoint("Attacker deals full damage minus terrain defense")
                        bulletPoint("Defender counter-attacks at half damage (melee only)")
                        bulletPoint("Artillery attacks at range 2-3, no counter-attack")
                        bulletPoint("Minimum damage is always 1")
                        bulletPoint("Units on friendly cities heal 1 HP per turn")
                    }

                    section("Victory") {
                        bulletPoint("Capture all cities to win")
                        bulletPoint("A player with no cities and no units is eliminated")
                        bulletPoint("Last player standing wins")
                    }
                }
                .padding()
            }
            .background(Color(red: 0.05, green: 0.08, blue: 0.15))
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
                .tracking(2)
            content()
        }
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("*")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private func unitRow(symbol: String, name: String, stats: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.4))
                    .frame(width: 28, height: 28)
                Text(symbol)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(stats)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }

    private func terrainRow(_ name: String, cost: Any, defense: Int) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 130, alignment: .leading)
            Text("Move: \(cost)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
            Text("Def: +\(defense)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.cyan)
        }
    }
}
