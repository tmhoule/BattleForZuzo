import SpriteKit

class UnitRenderer {
    let unitLayer: SKNode
    private let layout = Constants.hexLayout
    private var unitNodes: [UUID: SKNode] = [:]
    private var ghostUnitNodes: [String: SKNode] = [:]
    var mapPixelWidth: CGFloat = 0
    var mapWidth: Int = 0
    private let ghostColumns = 8

    init() {
        unitLayer = SKNode()
        unitLayer.zPosition = Constants.zUnit
    }

    func renderUnits(_ units: [Unit], players: [Player], visibleHexes: Set<HexCoord>? = nil, submarineDetectionHexes: Set<HexCoord>? = nil, humanPlayerID: UUID? = nil) {
        // Remove old nodes for units that no longer exist
        let activeIDs = Set(units.map { $0.id })
        for (id, node) in unitNodes {
            if !activeIDs.contains(id) {
                node.removeFromParent()
                unitNodes.removeValue(forKey: id)
            }
        }

        // Remove old ghost nodes
        for (_, node) in ghostUnitNodes {
            node.removeFromParent()
        }
        ghostUnitNodes.removeAll()

        for unit in units {
            guard unit.isAlive && !unit.isLoaded else {
                // Remove node if unit is loaded or dead
                if let node = unitNodes[unit.id] {
                    node.removeFromParent()
                    unitNodes.removeValue(forKey: unit.id)
                }
                continue
            }

            // Check visibility (enemy submarines need a friendly unit within 2 hexes)
            if let visible = visibleHexes {
                let isVisible: Bool
                if unit.type == .submarine,
                   let humanID = humanPlayerID,
                   unit.ownerID != humanID {
                    isVisible = submarineDetectionHexes?.contains(unit.position) ?? false
                } else {
                    isVisible = visible.contains(unit.position)
                }
                if !isVisible {
                    if let node = unitNodes[unit.id] {
                        node.isHidden = true
                    }
                    continue
                }
            }

            let position = layout.hexToPixel(unit.position)
            let playerColor = players.first(where: { $0.id == unit.ownerID })?.color ?? .white

            if let existingNode = unitNodes[unit.id] {
                // Update position
                existingNode.isHidden = false
                existingNode.position = position
                // Update HP and movement indicators
                updateHealthBar(on: existingNode, unit: unit)
                updateMovementPips(on: existingNode, unit: unit)
            } else {
                // Create new unit node
                let node = createUnitNode(unit: unit, color: playerColor)
                node.position = position
                unitLayer.addChild(node)
                unitNodes[unit.id] = node
            }

            // Ghost copies for wrapping
            if mapPixelWidth > 0 && mapWidth > 0 {
                let offset = HexLayout.axialToOffset(q: unit.position.q, r: unit.position.r)
                if offset.col < ghostColumns {
                    let ghostNode = createUnitNode(unit: unit, color: playerColor)
                    ghostNode.position = CGPoint(x: position.x + mapPixelWidth, y: position.y)
                    unitLayer.addChild(ghostNode)
                    ghostUnitNodes["r_\(unit.id)"] = ghostNode
                }
                if offset.col >= mapWidth - ghostColumns {
                    let ghostNode = createUnitNode(unit: unit, color: playerColor)
                    ghostNode.position = CGPoint(x: position.x - mapPixelWidth, y: position.y)
                    unitLayer.addChild(ghostNode)
                    ghostUnitNodes["l_\(unit.id)"] = ghostNode
                }
            }
        }
    }

    func animateMove(_ unit: Unit, path: [HexCoord], completion: @escaping () -> Void) {
        guard let node = unitNodes[unit.id], path.count > 1 else {
            completion()
            return
        }

        var actions: [SKAction] = []
        for i in 1..<path.count {
            let targetPos = layout.hexToPixel(path[i])
            let moveAction = SKAction.move(to: targetPos, duration: Constants.moveAnimationDuration)
            moveAction.timingMode = .easeInEaseOut
            actions.append(moveAction)
        }

        node.run(SKAction.sequence(actions)) {
            completion()
        }
    }

