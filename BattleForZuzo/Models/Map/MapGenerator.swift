import Foundation
import GameplayKit

class MapGenerator {
    let mapSize: Constants.MapSize
    let mapType: Constants.MapType
    private var rng: GKRandomSource

    init(mapSize: Constants.MapSize, mapType: Constants.MapType, seed: UInt64? = nil) {
        self.mapSize = mapSize
        self.mapType = mapType
        if let seed = seed {
            self.rng = GKMersenneTwisterRandomSource(seed: seed)
        } else {
            self.rng = GKMersenneTwisterRandomSource()
        }
    }

    func generate() -> GameMap {
        let (w, h) = mapSize.dimensions
        let map = GameMap(width: w, height: h)

        // Generate elevation using Perlin noise
        let elevationMap = generateElevation(width: w, height: h)

        // Assign terrain based on elevation
        for col in 0..<w {
            for row in 0..<h {
                let coord = HexLayout.offsetToAxial(col: col, row: row)
                let elevation = elevationMap[col][row]
                let terrain = terrainForElevation(elevation)
                var tile = Tile(terrain: terrain, elevation: elevation)
                // Mark water adjacency
                tile.isAdjacentToWater = false
                map.tiles[coord] = tile
            }
        }

        // Smooth terrain clusters — similar terrain groups together
        smoothTerrain(on: map, width: w, height: h, iterations: 4)

        // Enforce minimum water group sizes
        enforceMinimumWaterGroups(on: map)

        // Remove inland water: continents get one solid landmass, islands get clean shorelines
        if mapType == .continents || mapType == .islands {
            removeInlandWater(on: map)
        }

        // Update water adjacency
        for coord in map.allCoords {
            if var tile = map.tiles[coord], tile.terrain.isLand {
                tile.isAdjacentToWater = map.isWaterAdjacent(coord)
                map.tiles[coord] = tile
            }
        }

        // Place cities
        placeCities(on: map)

        return map
    }

    // MARK: - Elevation Generation

    private func generateElevation(width: Int, height: Int) -> [[Double]] {
        let noiseSource = GKPerlinNoiseSource(
            frequency: noiseFrequency,
            octaveCount: 3,
            persistence: 0.3,
            lacunarity: 2.0,
            seed: Int32(rng.nextInt(upperBound: 100000))
        )
        let noise = GKNoise(noiseSource)

        // Sample noise
        let noiseMap = GKNoiseMap(
            noise,
            size: vector_double2(Double(width), Double(height)),
            origin: vector_double2(0, 0),
            sampleCount: vector_int2(Int32(width), Int32(height)),
            seamless: true  // horizontal tiling for cylindrical wrapping
        )

        var elevation = Array(repeating: Array(repeating: 0.0, count: height), count: width)
        for x in 0..<width {
            for y in 0..<height {
                elevation[x][y] = Double(noiseMap.value(at: vector_int2(Int32(x), Int32(y))))
            }
        }

        // Apply gradient based on map type
        applyGradient(to: &elevation, width: width, height: height)

        return elevation
    }

    private var noiseFrequency: Double {
        switch mapType {
        case .continents: return 0.8
        case .islands: return 2.0
        case .mixed: return 1.2
        }
    }

    private func applyGradient(to elevation: inout [[Double]], width: Int, height: Int) {
        let centerX = Double(width) / 2.0
        let centerY = Double(height) / 2.0

        for x in 0..<width {
            for y in 0..<height {
                let dx = (Double(x) - centerX) / centerX
                let dy = (Double(y) - centerY) / centerY
                let dist = sqrt(dx * dx + dy * dy)  // 0 at center, ~1.4 at corners

                switch mapType {
                case .continents:
                    // Strong radial gradient: high center dome, drops to ocean at edges
                    let gradient = max(0, 1.0 - dist * 1.1)
                    elevation[x][y] += gradient * 0.8 - 0.15

                case .islands:
                    // Lower overall to create more ocean between islands
                    elevation[x][y] -= 0.15
                    // Drop off at edges
                    if dist > 0.85 {
                        elevation[x][y] -= (dist - 0.85) * 2.0
                    }

                case .mixed:
                    let verticalDist = abs(Double(y) - centerY) / centerY
                    let gradient = 1.0 - verticalDist * 1.2
                    elevation[x][y] += gradient * 0.25
                }

                // Polar caps (skip for continents — they have radial ocean border)
                if mapType != .continents {
                    let polarRows = max(1, height / 15)
                    if y < polarRows || y >= height - polarRows {
                        elevation[x][y] = max(elevation[x][y], Constants.forestThreshold + 0.1)
                    } else if y < polarRows * 2 || y >= height - polarRows * 2 {
                        elevation[x][y] += 0.15
                    }
                }
            }
        }
    }

