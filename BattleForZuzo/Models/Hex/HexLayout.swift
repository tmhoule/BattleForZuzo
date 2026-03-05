import Foundation
import CoreGraphics

/// Converts between axial hex coordinates and pixel positions.
/// Uses flat-top hex orientation.
struct HexLayout {
    let size: CGFloat  // hex radius (center to vertex)

    /// Width of a single hex
    var hexWidth: CGFloat { size * 2 }

    /// Height of a single hex
    var hexHeight: CGFloat { size * sqrt(3) }

    /// Horizontal distance between hex centers
    var horizontalSpacing: CGFloat { size * 1.5 }

    /// Vertical distance between hex centers
    var verticalSpacing: CGFloat { size * sqrt(3) }

    // MARK: - Coordinate Conversion

    /// Convert axial hex coordinate to pixel position
    func hexToPixel(_ hex: HexCoord) -> CGPoint {
        let x = size * (1.5 * Double(hex.q))
        let y = size * (sqrt(3) * (Double(hex.r) + Double(hex.q) * 0.5))
        return CGPoint(x: x, y: y)
    }

    /// Convert pixel position to axial hex coordinate
    func pixelToHex(_ point: CGPoint) -> HexCoord {
        let q = (2.0 / 3.0 * Double(point.x)) / Double(size)
        let r = (-1.0 / 3.0 * Double(point.x) + sqrt(3) / 3.0 * Double(point.y)) / Double(size)
        return HexCoord.round(fq: q, fr: r)
    }

    /// Corner positions of a hex (flat-top)
    func hexCorners(_ hex: HexCoord) -> [CGPoint] {
        let center = hexToPixel(hex)
        return (0..<6).map { i in
            let angle = CGFloat.pi / 180.0 * CGFloat(60 * i)
            return CGPoint(
                x: center.x + size * cos(angle),
                y: center.y + size * sin(angle)
            )
        }
    }

    // MARK: - Offset Conversion (for SKTileMapNode)

    /// Convert axial to offset coordinates (even-q for flat-top)
    static func axialToOffset(q: Int, r: Int) -> (col: Int, row: Int) {
        let col = q
        let row = r + (q + (q & 1)) / 2
        return (col, row)
    }

    /// Convert offset coordinates to axial (even-q for flat-top)
    static func offsetToAxial(col: Int, row: Int) -> HexCoord {
        let q = col
        let r = row - (col + (col & 1)) / 2
        return HexCoord(q: q, r: r)
    }

    // MARK: - Map Bounds

    /// Calculate the pixel bounds for a map of given size
    func mapBounds(width: Int, height: Int) -> CGRect {
        let minCoord = HexCoord(q: 0, r: 0)
        let maxCoord = HexCoord(q: width - 1, r: height - 1)
        let minPixel = hexToPixel(minCoord)
        let maxPixel = hexToPixel(maxCoord)
        let padding = size * 8
        return CGRect(
            x: minPixel.x - padding,
            y: minPixel.y - padding,
            width: maxPixel.x - minPixel.x + padding * 2,
            height: maxPixel.y - minPixel.y + padding * 2
        )
    }
}
