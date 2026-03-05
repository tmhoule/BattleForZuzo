import Foundation
import SpriteKit

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }
}

extension SKColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    func withBrightness(_ factor: CGFloat) -> SKColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return SKColor(hue: h, saturation: s, brightness: min(b * factor, 1.0), alpha: a)
    }
}

extension Array {
    func randomElement(using generator: inout some RandomNumberGenerator) -> Element? {
        guard !isEmpty else { return nil }
        return self[Int.random(in: indices, using: &generator)]
    }
}

extension SKShapeNode {
    static func hexagon(size: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat.pi / 180.0 * CGFloat(60 * i)
            let point = CGPoint(x: size * cos(angle), y: size * sin(angle))
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        return node
    }
}

extension SKTexture {
    static func hexTexture(size: CGFloat, color: SKColor) -> SKTexture {
        let diameter = size * 2 + 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { ctx in
            let context = ctx.cgContext
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            let path = CGMutablePath()
            for i in 0..<6 {
                let angle = CGFloat.pi / 180.0 * CGFloat(60 * i)
                let point = CGPoint(x: center.x + size * cos(angle),
                                    y: center.y + size * sin(angle))
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
            context.addPath(path)
            context.setFillColor(color.cgColor)
            context.fillPath()
            // Subtle border
            context.addPath(path)
            context.setStrokeColor(SKColor(white: 0, alpha: 0.15).cgColor)
            context.setLineWidth(1)
            context.strokePath()
        }
        return SKTexture(image: image)
    }

    /// Terrain-aware hex texture with gradient bevel and detail overlays
    static func terrainHexTexture(size: CGFloat, terrain: Terrain, variant: Int = 0) -> SKTexture {
        let diameter = size * 2 + 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { ctx in
            let context = ctx.cgContext
            let center = CGPoint(x: diameter / 2, y: diameter / 2)

            // Build hex path
            let path = CGMutablePath()
            for i in 0..<6 {
                let angle = CGFloat.pi / 180.0 * CGFloat(60 * i)
                let point = CGPoint(x: center.x + size * cos(angle),
                                    y: center.y + size * sin(angle))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()

            // Clip to hex shape
            context.saveGState()
            context.addPath(path)
            context.clip()

            // Gradient fill (lighter top-left to darker bottom-right for 3D bevel)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradientColors = [terrain.colorLight.cgColor, terrain.color.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0]) {
                let startPt = CGPoint(x: center.x - size * 0.6, y: center.y - size * 0.6)
                let endPt = CGPoint(x: center.x + size * 0.6, y: center.y + size * 0.6)
                context.drawLinearGradient(gradient, start: startPt, end: endPt, options: [])
            }

            // Terrain detail overlays
            let rng = SeededRNG(seed: UInt64(variant &* 2654435761))
            drawTerrainDetails(context: context, terrain: terrain, center: center, size: size, rng: rng)

            context.restoreGState()
        }
        return SKTexture(image: image)
    }

    private static func drawTerrainDetails(context: CGContext, terrain: Terrain, center: CGPoint, size: CGFloat, rng: SeededRNG) {
        let rng = rng
        switch terrain {
        case .forest:
            // Tree dots — small dark circles
            let treeColor = SKColor(red: 0.08, green: 0.30, blue: 0.08, alpha: 0.7).cgColor
            context.setFillColor(treeColor)
            for _ in 0..<(6 + rng.next(bound: 4)) {
                let dx = CGFloat(rng.next(bound: Int(size))) - size / 2
                let dy = CGFloat(rng.next(bound: Int(size))) - size / 2
                let r: CGFloat = 2.5 + CGFloat(rng.next(bound: 2))
                context.fillEllipse(in: CGRect(x: center.x + dx - r, y: center.y + dy - r, width: r * 2, height: r * 2))
            }

        case .mountain:
            // Mountain peaks — small triangles
            let peakColor = SKColor(red: 0.75, green: 0.72, blue: 0.68, alpha: 0.6).cgColor
            context.setFillColor(peakColor)
            for _ in 0..<(2 + rng.next(bound: 2)) {
                let dx = CGFloat(rng.next(bound: Int(size * 0.8))) - size * 0.4
                let dy = CGFloat(rng.next(bound: Int(size * 0.6))) - size * 0.3
                let triSize: CGFloat = 5 + CGFloat(rng.next(bound: 4))
                let peak = CGMutablePath()
                peak.move(to: CGPoint(x: center.x + dx, y: center.y + dy - triSize))
                peak.addLine(to: CGPoint(x: center.x + dx - triSize * 0.7, y: center.y + dy + triSize * 0.4))
                peak.addLine(to: CGPoint(x: center.x + dx + triSize * 0.7, y: center.y + dy + triSize * 0.4))
                peak.closeSubpath()
                context.addPath(peak)
                context.fillPath()
            }
            // Snow caps
            context.setFillColor(SKColor(white: 1.0, alpha: 0.4).cgColor)
            for _ in 0..<(2 + rng.next(bound: 2)) {
                let dx = CGFloat(rng.next(bound: Int(size * 0.6))) - size * 0.3
                let dy = CGFloat(rng.next(bound: Int(size * 0.4))) - size * 0.4
                context.fillEllipse(in: CGRect(x: center.x + dx - 1.5, y: center.y + dy - 1.5, width: 3, height: 2))
            }

        case .water:
            // Wave lines
            let waveColor = SKColor(red: 0.30, green: 0.55, blue: 0.85, alpha: 0.4).cgColor
            context.setStrokeColor(waveColor)
            context.setLineWidth(1)
            for i in 0..<(2 + rng.next(bound: 2)) {
                let dy = CGFloat(i) * 8 - 8
                let wavePath = CGMutablePath()
                wavePath.move(to: CGPoint(x: center.x - size * 0.5, y: center.y + dy))
                for step in stride(from: -size * 0.5, to: size * 0.5, by: 4) {
                    let x = center.x + step
                    let y = center.y + dy + sin(step * 0.3) * 2.5
                    wavePath.addLine(to: CGPoint(x: x, y: y))
                }
                context.addPath(wavePath)
                context.strokePath()
            }

        case .marsh:
            // Reed lines — short vertical strokes
            let reedColor = SKColor(red: 0.30, green: 0.38, blue: 0.18, alpha: 0.5).cgColor
            context.setStrokeColor(reedColor)
            context.setLineWidth(1)
            for _ in 0..<(5 + rng.next(bound: 4)) {
                let dx = CGFloat(rng.next(bound: Int(size))) - size / 2
                let dy = CGFloat(rng.next(bound: Int(size * 0.8))) - size * 0.4
                let h: CGFloat = 3 + CGFloat(rng.next(bound: 3))
                context.move(to: CGPoint(x: center.x + dx, y: center.y + dy))
                context.addLine(to: CGPoint(x: center.x + dx + 1, y: center.y + dy - h))
                context.strokePath()
            }
            // Water puddle dots
            context.setFillColor(SKColor(red: 0.25, green: 0.40, blue: 0.55, alpha: 0.3).cgColor)
            for _ in 0..<(2 + rng.next(bound: 2)) {
                let dx = CGFloat(rng.next(bound: Int(size * 0.6))) - size * 0.3
                let dy = CGFloat(rng.next(bound: Int(size * 0.6))) - size * 0.3
                context.fillEllipse(in: CGRect(x: center.x + dx - 2, y: center.y + dy - 1, width: 4, height: 2))
            }

        case .flatLand:
            // Grass stipple dots
            let grassColor = SKColor(red: 0.40, green: 0.58, blue: 0.20, alpha: 0.3).cgColor
            context.setFillColor(grassColor)
            for _ in 0..<(4 + rng.next(bound: 3)) {
                let dx = CGFloat(rng.next(bound: Int(size))) - size / 2
                let dy = CGFloat(rng.next(bound: Int(size))) - size / 2
                context.fillEllipse(in: CGRect(x: center.x + dx - 0.5, y: center.y + dy - 0.5, width: 1.5, height: 1.5))
            }

        case .city:
            break
        }
    }

    /// Fog texture with subtle noise/cloud effect
    static func fogHexTexture(size: CGFloat, alpha: CGFloat) -> SKTexture {
        let diameter = size * 2 + 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        let image = renderer.image { ctx in
            let context = ctx.cgContext
            let center = CGPoint(x: diameter / 2, y: diameter / 2)

            let path = CGMutablePath()
            for i in 0..<6 {
                let angle = CGFloat.pi / 180.0 * CGFloat(60 * i)
                let point = CGPoint(x: center.x + size * cos(angle),
                                    y: center.y + size * sin(angle))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()

            context.saveGState()
            context.addPath(path)
            context.clip()

            // Dark base layer
            context.setFillColor(SKColor(white: 0.0, alpha: alpha * 0.85).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: diameter, height: diameter))

            // Haze/fog effect — soft radial gradient from edges
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let hazeColors = [
                SKColor(white: 0.15, alpha: alpha * 0.4).cgColor,
                SKColor(white: 0.05, alpha: alpha * 0.1).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: hazeColors, locations: [0.0, 1.0]) {
                context.drawRadialGradient(
                    gradient,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: size * 0.9,
                    options: []
                )
            }

            context.restoreGState()
        }
        return SKTexture(image: image)
    }

    static func circleTexture(size: CGFloat, color: SKColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        return SKTexture(image: image)
    }
}

/// Simple seeded RNG for deterministic texture variants
class SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    func next(bound: Int) -> Int {
        guard bound > 0 else { return 0 }
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(bound))
    }
}