    private func terrainForElevation(_ elevation: Double) -> Terrain {
        if elevation < Constants.deepWaterThreshold {
            return .deepWater
        } else if elevation < Constants.waterThreshold {
            return .water
        } else if elevation < Constants.marshThreshold {
            return .marsh
        } else if elevation < Constants.flatLandThreshold {
            return .flatLand
        } else if elevation < Constants.forestThreshold {
            return .forest
        } else {
            return .mountain
        }
    }

    // MARK: - Terrain Smoothing

    /// Cellular automata smoothing: tiles adopt the most common neighbor terrain
    private func smoothTerrain(on map: GameMap, width: Int, height: Int, iterations: Int) {
        let landTerrains: [Terrain] = [.marsh, .flatLand, .forest, .mountain]

        for _ in 0..<iterations {
            var changes: [(HexCoord, Terrain)] = []

            for coord in map.allCoords {
                guard let tile = map.tiles[coord] else { continue }
                // Only smooth land terrains; don't change water/deep water
                guard landTerrains.contains(tile.terrain) else { continue }

                // Count neighbor terrain types
                let neighbors = map.neighbors(of: coord)
                var counts: [Terrain: Int] = [:]
                for neighbor in neighbors {
                    if let nTile = map.tiles[neighbor], landTerrains.contains(nTile.terrain) {
                        counts[nTile.terrain, default: 0] += 1
                    }
                }

                // If 3+ neighbors share a terrain and it differs from ours, adopt it
                if let (dominant, count) = counts.max(by: { $0.value < $1.value }),
                   count >= 3, dominant != tile.terrain {
                    changes.append((coord, dominant))
                }
            }

            // Apply changes after scanning all tiles
            for (coord, newTerrain) in changes {
                if var tile = map.tiles[coord] {
                    tile.terrain = newTerrain
                    tile.elevation = elevationForTerrain(newTerrain)
                    map.tiles[coord] = tile
                }
            }
        }
    }

    // MARK: - Water Group Enforcement

    /// Convert small isolated water groups to land terrain
    private func enforceMinimumWaterGroups(on map: GameMap) {
        let minDeepWater = 30
        let minShallowWater = 5

        // Find connected components for deep water
        let deepWaterGroups = findConnectedGroups(on: map, matching: { $0 == .deepWater })
        for group in deepWaterGroups where group.count < minDeepWater {
            // Convert small deep water groups to shallow water
            for coord in group {
                if var tile = map.tiles[coord] {
                    tile.terrain = .water
                    tile.elevation = elevationForTerrain(.water)
                    map.tiles[coord] = tile
                }
            }
        }

        // Find connected components for all water (shallow, including converted deep)
        let waterGroups = findConnectedGroups(on: map, matching: { $0 == .water })
        for group in waterGroups where group.count < minShallowWater {
            // Convert small water groups to the most common adjacent land terrain
            let replacement = dominantAdjacentLand(for: group, on: map)
            for coord in group {
                if var tile = map.tiles[coord] {
                    tile.terrain = replacement
                    tile.elevation = elevationForTerrain(replacement)
                    map.tiles[coord] = tile
                }
            }
        }
    }

    /// Remove water not connected to the map border (fills inland lakes and island holes)
    private func removeInlandWater(on map: GameMap) {
        var oceanWater = Set<HexCoord>()
        var queue: [HexCoord] = []

        // Seed with border water tiles
        for coord in map.allCoords {
            let offset = HexLayout.axialToOffset(q: coord.q, r: coord.r)
            let isBorder = offset.col == 0 || offset.col == map.width - 1 ||
                           offset.row == 0 || offset.row == map.height - 1
            if isBorder, let tile = map.tile(at: coord), tile.terrain.isWater {
                oceanWater.insert(coord)
                queue.append(coord)
            }
        }

        // BFS flood fill from border water to find all ocean-connected water
        while !queue.isEmpty {
            let current = queue.removeFirst()
            for neighbor in map.neighbors(of: current) {
                guard !oceanWater.contains(neighbor) else { continue }
                guard let tile = map.tile(at: neighbor), tile.terrain.isWater else { continue }
                oceanWater.insert(neighbor)
                queue.append(neighbor)
            }
        }

        // Convert non-ocean water to land
        for coord in map.allCoords {
            guard var tile = map.tiles[coord], tile.terrain.isWater else { continue }
            if !oceanWater.contains(coord) {
                let replacement = dominantAdjacentLand(for: [coord], on: map)
                tile.terrain = replacement
                tile.elevation = elevationForTerrain(replacement)
                map.tiles[coord] = tile
            }
        }
    }

