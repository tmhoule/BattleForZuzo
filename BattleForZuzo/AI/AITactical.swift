import Foundation

class AITactical {
    unowned let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    func decidAction(for unit: Unit, mode: AIMode, player: Player) -> AIAction {
        guard let map = gameState.map else { return .hold }

        // Construction units: build roads or move toward useful locations
        if unit.type == .construction {
            return constructionAction(for: unit, map: map, player: player)
        }

        // Check for attackable enemies within range
        let attackableEnemies = findEnemiesInRange(of: unit, map: map, player: player)

        if unit.canAttack, let bestTarget = attackableEnemies.min(by: { $0.hp < $1.hp }) {
            return .attack(bestTarget.id)
        }

        // Get reachable hexes
        let reachable = gameState.movementSystem?.reachableHexes(for: unit) ?? []
        guard !reachable.isEmpty else { return .hold }

        switch mode {
        case .expand:
            return expandAction(for: unit, reachable: reachable, map: map, player: player)
        case .attack:
            return attackAction(for: unit, reachable: reachable, map: map, player: player)
        case .defend:
            return defendAction(for: unit, reachable: reachable, map: map, player: player)
        }
    }

    private func expandAction(for unit: Unit, reachable: Set<HexCoord>, map: GameMap, player: Player) -> AIAction {
        // Find nearest neutral city
        let neutralCities = map.cities.values.filter { $0.isNeutral }
        let topo = map.topology
        guard let nearestCity = neutralCities.min(by: {
            topo.distance(from: unit.position, to: $0.position) < topo.distance(from: unit.position, to: $1.position)
        }) else {
            return attackAction(for: unit, reachable: reachable, map: map, player: player)
        }

        // Move toward it
        return moveToward(unit: unit, target: nearestCity.position, reachable: reachable, map: map)
    }

    private func attackAction(for unit: Unit, reachable: Set<HexCoord>, map: GameMap, player: Player) -> AIAction {
        // Find nearest enemy unit or city
        let enemies = gameState.units.filter { $0.ownerID != player.id && $0.isAlive }
        let enemyCities = map.cities.values.filter { $0.ownerID != nil && $0.ownerID != player.id }
        let topo = map.topology

        // Check if we can move to attack an enemy this turn
        let attackRange = unit.type.attackRange
        for hex in reachable {
            // Find enemies within attack range from this hex
            var visited = Set<HexCoord>([hex])
            var frontier = [hex]
            for _ in 0..<attackRange {
                var nextFrontier: [HexCoord] = []
                for coord in frontier {
                    for neighbor in map.neighbors(of: coord) {
                        guard !visited.contains(neighbor) else { continue }
                        visited.insert(neighbor)
                        nextFrontier.append(neighbor)
                        if let enemy = gameState.unit(at: neighbor), enemy.ownerID != player.id, unit.canAttack {
                            return .moveAndAttack(hex, enemy.id)
                        }
                    }
                }
                frontier = nextFrontier
            }
        }

        // Move toward nearest enemy
        if let nearestEnemy = enemies.min(by: {
            topo.distance(from: unit.position, to: $0.position) < topo.distance(from: unit.position, to: $1.position)
        }) {
            return moveToward(unit: unit, target: nearestEnemy.position, reachable: reachable, map: map)
        }

        // Move toward nearest enemy city
        if let nearestCity = enemyCities.min(by: {
            topo.distance(from: unit.position, to: $0.position) < topo.distance(from: unit.position, to: $1.position)
        }) {
            return moveToward(unit: unit, target: nearestCity.position, reachable: reachable, map: map)
        }

        return .hold
    }

    private func defendAction(for unit: Unit, reachable: Set<HexCoord>, map: GameMap, player: Player) -> AIAction {
        // Find our most threatened city
        let ownCities = map.citiesForPlayer(player.id)
        let topo = map.topology
        let threatenedCity = ownCities.min(by: { city1, city2 in
            let threats1 = gameState.units.filter {
                $0.ownerID != player.id && $0.isAlive &&
                topo.distance(from: $0.position, to: city1.position) <= 3
            }.count
            let threats2 = gameState.units.filter {
                $0.ownerID != player.id && $0.isAlive &&
                topo.distance(from: $0.position, to: city2.position) <= 3
            }.count
            return threats1 > threats2
        })

        if let city = threatenedCity {
            // If we're already adjacent to city, try to attack nearby enemies
            if topo.distance(from: unit.position, to: city.position) <= 2 {
                return attackAction(for: unit, reachable: reachable, map: map, player: player)
            }
            return moveToward(unit: unit, target: city.position, reachable: reachable, map: map)
        }

        return .hold
    }

    private func findEnemiesInRange(of unit: Unit, map: GameMap, player: Player) -> [Unit] {
        let range = unit.type.attackRange
        var visited = Set<HexCoord>([unit.position])
        var frontier = [unit.position]
        var enemies: [Unit] = []

        for _ in 0..<range {
            var nextFrontier: [HexCoord] = []
            for coord in frontier {
                for neighbor in map.neighbors(of: coord) {
                    guard !visited.contains(neighbor) else { continue }
                    visited.insert(neighbor)
                    nextFrontier.append(neighbor)
                    if let target = gameState.unit(at: neighbor), target.ownerID != player.id {
                        enemies.append(target)
                    }
                }
            }
            frontier = nextFrontier
        }
        return enemies
    }

    private func constructionAction(for unit: Unit, map: GameMap, player: Player) -> AIAction {
        // If current tile is land with no road, build one
        if let tile = map.tile(at: unit.position), tile.terrain.isLand, !tile.hasRoad, unit.canBuildRoad {
            return .buildRoad
        }

        // Otherwise move toward a hex between owned cities that lacks a road
        let reachable = gameState.movementSystem?.reachableHexes(for: unit) ?? []
        guard !reachable.isEmpty else { return .hold }

        let ownCities = map.citiesForPlayer(player.id)
        let topo = map.topology

        // Find a land hex without a road that's near our cities
        var bestTarget: HexCoord?
        var bestDist = Int.max
        for city in ownCities {
            for neighbor in map.neighbors(of: city.position) {
                if let tile = map.tile(at: neighbor), tile.terrain.isLand, !tile.hasRoad {
                    let dist = topo.distance(from: unit.position, to: neighbor)
                    if dist < bestDist {
                        bestDist = dist
                        bestTarget = neighbor
                    }
                }
            }
        }

        if let target = bestTarget {
            return moveToward(unit: unit, target: target, reachable: reachable, map: map)
        }

        return .hold
    }

    private func moveToward(unit: Unit, target: HexCoord, reachable: Set<HexCoord>, map: GameMap) -> AIAction {
        let topo = map.topology
        // Find reachable hex closest to target
        guard let best = reachable.min(by: {
            topo.distance(from: $0, to: target) < topo.distance(from: $1, to: target)
        }) else {
            return .hold
        }

        // Only move if it gets us closer
        if topo.distance(from: best, to: target) < topo.distance(from: unit.position, to: target) {
            return .move(best)
        }

        return .hold
    }
}
