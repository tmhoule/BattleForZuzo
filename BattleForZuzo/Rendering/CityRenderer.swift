import SpriteKit

class CityRenderer {
    let cityLayer: SKNode
    private let layout = Constants.hexLayout
    private var cityNodes: [UUID: SKNode] = [:]
    private var ghostCityNodes: [String: SKNode] = [:]
    var mapPixelWidth: CGFloat = 0
    private let ghostColumns = 8

    init() {
        cityLayer = SKNode()
        cityLayer.zPosition = Constants.zCity
    }

    func renderCities(_ cities: [UUID: City], players: [Player], visibleHexes: Set<HexCoord>? = nil, exploredHexes: Set<HexCoord>? = nil, mapWidth: Int = 0) {
        // Remove old nodes
        let activeIDs = Set(cities.keys)
        for (id, node) in cityNodes {
            if !activeIDs.contains(id) {
                node.removeFromParent()
                cityNodes.removeValue(forKey: id)
            }
        }

        // Remove old ghost nodes
        for (_, node) in ghostCityNodes {
            node.removeFromParent()
        }
        ghostCityNodes.removeAll()

        for (_, city) in cities {
            // Cities are visible if currently visible OR explored (per fog of war spec)
            let isVisible = visibleHexes?.contains(city.position) ?? true
            let isExplored = exploredHexes?.contains(city.position) ?? true
            if !isVisible && !isExplored {
                if let node = cityNodes[city.id] {
                    node.isHidden = true
                }
                continue
            }

            let position = layout.hexToPixel(city.position)

            if let existingNode = cityNodes[city.id] {
                existingNode.isHidden = false
                existingNode.position = position
                updateCityNode(existingNode, city: city, players: players)
            } else {
                let node = createCityNode(city: city, players: players)
                node.position = position
                cityLayer.addChild(node)
                cityNodes[city.id] = node
            }

            // Ghost copies for wrapping
            if mapPixelWidth > 0 && mapWidth > 0 {
                let offset = HexLayout.axialToOffset(q: city.position.q, r: city.position.r)
                if offset.col < ghostColumns {
                    // Near left edge -> ghost on right
                    let ghostNode = createCityNode(city: city, players: players)
                    ghostNode.position = CGPoint(x: position.x + mapPixelWidth, y: position.y)
                    ghostNode.alpha = isVisible ? 1.0 : 0.5
                    cityLayer.addChild(ghostNode)
                    ghostCityNodes["r_\(city.id)"] = ghostNode
                }
                if offset.col >= mapWidth - ghostColumns {
                    // Near right edge -> ghost on left
                    let ghostNode = createCityNode(city: city, players: players)
                    ghostNode.position = CGPoint(x: position.x - mapPixelWidth, y: position.y)
                    ghostNode.alpha = isVisible ? 1.0 : 0.5
                    cityLayer.addChild(ghostNode)
                    ghostCityNodes["l_\(city.id)"] = ghostNode
                }
            }
        }
    }

