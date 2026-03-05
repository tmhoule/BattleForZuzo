import SpriteKit

class FogRenderer {
    let fogLayer: SKNode
    private let layout = Constants.hexLayout
    private var fogNodes: [HexCoord: SKSpriteNode] = [:]
    private var ghostFogNodes: [String: SKSpriteNode] = [:]
    private var blackTexture: SKTexture?
    private var greyTexture: SKTexture?
    var mapPixelWidth: CGFloat = 0
    private let ghostColumns = 8

    init() {
        fogLayer = SKNode()
        fogLayer.zPosition = Constants.zFog
        buildTextures()
    }

    private func buildTextures() {
        blackTexture = SKTexture.hexTexture(size: layout.size, color: .black)
        greyTexture = SKTexture.fogHexTexture(size: layout.size, alpha: 0.65)
    }

    func initializeFog(for map: GameMap) {
        fogLayer.removeAllChildren()
        fogNodes.removeAll()
        ghostFogNodes.removeAll()

        for coord in map.allCoords {
            let position = layout.hexToPixel(coord)
            let sprite = SKSpriteNode(texture: blackTexture)
            sprite.position = position
            sprite.zPosition = Constants.zFog
            sprite.setScale(1.08)
            fogLayer.addChild(sprite)
            fogNodes[coord] = sprite
        }

        // Ghost fog columns for wrapping
        if map.topology.wrapping {
            let colsToGhost = min(ghostColumns, map.width)
            for row in 0..<map.height {
                for col in 0..<colsToGhost {
                    let coord = HexLayout.offsetToAxial(col: col, row: row)
                    let basePos = layout.hexToPixel(coord)
                    let sprite = SKSpriteNode(texture: blackTexture)
                    sprite.position = CGPoint(x: basePos.x + mapPixelWidth, y: basePos.y)
                    sprite.zPosition = Constants.zFog
                    sprite.setScale(1.08)
                    fogLayer.addChild(sprite)
                    ghostFogNodes["r_\(col)_\(row)"] = sprite
                }
                for col in (map.width - colsToGhost)..<map.width {
                    let coord = HexLayout.offsetToAxial(col: col, row: row)
                    let basePos = layout.hexToPixel(coord)
                    let sprite = SKSpriteNode(texture: blackTexture)
                    sprite.position = CGPoint(x: basePos.x - mapPixelWidth, y: basePos.y)
                    sprite.zPosition = Constants.zFog
                    sprite.setScale(1.08)
                    fogLayer.addChild(sprite)
                    ghostFogNodes["l_\(col)_\(row)"] = sprite
                }
            }
        }
    }

    func updateFog(visibleHexes: Set<HexCoord>, exploredHexes: Set<HexCoord>, mapWidth: Int = 0) {
        for (coord, node) in fogNodes {
            if visibleHexes.contains(coord) {
                node.isHidden = true
            } else if exploredHexes.contains(coord) {
                node.isHidden = false
                node.texture = greyTexture
            } else {
                node.isHidden = false
                node.texture = blackTexture
            }
        }

        // Update ghost fog to match their source columns
        for (key, node) in ghostFogNodes {
            let parts = key.split(separator: "_")
            guard parts.count == 3,
                  let col = Int(parts[1]),
                  let row = Int(parts[2]) else { continue }
            let coord = HexLayout.offsetToAxial(col: col, row: row)
            if visibleHexes.contains(coord) {
                node.isHidden = true
            } else if exploredHexes.contains(coord) {
                node.isHidden = false
                node.texture = greyTexture
            } else {
                node.isHidden = false
                node.texture = blackTexture
            }
        }
    }
}