    func animateAttack(_ attacker: Unit, target: Unit, defenderDestroyed: Bool = false, completion: @escaping () -> Void) {
        guard let attackerNode = unitNodes[attacker.id] else {
            completion()
            return
        }

        let targetPos = layout.hexToPixel(target.position)
        let originalPos = attackerNode.position
        let midPoint = CGPoint(
            x: (originalPos.x + targetPos.x) / 2,
            y: (originalPos.y + targetPos.y) / 2
        )

        let forward = SKAction.move(to: midPoint, duration: Constants.attackAnimationDuration / 2)
        let back = SKAction.move(to: originalPos, duration: Constants.attackAnimationDuration / 2)
        forward.timingMode = .easeIn
        back.timingMode = .easeOut

        // Flash target and spawn hit particles
        if let targetNode = unitNodes[target.id] {
            let flash = SKAction.sequence([
                SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.1),
                SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
            ])
            targetNode.run(flash)

            // Orange spark burst on hit
            spawnHitParticles(at: targetPos, isKill: defenderDestroyed)
        }

        attackerNode.run(SKAction.sequence([forward, back])) {
            completion()
        }
    }

    /// Spawn orange spark particles at a position
    private func spawnHitParticles(at position: CGPoint, isKill: Bool) {
        let count = isKill ? 12 : 6
        let maxDist: CGFloat = isKill ? 25 : 15

        for _ in 0..<count {
            let particle = SKShapeNode(circleOfRadius: isKill ? 3 : 2)
            particle.fillColor = isKill ? .red : .orange
            particle.strokeColor = .yellow
            particle.lineWidth = 0.5
            particle.position = position
            particle.zPosition = Constants.zUnit + 10
            unitLayer.addChild(particle)

            let angle = CGFloat.random(in: 0..<(.pi * 2))
            let dist = CGFloat.random(in: 5...maxDist)
            let dest = CGPoint(x: position.x + cos(angle) * dist,
                             y: position.y + sin(angle) * dist)
            let duration = isKill ? 0.4 : 0.25

            let move = SKAction.move(to: dest, duration: duration)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: duration)
            let scale = SKAction.scale(to: 0.1, duration: duration)
            let group = SKAction.group([move, fade, scale])
            particle.run(SKAction.sequence([group, SKAction.removeFromParent()]))
        }
    }

    /// Spawn fading trail dots behind a moving unit
    func spawnMovementTrail(from start: CGPoint, to end: CGPoint) {
        let steps = 3
        for i in 0..<steps {
            let t = CGFloat(i + 1) / CGFloat(steps + 1)
            let pos = CGPoint(x: start.x + (end.x - start.x) * t,
                            y: start.y + (end.y - start.y) * t)
            let dot = SKShapeNode(circleOfRadius: 1.5)
            dot.fillColor = SKColor(white: 0.8, alpha: 0.5)
            dot.strokeColor = .clear
            dot.position = pos
            dot.zPosition = Constants.zUnit - 1
            unitLayer.addChild(dot)

            dot.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.3 + Double(i) * 0.1),
                SKAction.fadeOut(withDuration: 0.5),
                SKAction.removeFromParent()
            ]))
        }
    }

    func removeUnit(_ unitID: UUID) {
        if let node = unitNodes[unitID] {
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            node.run(fadeOut) {
                node.removeFromParent()
            }
            unitNodes.removeValue(forKey: unitID)
        }
    }

    // MARK: - Node Creation

    private func createUnitNode(unit: Unit, color: SKColor) -> SKNode {
        let container = SKNode()
        container.name = "unit_\(unit.id.uuidString)"

        let size = Constants.hexSize * 1.2

        // Player-colored ring with semi-transparent fill
        let bg = SKShapeNode(circleOfRadius: size / 2)
        bg.fillColor = color.withAlphaComponent(0.35)
        bg.strokeColor = color
        bg.lineWidth = 2.5
        bg.glowWidth = 1.0
        container.addChild(bg)

        // Unit silhouette
        let silhouette = createUnitSilhouette(type: unit.type, size: size)
        container.addChild(silhouette)

        // HP bar
        let hpBar = createHealthBar(unit: unit)
        hpBar.position = CGPoint(x: 0, y: -size / 2 - 5)
        hpBar.name = "hpBar"
        container.addChild(hpBar)

        // Movement pip indicators
        let movePips = createMovementPips(unit: unit)
        movePips.position = CGPoint(x: 0, y: size / 2 + 3)
        movePips.name = "movePips"
        container.addChild(movePips)

        // Subtle idle breathing animation
        let breathe = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.03, duration: 1.5),
            SKAction.scale(to: 0.97, duration: 1.5)
        ]))
        breathe.timingMode = .easeInEaseOut
        container.run(breathe)

        return container
    }

    private func createUnitSilhouette(type: UnitType, size: CGFloat) -> SKNode {
        let node = SKShapeNode()
        let path = CGMutablePath()
        let s = size * 0.35  // scale factor

        switch type {
        case .tank:
            // Rectangle body + turret barrel
            path.addRect(CGRect(x: -s * 0.8, y: -s * 0.4, width: s * 1.6, height: s * 0.8))
            path.addRect(CGRect(x: -s * 0.3, y: -s * 0.25, width: s * 0.6, height: s * 0.5))
            path.addRect(CGRect(x: s * 0.3, y: -s * 0.08, width: s * 0.7, height: s * 0.16))

        case .submarine:
            // Oval hull + conning tower
            path.addEllipse(in: CGRect(x: -s, y: -s * 0.3, width: s * 2, height: s * 0.6))
            path.addRect(CGRect(x: -s * 0.15, y: s * 0.1, width: s * 0.3, height: s * 0.4))

        case .carrier:
            // Flat deck shape
            path.move(to: CGPoint(x: -s, y: -s * 0.2))
            path.addLine(to: CGPoint(x: s * 0.8, y: -s * 0.2))
            path.addLine(to: CGPoint(x: s, y: 0))
            path.addLine(to: CGPoint(x: s * 0.8, y: s * 0.2))
            path.addLine(to: CGPoint(x: -s, y: s * 0.2))
            path.closeSubpath()
            // Deck stripe
            path.move(to: CGPoint(x: -s * 0.7, y: 0))
            path.addLine(to: CGPoint(x: s * 0.6, y: 0))

        case .artillery:
            // Base + angled barrel
            path.addRect(CGRect(x: -s * 0.5, y: -s * 0.4, width: s, height: s * 0.5))
            // Barrel at angle
            path.move(to: CGPoint(x: 0, y: s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.7, y: s * 0.6))
            path.addLine(to: CGPoint(x: s * 0.55, y: s * 0.7))
            path.addLine(to: CGPoint(x: -s * 0.1, y: s * 0.15))
            path.closeSubpath()

        case .airplane:
            // Fuselage + wings cross
            path.addEllipse(in: CGRect(x: -s * 0.15, y: -s * 0.7, width: s * 0.3, height: s * 1.4))
            // Wings
            path.move(to: CGPoint(x: -s * 0.9, y: -s * 0.05))
            path.addLine(to: CGPoint(x: s * 0.9, y: -s * 0.05))
            path.addLine(to: CGPoint(x: s * 0.9, y: s * 0.05))
            path.addLine(to: CGPoint(x: -s * 0.9, y: s * 0.05))
            path.closeSubpath()
            // Tail
            path.move(to: CGPoint(x: -s * 0.35, y: -s * 0.55))
            path.addLine(to: CGPoint(x: s * 0.35, y: -s * 0.55))
            path.addLine(to: CGPoint(x: s * 0.35, y: -s * 0.45))
            path.addLine(to: CGPoint(x: -s * 0.35, y: -s * 0.45))
            path.closeSubpath()

        case .construction:
            // Truck cab (right side)
            path.addRect(CGRect(x: s * 0.3, y: -s * 0.35, width: s * 0.5, height: s * 0.5))
            // Flatbed (left side)
            path.addRect(CGRect(x: -s * 0.7, y: -s * 0.25, width: s * 1.0, height: s * 0.35))
            // Wheels
            path.addEllipse(in: CGRect(x: -s * 0.5, y: -s * 0.55, width: s * 0.3, height: s * 0.3))
            path.addEllipse(in: CGRect(x: s * 0.35, y: -s * 0.55, width: s * 0.3, height: s * 0.3))
            // Crane arm
            path.move(to: CGPoint(x: -s * 0.3, y: s * 0.1))
            path.addLine(to: CGPoint(x: s * 0.1, y: s * 0.65))
            path.addLine(to: CGPoint(x: s * 0.2, y: s * 0.55))
            path.addLine(to: CGPoint(x: -s * 0.2, y: s * 0.1))
            path.closeSubpath()
        }

        node.path = path
        node.fillColor = .white
        node.strokeColor = SKColor(white: 0.9, alpha: 0.8)
        node.lineWidth = 0.5
        return node
    }

    private func createMovementPips(unit: Unit) -> SKNode {
        let container = SKNode()
        let pipSize: CGFloat = 2.5
        let spacing: CGFloat = 5
        let total = unit.type.movement
        let remaining = Int(unit.movementRemaining)
        let startX = -CGFloat(total - 1) * spacing / 2

        for i in 0..<total {
            let pip = SKShapeNode(circleOfRadius: pipSize)
            pip.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            pip.fillColor = i < remaining ? .cyan : SKColor(white: 0.3, alpha: 0.5)
            pip.strokeColor = .clear
            container.addChild(pip)
        }
        return container
    }

    private func createHealthBar(unit: Unit) -> SKNode {
        let container = SKNode()
        let barWidth: CGFloat = Constants.hexSize * 0.8
        let barHeight: CGFloat = 3

        // Background
        let bg = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight))
        bg.fillColor = .darkGray
        bg.strokeColor = .clear
        container.addChild(bg)

        // Health fill
        let hpPercent = CGFloat(unit.hp) / CGFloat(unit.type.maxHP)
        let fillWidth = barWidth * hpPercent
        let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: barHeight))
        fill.fillColor = hpPercent > 0.5 ? .green : (hpPercent > 0.25 ? .yellow : .red)
        fill.strokeColor = .clear
        fill.position.x = (fillWidth - barWidth) / 2
        fill.name = "hpFill"
        container.addChild(fill)

        return container
    }

    private func updateHealthBar(on node: SKNode, unit: Unit) {
        guard let hpBar = node.childNode(withName: "hpBar") else { return }
        hpBar.removeAllChildren()

        let barWidth: CGFloat = Constants.hexSize * 0.8
        let barHeight: CGFloat = 3

        let bg = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight))
        bg.fillColor = .darkGray
        bg.strokeColor = .clear
        hpBar.addChild(bg)

        let hpPercent = CGFloat(unit.hp) / CGFloat(unit.type.maxHP)
        let fillWidth = barWidth * hpPercent
        let fill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: barHeight))
        fill.fillColor = hpPercent > 0.5 ? .green : (hpPercent > 0.25 ? .yellow : .red)
        fill.strokeColor = .clear
        fill.position.x = (fillWidth - barWidth) / 2
        hpBar.addChild(fill)
    }

    private func updateMovementPips(on node: SKNode, unit: Unit) {
        guard let pipContainer = node.childNode(withName: "movePips") else { return }
        pipContainer.removeAllChildren()

        let pipSize: CGFloat = 2.5
        let spacing: CGFloat = 5
        let total = unit.type.movement
        let remaining = Int(unit.movementRemaining)
        let startX = -CGFloat(total - 1) * spacing / 2

        for i in 0..<total {
            let pip = SKShapeNode(circleOfRadius: pipSize)
            pip.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            pip.fillColor = i < remaining ? .cyan : SKColor(white: 0.3, alpha: 0.5)
            pip.strokeColor = .clear
            pipContainer.addChild(pip)
        }
    }

    func unitNode(for unitID: UUID) -> SKNode? {
        unitNodes[unitID]
    }
}
