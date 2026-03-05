import Foundation
import CoreGraphics
import SpriteKit

enum Constants {
    // MARK: - Hex
    static let hexSize: CGFloat = 32
    static let hexLayout = HexLayout(size: hexSize)

    // MARK: - Map Sizes
    enum MapSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        var dimensions: (width: Int, height: Int) {
            switch self {
            case .small: return (26, 26)
            case .medium: return (44, 44)
            case .large: return (70, 70)
            }
        }

        var cityCount: ClosedRange<Int> {
            switch self {
            case .small: return 16...24
            case .medium: return 30...50
            case .large: return 60...90
            }
        }
    }

    // MARK: - Map Types
    enum MapType: String, CaseIterable {
        case continents = "Continents"
        case islands = "Islands"
        case mixed = "Mixed"
    }

    // MARK: - Terrain Thresholds
    static let deepWaterThreshold: Double = -0.3
    static let waterThreshold: Double = -0.1
    static let marshThreshold: Double = 0.05
    static let flatLandThreshold: Double = 0.35
    static let forestThreshold: Double = 0.5
    // Above forest = mountain

    // MARK: - City
    static let minCityDistance: Int = 3
    static let cityVisibilityRange: Int = 1

    // MARK: - Camera
    static let minZoom: CGFloat = 0.3
    static let maxZoom: CGFloat = 3.0
    static let defaultZoom: CGFloat = 1.0
    static let panSpeed: CGFloat = 1.0

    // MARK: - Colors
    static let playerColors: [SKColor] = [
        SKColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1),    // Blue (human)
        SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1),    // Red
        SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1),    // Green
        SKColor(red: 0.9, green: 0.8, blue: 0.1, alpha: 1),    // Yellow
    ]

    // MARK: - Z Positions
    static let zTerrain: CGFloat = 0
    static let zCity: CGFloat = 10
    static let zUnit: CGFloat = 20
    static let zHighlight: CGFloat = 5
    static let zFog: CGFloat = 50
    static let zUI: CGFloat = 100

    // MARK: - Animation
    static let moveAnimationDuration: TimeInterval = 0.3
    static let attackAnimationDuration: TimeInterval = 0.2
    static let aiMoveDelay: TimeInterval = 0.4

    // MARK: - Production
    static let defaultProductionCost: Int = 3
}
