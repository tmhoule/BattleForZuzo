import SwiftUI

struct CityInfoPanel: View {
    let city: City
    let isOwned: Bool
    var onSetProduction: ((UnitType) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // City name
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.yellow)
                Text(city.name)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                if city.isCoastal {
                    Image(systemName: "water.waves")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
            }

            if city.isNeutral {
                Text("Neutral City")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }

            if isOwned {
                Divider().background(Color.gray)

                // Current production
                if let producing = city.productionQueue {
                    HStack {
                        Text("Building: \(producing.displayName)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(city.productionProgress)/\(producing.productionCost)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                } else {
                    Text("No production")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }

                // Production options
                VStack(spacing: 4) {
                    ForEach(city.availableProductions, id: \.self) { unitType in
                        Button(action: {
                            onSetProduction?(unitType)
                        }) {
                            HStack {
                                Text(unitType.symbol)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                Text(unitType.displayName)
                                    .font(.system(size: 11, design: .monospaced))
                                Spacer()
                                Text("\(unitType.productionCost) turns")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                            }
                            .foregroundColor(city.productionQueue == unitType ? .orange : .white)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(city.productionQueue == unitType ?
                                          Color.orange.opacity(0.2) : Color.clear)
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
