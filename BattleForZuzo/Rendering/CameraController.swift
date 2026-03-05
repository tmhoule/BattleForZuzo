import SpriteKit

class CameraController {
    let cameraNode: SKCameraNode
    private var initialScale: CGFloat = 1.0
    private var lastPanPosition: CGPoint?

    var minZoom: CGFloat = Constants.minZoom
    var maxZoom: CGFloat = Constants.maxZoom
    var bounds: CGRect = .zero
    var viewSize: CGSize = .zero
    var wrapping: Bool = false

    init() {
        cameraNode = SKCameraNode()
        cameraNode.setScale(Constants.defaultZoom)
    }

    // MARK: - Pan

    func beginPan(at point: CGPoint) {
        lastPanPosition = point
    }

    func updatePan(to point: CGPoint) {
        guard let last = lastPanPosition else { return }
        let delta = CGPoint(
            x: (last.x - point.x) * cameraNode.xScale,
            y: (point.y - last.y) * cameraNode.yScale  // inverted for natural drag
        )
        cameraNode.position = CGPoint(
            x: cameraNode.position.x + delta.x,
            y: cameraNode.position.y + delta.y
        )
        lastPanPosition = point
        clampPosition()
    }

    func endPan() {
        lastPanPosition = nil
    }

    // MARK: - Zoom

    func beginPinch() {
        initialScale = cameraNode.xScale
    }

    func updatePinch(scale: CGFloat) {
        let newScale = initialScale / scale
        cameraNode.setScale(max(minZoom, min(maxZoom, newScale)))
        clampPosition()
    }

    func zoom(by factor: CGFloat, at point: CGPoint) {
        let newScale = max(minZoom, min(maxZoom, cameraNode.xScale * factor))
        cameraNode.setScale(newScale)
        clampPosition()
    }

    // MARK: - Center

    func centerOn(_ position: CGPoint, animated: Bool = true) {
        if animated {
            let action = SKAction.move(to: position, duration: 0.3)
            action.timingMode = .easeInEaseOut
            cameraNode.run(action)
        } else {
            cameraNode.position = position
        }
    }

    // MARK: - Bounds

    func updateBounds(_ newBounds: CGRect) {
        bounds = newBounds
    }

    private func clampPosition() {
        guard bounds != .zero, viewSize != .zero else { return }

        // Visible area in scene coordinates = screen size * camera scale
        let visibleWidth = viewSize.width * cameraNode.xScale
        let visibleHeight = viewSize.height * cameraNode.yScale

        // Only clamp x when NOT wrapping
        if !wrapping {
            let minX = bounds.minX + visibleWidth / 2
            let maxX = bounds.maxX - visibleWidth / 2
            if minX < maxX {
                cameraNode.position.x = max(minX, min(maxX, cameraNode.position.x))
            } else {
                // Map smaller than viewport — center it
                cameraNode.position.x = bounds.midX
            }
        }

        // Always clamp y
        let minY = bounds.minY + visibleHeight / 2
        let maxY = bounds.maxY - visibleHeight / 2
        if minY < maxY {
            cameraNode.position.y = max(minY, min(maxY, cameraNode.position.y))
        } else {
            cameraNode.position.y = bounds.midY
        }
    }
}
