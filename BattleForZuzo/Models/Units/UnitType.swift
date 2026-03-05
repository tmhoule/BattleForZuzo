import Foundation
import SpriteKit

enum TerrainAccess: String, Codable, Sendable {
    case land
    case water
    case any
}

enum UnitType: String, CaseIterable, Codable, Sendable {
    case submarine
    case tank
    case carrier
    case artillery
    case airplane
    case construction

    var displayName: String {
        switch self {
        case .submarine: return "Submarine"
        case .tank: return "Tank"
        case .carrier: return "Carrier"
        case .artillery: return "Artillery"
        case .airplane: return "Airplane"
        case .construction: return "Construction"
        }
    }

    var maxHP: Int {
        switch self {
        case .submarine: return 3
        case .tank: return 6
        case .carrier: return 3
        case .artillery: return 2
        case .airplane: return 2
        case .construction: return 2
        }
    }

    var movement: Int {
        switch self {
        case .submarine: return 4
        case .tank: return 2
        case .carrier: return 3
        case .artillery: return 1
        case .airplane: return 5
        case .construction: return 4
        }
    }

    var damage: Int {
        switch self {
        case .submarine: return 4
        case .tank: return 3
        case .carrier: return 0
        case .artillery: return 5
        case .airplane: return 1
        case .construction: return 0
        }
    }

    var visibility: Int {
        switch self {
        case .submarine: return 4
        case .tank: return 2
        case .carrier: return 3
        case .artillery: return 2
        case .airplane: return 4
        case .construction: return 3
        }
    }

    var terrainAccess: TerrainAccess {
        switch self {
        case .submarine: return .water
        case .tank: return .land
        case .carrier: return .water
        case .artillery: return .land
        case .airplane: return .any
        case .construction: return .land
        }
    }

    var productionCost: Int {
        switch self {
        case .submarine: return 4
        case .tank: return 3
        case .carrier: return 3
        case .artillery: return 4
        case .airplane: return 4
        case .construction: return 3
        }
    }

    var attackRange: Int {
        switch self {
        case .artillery: return 3
        case .tank: return 2
        default: return 1
        }
    }

    var canAttack: Bool {
        damage > 0
    }

    var canCarryUnits: Bool {
        self == .carrier
    }

    var carrierCapacity: Int {
        self == .carrier ? 2 : 0
    }

    /// Shape/symbol for placeholder rendering
    var symbol: String {
        switch self {
        case .submarine: return "S"
        case .tank: return "T"
        case .carrier: return "C"
        case .artillery: return "A"
        case .airplane: return "P"
        case .construction: return "R"
        }
    }

    var iconColor: SKColor {
        switch self {
        case .submarine: return .systemTeal
        case .tank: return .systemBrown
        case .carrier: return .systemGray
        case .artillery: return .systemOrange
        case .airplane: return .white
        case .construction: return .systemYellow
        }
    }
}