    private func createCityNode(city: City, players: [Player]) -> SKNode {
        let container = SKNode()
        container.name = "city_\(city.id.uuidString)"

        let size = Constants.hexSize * 1.4
        let ownerColor = players.first(where: { $0.id == city.ownerID })?.color ?? SKColor(white: 0.6, alpha: 1)

        // Hex-shaped colored base platform
        let base = SKShapeNode.hexagon(size: size * 0.5)
        base.fillColor = ownerColor.withAlphaComponent(0.5)
        base.strokeColor = ownerColor
        base.lineWidth = 1.5
        base.name = "cityBase"
        container.addChild(base)

        // Central tall building
        let mainBuilding = SKShapeNode(rectOf: CGSize(width: size * 0.25, height: size * 0.5), cornerRadius: 1)
        mainBuilding.fillColor = ownerColor.withAlphaComponent(0.9)
        mainBuilding.strokeColor = .white
        mainBuilding.lineWidth = 0.5
        mainBuilding.position = CGPoint(x: 0, y: size * 0.1)
        mainBuilding.name = "cityShape"
        container.addChild(mainBuilding)

        // Left side building
        let leftBuilding = SKShapeNode(rectOf: CGSize(width: size * 0.18, height: size * 0.3), cornerRadius: 1)
        leftBuilding.fillColor = ownerColor.withAlphaComponent(0.7)
        leftBuilding.strokeColor = SKColor(white: 0.9, alpha: 0.5)
        leftBuilding.lineWidth = 0.5
        leftBuilding.position = CGPoint(x: -size * 0.22, y: 0)
        container.addChild(leftBuilding)

        // Right side building
        let rightBuilding = SKShapeNode(rectOf: CGSize(width: size * 0.18, height: size * 0.35), cornerRadius: 1)
        rightBuilding.fillColor = ownerColor.withAlphaComponent(0.7)
        rightBuilding.strokeColor = SKColor(white: 0.9, alpha: 0.5)
        rightBuilding.lineWidth = 0.5
        rightBuilding.position = CGPoint(x: size * 0.22, y: size * 0.02)
        container.addChild(rightBuilding)

        // Production gear indicator (spinning when producing)
        if city.productionQueue != nil {
            let gear = SKLabelNode(text: "\u{2699}")
            gear.fontSize = 8
            gear.fontColor = .yellow
            gear.position = CGPoint(x: size * 0.35, y: size * 0.3)
            gear.name = "productionGear"
            gear.zPosition = 1
            container.addChild(gear)

            let spin = SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 4.0))
            gear.run(spin)
        }

        // Drop shadow on city name
        let shadowLabel = SKLabelNode(text: city.name)
        shadowLabel.fontName = "Menlo-Bold"
        shadowLabel.fontSize = 9
        shadowLabel.fontColor = SKColor(white: 0, alpha: 0.8)
        shadowLabel.verticalAlignmentMode = .bottom
        shadowLabel.horizontalAlignmentMode = .center
        shadowLabel.position = CGPoint(x: 1, y: Constants.hexSize * 0.7 - 1)
        shadowLabel.zPosition = Constants.zUnit + 4
        container.addChild(shadowLabel)

        // City name label
        let nameLabel = SKLabelNode(text: city.name)
        nameLabel.fontName = "Menlo-Bold"
        nameLabel.fontSize = 9
        nameLabel.fontColor = .white
        nameLabel.verticalAlignmentMode = .bottom
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: Constants.hexSize * 0.7)
        nameLabel.name = "cityName"
        nameLabel.zPosition = Constants.zUnit + 5
        container.addChild(nameLabel)

        // Name background for readability
        let bgWidth = CGFloat(city.name.count) * 6.0 + 8
        let nameBG = SKShapeNode(rectOf: CGSize(width: bgWidth, height: 13), cornerRadius: 3)
        nameBG.fillColor = SKColor(white: 0, alpha: 0.6)
        nameBG.strokeColor = .clear
        nameBG.position = CGPoint(x: 0, y: Constants.hexSize * 0.7 + 5)
        nameBG.zPosition = Constants.zUnit + 4
        container.addChild(nameBG)

        return container
    }

    private func updateCityNode(_ node: SKNode, city: City, players: [Player]) {
        let ownerColor = players.first(where: { $0.id == city.ownerID })?.color ?? SKColor(white: 0.6, alpha: 1)
        if let cityBase = node.childNode(withName: "cityBase") as? SKShapeNode {
            cityBase.fillColor = ownerColor.withAlphaComponent(0.5)
            cityBase.strokeColor = ownerColor
        }
        if let cityShape = node.childNode(withName: "cityShape") as? SKShapeNode {
            cityShape.fillColor = ownerColor.withAlphaComponent(0.9)
        }

        // Update production gear
        let hasGear = node.childNode(withName: "productionGear") != nil
        if city.productionQueue != nil && !hasGear {
            let size = Constants.hexSize * 1.4
            let gear = SKLabelNode(text: "\u{2699}")
            gear.fontSize = 8
            gear.fontColor = .yellow
            gear.position = CGPoint(x: size * 0.35, y: size * 0.3)
            gear.name = "productionGear"
            gear.zPosition = 1
            node.addChild(gear)
            gear.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi * 2, duration: 4.0)))
        } else if city.productionQueue == nil && hasGear {
            node.childNode(withName: "productionGear")?.removeFromParent()
        }
    }

    func cityNode(for cityID: UUID) -> SKNode? {
        cityNodes[cityID]
    }

    /// Play capture flash animation
    func animateCapture(cityID: UUID) {
        guard let node = cityNodes[cityID] else { return }
        let flash = SKShapeNode(circleOfRadius: Constants.hexSize * 1.2)
        flash.fillColor = .white
        flash.strokeColor = .clear
        flash.alpha = 0.8
        flash.zPosition = 2
        node.addChild(flash)

        let expand = SKAction.scale(to: 1.5, duration: 0.3)
        let fade = SKAction.fadeOut(withDuration: 0.3)
        flash.run(SKAction.sequence([SKAction.group([expand, fade]), SKAction.removeFromParent()]))
    }
}
