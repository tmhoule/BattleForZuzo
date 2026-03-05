import SpriteKit

class HexHighlighter {
    let highlightLayer: SKNode
    private let layout = Constants.hexLayout
    private var highlightNodes: [HexCoord: SKShapeNode] = [:]
    private var ghostHighlightNodes: [String: SKShapeNode] = [:]
    private var selectionNode: SKShapeNode?
    var mapPixelWidth: CGFloat = 0
    var mapWidth: Int = 0
    private let ghostColumns = 8

    init() {
        highlightLayer = SKNode()
        highlightLayer.zPosition = Constants.zHighlight
    }

    func showReachable(_ hexes: Set<HexCoord>) {
        clearHighlights(named: "reachable")
        for coord in hexes {
            let color = SKColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 0.3)
            let node = createHighlightHex(color: color)
            node.position = layout.hexToPixel(coord)
            node.name = "reachable"
            highlightLayer.addChild(node)
            highlightNodes[coord] = node

            addGhostHighlight(coord: coord, color: color, name: "reachable")
        }
    }

    func showAttackable(_ hexes: Set<HexCoord>, attacker: Unit? = nil, gameState: GameState? = nil) {
        clearHighlights(named: "attackable")
        for coord in hexes {
            let color = SKColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.4)
            let node = createHighlightHex(color: color)
            node.position = layout.hexToPixel(coord)
            node.name = "attackable"
            highlightLayer.addChild(node)
            highlightNodes[coord] = node

            // Damage preview label
            if let attacker = attacker, let gs = gameState,
               let defender = gs.unit(at: coord),
               let defenderTerrain = gs.map?.tile(at: coord)?.terrain {
                let defenseBonus = Int(defenderTerrain.defenseBonus)
                let expectedDamage = max(1, attacker.type.damage - defenseBonus)
                let damageLabel = SKLabelNode(text: "-\(expectedDamage)")
                damageLabel.fontName = "Menlo-Bold"
                damageLabel.fontSize = 11
                damageLabel.fontColor = .white
                damageLabel.verticalAlignmentMode = .center
                damageLabel.horizontalAlignmentMode = .center
                damageLabel.position = layout.hexToPixel(coord)
                damageLabel.zPosition = Constants.zHighlight + 1
                damageLabel.name = "attackable"

                // Background circle
                let bg = SKShapeNode(circleOfRadius: 10)
                bg.fillColor = SKColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.8)
                bg.strokeColor = .clear
                bg.position = layout.hexToPixel(coord)
                bg.zPosition = Constants.zHighlight + 0.5
                bg.name = "attackable"
                highlightLayer.addChild(bg)
                highlightLayer.addChild(damageLabel)

                let _ = defender // suppress unused warning
            }

            addGhostHighlight(coord: coord, color: color, name: "attackable")
        }
    }

    func showSelection(at coord: HexCoord) {
        selectionNode?.removeFromParent()
        let node = createHighlightHex(color: SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.2))
        node.position = layout.hexToPixel(coord)
        node.name = "selection"
        node.lineWidth = 3
        node.strokeColor = .white
        node.glowWidth = 3.0
        highlightLayer.addChild(node)
        selectionNode = node

        // Pulse animation with glow
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.15, duration: 0.6),
            SKAction.fadeAlpha(to: 0.5, duration: 0.6)
        ]))
        pulse.timingMode = .easeInEaseOut
        node.run(pulse)

        // Ghost selection for wrapping
        addGhostHighlight(coord: coord, color: SKColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.2), name: "selection")
    }

    private func addGhostHighlight(coord: HexCoord, color: SKColor, name: String) {
        guard mapPixelWidth > 0 && mapWidth > 0 else { return }
        let offset = HexLayout.axialToOffset(q: coord.q, r: coord.r)
        let position = layout.hexToPixel(coord)

        if offset.col < ghostColumns {
            let ghost = createHighlightHex(color: color)
            ghost.position = CGPoint(x: position.x + mapPixelWidth, y: position.y)
            ghost.name = name
            highlightLayer.addChild(ghost)
            ghostHighlightNodes["r_\(coord.q)_\(coord.r)_\(name)"] = ghost
        }
        if offset.col >= mapWidth - ghostColumns {
            let ghost = createHighlightHex(color: color)
            ghost.position = CGPoint(x: position.x - mapPixelWidth, y: position.y)
            ghost.name = name
            highlightLayer.addChild(ghost)
            ghostHighlightNodes["l_\(coord.q)_\(coord.r)_\(name)"] = ghost
        }
    }

    func clearSelection() {
        selectionNode?.removeFromParent()
        selectionNode = nil
    }

    func clearAllHighlights() {
        highlightLayer.removeAllChildren()
        highlightNodes.removeAll()
        ghostHighlightNodes.removeAll()
        selectionNode = nil
    }

    private func clearHighlights(named name: String) {
        highlightLayer.children
            .filter { $0.name == name }
            .forEach { $0.removeFromParent() }
        highlightNodes = highlightNodes.filter { $0.value.name != name }
    }

    private func createHighlightHex(color: SKColor) -> SKShapeNode {
        let node = SKShapeNode.hexagon(size: layout.size * 0.95)
        node.fillColor = color
        node.strokeColor = color.withAlphaComponent(0.6)
        node.lineWidth = 1.5
        return node
    }
}
