import Foundation
import SpriteKit

enum Terrain: String, CaseIterable, Codable, Sendable {
    case deepWater
    case water
    case marsh
    case flatLand
    case forest
    case mountain
    case city  // not a real terrain, used for rendering

    var displayName: String {
        switch self {
        case .deepWater: return "Deep Water"
        case .water: return "Water"
        case .marsh: return "Marsh"
        case .flatLand: return "Plains"
        case .forest: return "Forest"
        case .mountain: return "Mountain"
        case .city: return "City"
        }
    }

    var movementCost: Int {
        switch self {
        case .deepWater: return 1
        case .water: return 1
        case .marsh: return 2
        case .flatLand: return 1
        case .forest: return 2
        case .mountain: return 99  // impassable for most
        case .city: return 1
        }
    }

    var isWater: Bool {
        self == .deepWater || self == .water
    }

    var isLand: Bool {
        !isWater
    }

    var color: SKColor {
        switch self {
        case .deepWater: return SKColor(red: 0.06, green: 0.12, blue: 0.35, alpha: 1)
        case .water: return SKColor(red: 0.15, green: 0.35, blue: 0.65, alpha: 1)
        case .marsh: return SKColor(red: 0.35, green: 0.45, blue: 0.25, alpha: 1)
        case .flatLand: return SKColor(red: 0.45, green: 0.65, blue: 0.25, alpha: 1)
        case .forest: return SKColor(red: 0.13, green: 0.42, blue: 0.15, alpha: 1)
        case .mountain: return SKColor(red: 0.55, green: 0.52, blue: 0.48, alpha: 1)
        case .city: return SKColor(red: 0.75, green: 0.65, blue: 0.45, alpha: 1)
        }
    }

    var colorLight: SKColor {
        switch self {
        case .deepWater: return SKColor(red: 0.10, green: 0.18, blue: 0.42, alpha: 1)
        case .water: return SKColor(red: 0.22, green: 0.45, blue: 0.75, alpha: 1)
        case .marsh: return SKColor(red: 0.42, green: 0.55, blue: 0.30, alpha: 1)
        case .flatLand: return SKColor(red: 0.55, green: 0.75, blue: 0.32, alpha: 1)
        case .forest: return SKColor(red: 0.18, green: 0.52, blue: 0.20, alpha: 1)
        case .mountain: return SKColor(red: 0.65, green: 0.62, blue: 0.58, alpha: 1)
        case .city: return SKColor(red: 0.82, green: 0.72, blue: 0.52, alpha: 1)
        }
    }

    var defenseBonus: Double {
        switch self {
        case .deepWater, .water: return 0
        case .marsh: return 0
        case .flatLand: return 0
        case .forest: return 1
        case .mountain: return 2
        case .city: return 2
        }
    }
}
