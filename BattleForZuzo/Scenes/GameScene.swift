import SpriteKit
import Combine

protocol GameSceneDelegate: AnyObject {
    func didTapUnit(_ unit: Unit)
    func didTapCity(_ city: City)
    func didTapEmpty(at coord: HexCoord)
}

class GameScene: SKScene {
    weak var gameSceneDelegate: GameSceneDelegate?
    var gameState: GameState?

    // Renderers
    let mapRenderer = MapRenderer()
    let unitRenderer = UnitRenderer()
    let cityRenderer = CityRenderer()
    let hexHighlighter = HexHighlighter()
    let fogRenderer = FogRenderer()
    let cameraController = CameraController()

    // Gesture state
    private var isPanning = false
    private var isZooming = false
    private var lastPanPoint: CGPoint?

    // Haptic feedback
    private let selectionFeedback = UIImpactFeedbackGenerator(style: .light)
    private let actionFeedback = UIImpactFeedbackGenerator(style: .medium)

    private var cancellables = Set<AnyCancellable>()

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1)

        // Setup camera
        camera = cameraController.cameraNode
        addChild(cameraController.cameraNode)

        // Add render layers
        addChild(mapRenderer.terrainLayer)
        addChild(cityRenderer.cityLayer)
        addChild(hexHighlighter.highlightLayer)
        addChild(unitRenderer.unitLayer)
        addChild(fogRenderer.fogLayer)
        addChild(mapRenderer.roadLayer)  // Above fog so roads show on explored hexes

        // Setup gesture recognizers
        setupGestures(in: view)

        // Initial render if game state is ready
        if let gs = gameState, gs.map != nil {
            renderAll()
        }
    }

    func renderAll() {
        guard let gs = gameState, let map = gs.map else { return }

        mapRenderer.renderMap(map)

        // Pass wrapping info to renderers (0 disables ghost columns)
        let pixelWidth = map.topology.wrapping ? mapRenderer.mapPixelWidth : 0
        cityRenderer.mapPixelWidth = pixelWidth
        unitRenderer.mapPixelWidth = pixelWidth
        unitRenderer.mapWidth = map.width
        fogRenderer.mapPixelWidth = pixelWidth
        hexHighlighter.mapPixelWidth = pixelWidth
        hexHighlighter.mapWidth = map.width
        cameraController.wrapping = map.topology.wrapping

        cityRenderer.renderCities(map.cities, players: gs.players, mapWidth: map.width)
        fogRenderer.initializeFog(for: map)

        // Set camera bounds and view size
        let bounds = Constants.hexLayout.mapBounds(width: map.width, height: map.height)
        cameraController.updateBounds(bounds)
        if let viewSize = self.view?.bounds.size {
            cameraController.viewSize = viewSize
        }

        // Render units and fog
        updateRendering()

        // Center on human player's first unit or city
        if let human = gs.humanPlayer {
            let playerUnits = gs.units(for: human.id)
            if let firstUnit = playerUnits.first {
                let pos = Constants.hexLayout.hexToPixel(firstUnit.position)
                cameraController.centerOn(pos, animated: false)
            }
        }
    }

    func updateRendering() {
        guard let gs = gameState, let map = gs.map else { return }

        // Pick up any newly built roads (only show on explored hexes)
        mapRenderer.refreshRoads(map, exploredHexes: gs.humanPlayer?.exploredTiles)

        let humanPlayer = gs.humanPlayer
        var visibleHexes: Set<HexCoord>?

        if let player = humanPlayer {
            visibleHexes = gs.fogOfWarSystem?.visibleHexes(for: player)
            fogRenderer.updateFog(
                visibleHexes: visibleHexes ?? [],
                exploredHexes: player.exploredTiles,
                mapWidth: map.width
            )
        }

        let subDetection = humanPlayer.flatMap { gs.fogOfWarSystem?.submarineDetectionHexes(for: $0) }
        unitRenderer.renderUnits(gs.units, players: gs.players, visibleHexes: visibleHexes, submarineDetectionHexes: subDetection, humanPlayerID: humanPlayer?.id)
        cityRenderer.renderCities(map.cities, players: gs.players, visibleHexes: visibleHexes, exploredHexes: humanPlayer?.exploredTiles, mapWidth: map.width)

        // Update highlights
        hexHighlighter.clearAllHighlights()
        if let selected = gs.selectedUnit {
            hexHighlighter.showSelection(at: selected.position)
            if !gs.reachableHexes.isEmpty {
                hexHighlighter.showReachable(gs.reachableHexes)
            }
            if !gs.attackableHexes.isEmpty {
                hexHighlighter.showAttackable(gs.attackableHexes, attacker: selected, gameState: gs)
            }
        }
    }

    // MARK: - Touch Handling

    private var touchStartPos: CGPoint?
    private var touchStartTime: TimeInterval = 0
    private let tapThreshold: CGFloat = 10  // max movement for a tap
    private let tapTimeThreshold: TimeInterval = 0.3

    private var tooltipNode: SKNode?

    private func setupGestures(in view: SKView) {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        view.addGestureRecognizer(longPressGesture)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let gs = gameState, let map = gs.map, let view = self.view else { return }

        switch gesture.state {
        case .began:
            let viewLocation = gesture.location(in: view)
            let sceneLocation = convertPoint(fromView: viewLocation)
            let rawCoord = Constants.hexLayout.pixelToHex(sceneLocation)
            let hexCoord = map.normalize(rawCoord)

            guard let tile = map.tile(at: hexCoord) else { return }

            // Create tooltip at hex position
            let hexPos = Constants.hexLayout.hexToPixel(hexCoord)
            showTerrainTooltip(terrain: tile.terrain, at: hexPos, hasRoad: tile.hasRoad)

        case .ended, .cancelled:
            dismissTooltip()
        default:
            break
        }
    }

    private func showTerrainTooltip(terrain: Terrain, at position: CGPoint, hasRoad: Bool = false) {
        dismissTooltip()

        let container = SKNode()
        container.zPosition = Constants.zUI

        // Background
        var text = "\(terrain.displayName)\nMove: \(terrain.movementCost)\nDef: +\(Int(terrain.defenseBonus))"
        if hasRoad { text += "\nRoad" }
        let bgWidth: CGFloat = 100
        let bgHeight: CGFloat = hasRoad ? 62 : 50

        let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: bgHeight), cornerRadius: 6)
        bg.fillColor = SKColor(white: 0, alpha: 0.85)
        bg.strokeColor = SKColor(white: 0.5, alpha: 0.5)
        bg.lineWidth = 1
        container.addChild(bg)

        let label = SKLabelNode(text: text)
        label.fontName = "Menlo"
        label.fontSize = 10
        label.fontColor = .white
        label.numberOfLines = hasRoad ? 4 : 3
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.preferredMaxLayoutWidth = bgWidth - 8
        container.addChild(label)

        container.position = CGPoint(x: position.x, y: position.y + Constants.hexSize * 1.5)
        addChild(container)
        tooltipNode = container

        // Fade in
        container.alpha = 0
        container.run(SKAction.fadeIn(withDuration: 0.15))
    }

    private func dismissTooltip() {
        tooltipNode?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ]))
        tooltipNode = nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isZooming else { return }
        guard let touch = touches.first, let view = self.view else { return }
        touchStartPos = touch.location(in: view)
        touchStartTime = touch.timestamp
        isPanning = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isZooming else { return }
        guard let touch = touches.first, let view = self.view else { return }
        let location = touch.location(in: view)

        if !isPanning {
            guard let start = touchStartPos else { return }
            let dx = location.x - start.x
            let dy = location.y - start.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance > tapThreshold {
                isPanning = true
                cameraController.beginPan(at: start)
            }
        }

        if isPanning {
            cameraController.updatePan(to: location)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view = self.view else { return }

        if isPanning {
            cameraController.endPan()
            isPanning = false
        } else if !isZooming {
            // This was a tap (not part of a zoom)
            let viewLocation = touch.location(in: view)
            handleTapAt(viewLocation)
        }
        touchStartPos = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isPanning {
            cameraController.endPan()
            isPanning = false
        }
        touchStartPos = nil
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            cameraController.beginPinch()
            isZooming = true
        case .changed:
            cameraController.updatePinch(scale: gesture.scale)
        case .ended, .cancelled:
            isZooming = false
        default:
            break
        }
    }

    private func handleTapAt(_ viewLocation: CGPoint) {
        guard !isZooming else { return }
        guard let gs = gameState else { return }

        let sceneLocation = convertPoint(fromView: viewLocation)
        let rawHexCoord = Constants.hexLayout.pixelToHex(sceneLocation)

        guard let map = gs.map else { return }
        let hexCoord = map.normalize(rawHexCoord)
        guard map.isValid(hexCoord) else { return }

        // Check what's at this hex - unit first, then city, then empty
        if let unit = gs.unit(at: hexCoord) {
            selectionFeedback.impactOccurred()
            gameSceneDelegate?.didTapUnit(unit)
        } else if let city = map.city(at: hexCoord) {
            selectionFeedback.impactOccurred()
            gameSceneDelegate?.didTapCity(city)
        } else {
            gameSceneDelegate?.didTapEmpty(at: hexCoord)
        }
    }
}
