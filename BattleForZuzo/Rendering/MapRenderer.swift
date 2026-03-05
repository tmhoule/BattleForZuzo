import SpriteKit

class MapRenderer {
    let terrainLayer: SKNode
    let roadLayer: SKNode
    private let layout = Constants.hexLayout
    private var hexNodes: [HexCoord: SKSpriteNode] = [:]
    private var textureCache: [Terrain: SKTexture] = [:]
    private(set) var mapPixelWidth: CGFloat = 0
    private let ghostColumns = 8
    private var roadCoords: Set<HexCoord> = []

    init() {
        terrainLayer = SKNode()
        terrainLayer.zPosition = Constants.zTerrain
        roadLayer = SKNode()
        roadLayer.zPosition = Constants.zFog + 1  // Above fog so roads are visible on explored hexes
    }

    func renderMap(_ map: GameMap) {
        terrainLayer.removeAllChildren()
        hexNodes.removeAll()
        buildTextureCache()

        // Calculate map pixel width for wrapping
        let lastColCoord = HexLayout.offsetToAxial(col: map.width, row: 0)
        let firstColCoord = HexLayout.offsetToAxial(col: 0, row: 0)
        mapPixelWidth = layout.hexToPixel(lastColCoord).x - layout.hexToPixel(firstColCoord).x

        for coord in map.allCoords {
            guard let tile = map.tile(at: coord) else { continue }
            let position = layout.hexToPixel(coord)
            let texture = textureForTerrain(tile.terrain, at: coord)
            let sprite = SKSpriteNode(texture: texture)
            sprite.position = position
            sprite.zPosition = Constants.zTerrain
            sprite.setScale(1.08)
            sprite.name = "hex_\(coord.q)_\(coord.r)"
            terrainLayer.addChild(sprite)
            hexNodes[coord] = sprite
        }

        // Render ghost columns for seamless wrapping
        if map.topology.wrapping {
            renderGhostColumns(map)
        }
    }

    private func renderGhostColumns(_ map: GameMap) {
        let colsToGhost = min(ghostColumns, map.width)

        for row in 0..<map.height {
            // Right-side ghosts (copies of left edge columns, offset right by mapPixelWidth)
            for col in 0..<colsToGhost {
                let coord = HexLayout.offsetToAxial(col: col, row: row)
                guard let tile = map.tile(at: coord) else { continue }
                let texture = textureForTerrain(tile.terrain, at: coord)
                let sprite = SKSpriteNode(texture: texture)
                let basePos = layout.hexToPixel(coord)
                let ghostPos = CGPoint(x: basePos.x + mapPixelWidth, y: basePos.y)
                sprite.position = ghostPos
                sprite.zPosition = Constants.zTerrain
                sprite.setScale(1.08)
                sprite.name = "ghost_r_\(col)_\(row)"
                terrainLayer.addChild(sprite)
            }

            // Left-side ghosts (copies of right edge columns, offset left by mapPixelWidth)
            for col in (map.width - colsToGhost)..<map.width {
                let coord = HexLayout.offsetToAxial(col: col, row: row)
                guard let tile = map.tile(at: coord) else { continue }
                let texture = textureForTerrain(tile.terrain, at: coord)
                let sprite = SKSpriteNode(texture: texture)
                let basePos = layout.hexToPixel(coord)
                let ghostPos = CGPoint(x: basePos.x - mapPixelWidth, y: basePos.y)
                sprite.position = ghostPos
                sprite.zPosition = Constants.zTerrain
                sprite.setScale(1.08)
                sprite.name = "ghost_l_\(col)_\(row)"
                terrainLayer.addChild(sprite)
            }
        }
    }

    func updateTile(at coord: HexCoord, terrain: Terrain) {
        guard let node = hexNodes[coord] else { return }
        node.texture = textureCache[terrain]
    }

    private func buildTextureCache() {
        // Create 4 variants per terrain for visual variety
        for terrain in Terrain.allCases {
            // Cache variant 0 as default
            textureCache[terrain] = SKTexture.terrainHexTexture(size: layout.size, terrain: terrain, variant: 0)
        }
        // Build variant caches
        for terrain in Terrain.allCases {
            var variants: [SKTexture] = []
            for v in 0..<4 {
                variants.append(SKTexture.terrainHexTexture(size: layout.size, terrain: terrain, variant: v))
            }
            terrainVariantCache[terrain] = variants
        }
    }

    private var terrainVariantCache: [Terrain: [SKTexture]] = [:]

    func textureForTerrain(_ terrain: Terrain, at coord: HexCoord) -> SKTexture {
        let variants = terrainVariantCache[terrain] ?? [textureCache[terrain]!]
        let index = abs(coord.q &* 31 &+ coord.r &* 17) % variants.count
        return variants[index]
    }

