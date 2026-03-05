import Foundation

struct Tile: Sendable, Codable {
    var terrain: Terrain
    var elevation: Double
    var hasRoad: Bool = false
    var hasCity: Bool = false
    var cityID: UUID? = nil

    init(terrain: Terrain, elevation: Double = 0) {
        self.terrain = terrain
        self.elevation = elevation
    }

    var isPassableByLand: Bool {
        terrain.isLand && terrain != .mountain
    }

    var isPassableByWater: Bool {
        terrain.isWater
    }

    var isAdjacentToWater: Bool = false
}