    /// Flood-fill to find connected groups of tiles matching a terrain predicate
    private func findConnectedGroups(on map: GameMap, matching predicate: (Terrain) -> Bool) -> [Set<HexCoord>] {
        var visited = Set<HexCoord>()
        var groups: [Set<HexCoord>] = []

        for coord in map.allCoords {
            guard !visited.contains(coord) else { continue }
            guard let tile = map.tiles[coord], predicate(tile.terrain) else { continue }

            // BFS flood fill
            var group = Set<HexCoord>()
            var queue = [coord]
            visited.insert(coord)

            while !queue.isEmpty {
                let current = queue.removeFirst()
                group.insert(current)

                for neighbor in map.neighbors(of: current) {
                    guard !visited.contains(neighbor) else { continue }
                    guard let nTile = map.tiles[neighbor], predicate(nTile.terrain) else { continue }
                    visited.insert(neighbor)
                    queue.append(neighbor)
                }
            }

            groups.append(group)
        }

        return groups
    }

    /// Find the most common land terrain adjacent to a group of hexes
    private func dominantAdjacentLand(for group: Set<HexCoord>, on map: GameMap) -> Terrain {
        var counts: [Terrain: Int] = [:]
        for coord in group {
            for neighbor in map.neighbors(of: coord) {
                guard !group.contains(neighbor) else { continue }
                if let tile = map.tiles[neighbor], tile.terrain.isLand {
                    counts[tile.terrain, default: 0] += 1
                }
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? .flatLand
    }

    /// Approximate elevation for a given terrain (used during smoothing)
    private func elevationForTerrain(_ terrain: Terrain) -> Double {
        switch terrain {
        case .deepWater: return Constants.deepWaterThreshold - 0.1
        case .water: return Constants.waterThreshold - 0.05
        case .marsh: return Constants.marshThreshold - 0.02
        case .flatLand: return (Constants.marshThreshold + Constants.flatLandThreshold) / 2
        case .forest: return (Constants.flatLandThreshold + Constants.forestThreshold) / 2
        case .mountain: return Constants.forestThreshold + 0.1
        case .city: return Constants.marshThreshold + 0.1
        }
    }

    // MARK: - City Placement

    private func placeCities(on map: GameMap) {
        let cityRange = mapSize.cityCount
        var sysRng = SystemRandomNumberGenerator()
        let targetCount = Int.random(in: cityRange, using: &sysRng)
        var placedCities: [HexCoord] = []
        let cityNames = generateCityNames(count: targetCount + 10)
        var nameIndex = 0

        // Collect all valid land tiles
        var candidates = map.allCoords.filter { coord in
            guard let tile = map.tile(at: coord) else { return false }
            return tile.terrain.isLand && tile.terrain != .mountain
        }
        candidates.shuffle(using: &sysRng)

        // Poisson disk sampling: ensure minimum distance between cities
        for candidate in candidates {
            guard placedCities.count < targetCount else { break }
            let tooClose = placedCities.contains { placed in
                candidate.distance(to: placed) < Constants.minCityDistance
            }
            if !tooClose {
                let isCoastal = map.isWaterAdjacent(candidate)
                let city = City(
                    position: candidate,
                    name: cityNames[nameIndex],
                    isCoastal: isCoastal
                )
                nameIndex += 1

                map.cities[city.id] = city
                if var tile = map.tiles[candidate] {
                    tile.hasCity = true
                    tile.cityID = city.id
                    tile.hasRoad = true
                    map.tiles[candidate] = tile
                }
                placedCities.append(candidate)
            }
        }
    }

    private func generateCityNames(count: Int) -> [String] {
        let names = [
            "Zuzo", "Krath", "Velmar", "Thune", "Orvek",
            "Salden", "Mirax", "Dorne", "Pelgar", "Vexis",
            "Althen", "Brunos", "Caldor", "Drayen", "Elphis",
            "Ferox", "Gildren", "Helvos", "Ithren", "Juxmar",
            "Korven", "Lyndar", "Mortis", "Nexor", "Ophren",
            "Paldis", "Quorin", "Revax", "Sython", "Talvek",
            "Umbren", "Voldis", "Wyther", "Xandor", "Yelmis",
            "Zephyr", "Arkham", "Basken", "Cyrix", "Dulmar",
            "Enthos", "Falkren", "Grimvar", "Havren", "Ixmor",
            "Jethren", "Keldis", "Lormax", "Malvex", "Norish"
        ]
        return Array(names.prefix(count))
    }
}