    /// Clear and re-render all road overlays from current map data.
    /// Roads connect visually to adjacent road hexes.
    func refreshRoads(_ map: GameMap, exploredHexes: Set<HexCoord>? = nil) {
        roadLayer.removeAllChildren()
        roadCoords.removeAll()

        // First pass: collect all road coordinates
        for coord in map.allCoords {
            guard let tile = map.tile(at: coord), tile.hasRoad else { continue }
            roadCoords.insert(coord)
        }
        // Second pass: render roads with neighbor connections
        for coord in roadCoords {
            // Only show roads the player has explored
            if let explored = exploredHexes, !explored.contains(coord) { continue }

            let position = layout.hexToPixel(coord)

            // Find which neighbor directions also have roads
            var connectedDirs: [Int] = []
            for (i, dCoord) in HexCoord.directions.enumerated() {
                let neighbor = map.normalize(HexCoord(q: coord.q + dCoord.q, r: coord.r + dCoord.r))
                if roadCoords.contains(neighbor) {
                    connectedDirs.append(i)
                }
            }

            addRoadNode(at: position, connectedDirections: connectedDirs)

            // Ghost copies for wrapping
            if map.topology.wrapping && mapPixelWidth > 0 {
                let offset = HexLayout.axialToOffset(q: coord.q, r: coord.r)
                if offset.col < ghostColumns {
                    addRoadNode(
                        at: CGPoint(x: position.x + mapPixelWidth, y: position.y),
                        connectedDirections: connectedDirs
                    )
                }
                if offset.col >= map.width - ghostColumns {
                    addRoadNode(
                        at: CGPoint(x: position.x - mapPixelWidth, y: position.y),
                        connectedDirections: connectedDirs
                    )
                }
            }
        }
    }

    /// Draw a road node positioned at the hex center with segments toward connected neighbors.
    /// Using a container node at the hex position with paths relative to (0,0)
    /// fixes SpriteKit's SKShapeNode bounding-box culling issue.
    private func addRoadNode(at position: CGPoint, connectedDirections: [Int]) {
        let container = SKNode()
        container.position = position
        container.name = "road"

        let s = layout.size
        let roadWidth = s * 0.20
        let sqrt3 = CGFloat(sqrt(3.0))

        // Edge midpoint offsets for each of the 6 hex directions (flat-top)
        // These are half the center-to-center pixel distance for each direction
        let edgeOffsets: [CGPoint] = [
            CGPoint(x: 0.75 * s, y: sqrt3 / 4 * s),      // East
            CGPoint(x: 0.75 * s, y: -sqrt3 / 4 * s),     // NE
            CGPoint(x: 0, y: -sqrt3 / 2 * s),             // NW
            CGPoint(x: -0.75 * s, y: -sqrt3 / 4 * s),     // West
            CGPoint(x: -0.75 * s, y: sqrt3 / 4 * s),      // SW
            CGPoint(x: 0, y: sqrt3 / 2 * s),              // SE
        ]

        let roadColor = SKColor(red: 0.72, green: 0.60, blue: 0.38, alpha: 0.9)
        let borderColor = SKColor(red: 0.45, green: 0.35, blue: 0.20, alpha: 0.7)

        if connectedDirections.isEmpty {
            // Isolated road: draw a visible dot at center
            let dot = SKShapeNode(circleOfRadius: roadWidth * 1.5)
            dot.fillColor = roadColor
            dot.strokeColor = borderColor
            dot.lineWidth = 1.5
            container.addChild(dot)
        } else {
            // Border layer (slightly wider, darker) for definition
            let borderPath = CGMutablePath()
            for dir in connectedDirections {
                borderPath.move(to: .zero)
                borderPath.addLine(to: edgeOffsets[dir])
            }
            let border = SKShapeNode()
            border.path = borderPath
            border.strokeColor = borderColor
            border.lineWidth = roadWidth + 2
            border.lineCap = .round
            border.lineJoin = .round
            border.zPosition = 0
            container.addChild(border)

            // Main road surface
            let roadPath = CGMutablePath()
            for dir in connectedDirections {
                roadPath.move(to: .zero)
                roadPath.addLine(to: edgeOffsets[dir])
            }
            let road = SKShapeNode()
            road.path = roadPath
            road.strokeColor = roadColor
            road.lineWidth = roadWidth
            road.lineCap = .round
            road.lineJoin = .round
            road.zPosition = 0.1
            container.addChild(road)
        }

        roadLayer.addChild(container)
    }

    func hexNode(at coord: HexCoord) -> SKSpriteNode? {
        hexNodes[coord]
    }
}
