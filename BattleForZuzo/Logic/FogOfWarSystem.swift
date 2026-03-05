import Foundation

enum FogState {
    case unexplored  // Black - never seen
    case explored    // Grey - seen before but no current visibility
    case visible     // Clear - currently visible
}

class FogOfWarSystem {
    unowned let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    /// Get current visibility set for a player
    func visibleHexes(for player: Player) -> Set<HexCoord> {
        guard let map = gameState.map else { return [] }

        var visible = Set<HexCoord>()

        // Units provide visibility
        let playerUnits = gameState.units(for: player.id)
        for unit in playerUnits {
            let range = unit.type.visibility
            let hexesInRange = unit.position.hexesInRange(radius: range)
            for hex in hexesInRange {
                let normalized = map.normalize(hex)
                if map.isValid(normalized) {
                    visible.insert(normalized)
                }
            }
        }

        // Cities provide visibility (hex + 1 ring)
        let playerCities = map.citiesForPlayer(player.id)
        for city in playerCities {
            let hexesInRange = city.position.hexesInRange(radius: Constants.cityVisibilityRange)
            for hex in hexesInRange {
                let normalized = map.normalize(hex)
                if map.isValid(normalized) {
                    visible.insert(normalized)
                }
            }
        }

        return visible
    }

    /// Update explored tiles for a player based on current visibility
    func updateVisibility(for player: Player) {
        let visible = visibleHexes(for: player)
        player.exploredTiles.formUnion(visible)
    }

    /// Get fog state for a specific hex for a player
    func fogState(at coord: HexCoord, for player: Player) -> FogState {
        let visible = visibleHexes(for: player)
        if visible.contains(coord) {
            return .visible
        } else if player.exploredTiles.contains(coord) {
            return .explored
        } else {
            return .unexplored
        }
    }

    /// Hexes within 2 of any friendly unit (for submarine detection)
    func submarineDetectionHexes(for player: Player) -> Set<HexCoord> {
        guard let map = gameState.map else { return [] }
        var detectable = Set<HexCoord>()
        let playerUnits = gameState.units(for: player.id)
        for unit in playerUnits {
            let hexesInRange = unit.position.hexesInRange(radius: 2)
            for hex in hexesInRange {
                let normalized = map.normalize(hex)
                if map.isValid(normalized) {
                    detectable.insert(normalized)
                }
            }
        }
        return detectable
    }

    /// Check if a unit is visible to a player
    func isUnitVisible(_ unit: Unit, to player: Player) -> Bool {
        guard unit.ownerID != player.id else { return true }
        // Enemy submarines require a friendly unit within 2 hexes
        if unit.type == .submarine {
            let detection = submarineDetectionHexes(for: player)
            return detection.contains(unit.position)
        }
        let visible = visibleHexes(for: player)
        return visible.contains(unit.position)
    }
}
