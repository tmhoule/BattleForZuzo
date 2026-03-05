import Foundation

class MovementSystem {
    unowned let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    /// Calculate all hexes reachable by a unit with remaining movement
    func reachableHexes(for unit: Unit) -> Set<HexCoord> {
        guard let map = gameState.map, unit.canMove else { return [] }

        var reachable = Set<HexCoord>()
        var visited: [HexCoord: Double] = [unit.position: 0]
        var queue = PriorityQueue<(coord: HexCoord, cost: Double)>(sort: { $0.cost < $1.cost })
        queue.enqueue((coord: unit.position, cost: 0))

        while let current = queue.dequeue() {
            let neighbors = map.neighbors(of: current.coord)
            for neighbor in neighbors {
                guard let tile = map.tile(at: neighbor) else { continue }
                // Roads bypass terrain restrictions
                guard tile.hasRoad || unit.canTraverse(terrain: tile.terrain) else { continue }

                // Can't move through enemy units
                if let occupant = gameState.unit(at: neighbor), occupant.ownerID != unit.ownerID {
                    continue
                }

                // Can't stack friendly non-carrier units
                if let occupant = gameState.unit(at: neighbor), occupant.ownerID == unit.ownerID {
                    if !occupant.type.canCarryUnits || unit.type.terrainAccess != .land {
                        if occupant.id != unit.id {
                            continue
                        }
                    }
                }

                let tileCost = (tile.hasRoad && unit.type != .airplane) ? 0.25 : unit.movementCost(for: tile.terrain)
                let moveCost = current.cost + tileCost
                if moveCost <= unit.movementRemaining {
                    if visited[neighbor] == nil || visited[neighbor]! > moveCost {
                        visited[neighbor] = moveCost
                        reachable.insert(neighbor)
                        queue.enqueue((coord: neighbor, cost: moveCost))
                    }
                }
            }
        }

        reachable.remove(unit.position)
        return reachable
    }

    /// Calculate hexes where enemies can be attacked (supports ranged units)
    func attackableHexes(for unit: Unit) -> Set<HexCoord> {
        guard let map = gameState.map, unit.canAttack else { return [] }

        let range = unit.type.attackRange
        var attackable = Set<HexCoord>()

        // BFS to find all hexes within attack range
        var visited = Set<HexCoord>([unit.position])
        var frontier = [unit.position]
        for _ in 0..<range {
            var nextFrontier: [HexCoord] = []
            for coord in frontier {
                for neighbor in map.neighbors(of: coord) {
                    guard !visited.contains(neighbor) else { continue }
                    visited.insert(neighbor)
                    nextFrontier.append(neighbor)
                    if let target = gameState.unit(at: neighbor), target.ownerID != unit.ownerID {
                        attackable.insert(neighbor)
                    }
                }
            }
            frontier = nextFrontier
        }
        return attackable
    }

    /// Move a unit to destination, spending movement points
    func moveUnit(_ unit: Unit, to destination: HexCoord) -> Bool {
        guard let map = gameState.map else { return false }
        let reachable = reachableHexes(for: unit)
        guard reachable.contains(destination) else { return false }

        // Calculate path and cost
        let path = findPath(from: unit.position, to: destination, for: unit, on: map)
        guard !path.isEmpty else { return false }

        let cost = pathCost(path, for: unit, on: map)
        unit.movementRemaining = max(0.0, unit.movementRemaining - cost)
        unit.position = destination

        // Auto-load onto carrier if a friendly carrier is at the destination
        if unit.type.terrainAccess == .land {
            if let carrier = gameState.units.first(where: {
                $0.position == destination && $0.type.canCarryUnits &&
                $0.ownerID == unit.ownerID && $0.id != unit.id && $0.isAlive
            }), unit.canLoadOnto(carrier) {
                carrier.carriedUnits.append(unit)
                unit.isLoaded = true
                unit.movementRemaining = 0
            }
        }

        return true
    }

    /// A* pathfinding
    func findPath(from start: HexCoord, to end: HexCoord, for unit: Unit, on map: GameMap) -> [HexCoord] {
        var openSet = PriorityQueue<PathNode>(sort: { $0.fScore < $1.fScore })
        var cameFrom: [HexCoord: HexCoord] = [:]
        var gScore: [HexCoord: Double] = [start: 0]

        let topology = map.topology
        openSet.enqueue(PathNode(coord: start, fScore: Double(topology.distance(from: start, to: end))))

        while let current = openSet.dequeue() {
            if current.coord == end {
                return reconstructPath(cameFrom: cameFrom, current: end)
            }

            for neighbor in map.neighbors(of: current.coord) {
                guard let tile = map.tile(at: neighbor) else { continue }
                guard tile.hasRoad || unit.canTraverse(terrain: tile.terrain) else { continue }

                // Skip enemy occupied hexes (except destination for attack)
                if neighbor != end {
                    if let occupant = gameState.unit(at: neighbor), occupant.ownerID != unit.ownerID {
                        continue
                    }
                }

                let roadCost = (tile.hasRoad && unit.type != .airplane) ? 0.25 : unit.movementCost(for: tile.terrain)
                let tentativeG = (gScore[current.coord] ?? .infinity) + roadCost
                if tentativeG < (gScore[neighbor] ?? .infinity) {
                    cameFrom[neighbor] = current.coord
                    gScore[neighbor] = tentativeG
                    let fScore = tentativeG + Double(topology.distance(from: neighbor, to: end))
                    openSet.enqueue(PathNode(coord: neighbor, fScore: fScore))
                }
            }
        }

        return []  // No path found
    }

    private func reconstructPath(cameFrom: [HexCoord: HexCoord], current: HexCoord) -> [HexCoord] {
        var path: [HexCoord] = [current]
        var node = current
        while let prev = cameFrom[node] {
            path.append(prev)
            node = prev
        }
        return path.reversed()
    }

    private func pathCost(_ path: [HexCoord], for unit: Unit, on map: GameMap) -> Double {
        var cost: Double = 0
        for i in 1..<path.count {
            if let tile = map.tile(at: path[i]) {
                cost += (tile.hasRoad && unit.type != .airplane) ? 0.25 : unit.movementCost(for: tile.terrain)
            }
        }
        return cost
    }
}

private struct PathNode {
    let coord: HexCoord
    let fScore: Double
}
