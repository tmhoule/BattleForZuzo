import SwiftUI

struct UnitInfoPanel: View {
    let unit: Unit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Unit name and type
            HStack {
                Text(unit.type.symbol)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(unit.type.iconColor))

                VStack(alignment: .leading, spacing: 2) {
                    Text(unit.type.displayName)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Text("HP: \(unit.hp)/\(unit.type.maxHP)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(hpColor)
                }
            }

            Divider().background(Color.gray)

            // Stats
            HStack(spacing: 16) {
                StatItem(icon: "arrow.up.and.down", label: "Move", value: "\(unit.movementRemaining.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(unit.movementRemaining))" : String(format: "%.1f", unit.movementRemaining))/\(unit.type.movement)")
                StatItem(icon: "bolt.fill", label: "ATK", value: "\(unit.type.damage)")
                StatItem(icon: "eye.fill", label: "VIS", value: "\(unit.type.visibility)")
            }
        }
        .padding(12)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var hpColor: Color {
        let ratio = Double(unit.hp) / Double(unit.type.maxHP)
        if ratio > 0.5 { return .green }
        if ratio > 0.25 { return .yellow }
        return .red
    }
}

struct StatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.gray)
        }
    }
}
