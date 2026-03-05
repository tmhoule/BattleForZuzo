import Foundation

/// Encapsulates cylindrical (east-west) map wrapping logic.
/// The q-axis (columns) wraps modulo `width`; rows are clamped.
struct MapTopology: Codable {
    let width: Int
    let height: Int
    let wrapping: Bool

    init(width: Int, height: Int, wrapping: Bool = true) {
        self.width = width
        self.height = height
        self.wrapping = wrapping
    }

    /// Normalize an axial coordinate so the column wraps around.
    func normalize(_ coord: HexCoord) -> HexCoord {
        guard wrapping else { return coord }

        // Convert to offset space, wrap column, convert back
        let offset = HexLayout.axialToOffset(q: coord.q, r: coord.r)
        var col = offset.col % width
        if col < 0 { col += width }
        let row = offset.row
        return HexLayout.offsetToAxial(col: col, row: row)
    }

    /// Check if a coordinate is valid (within vertical bounds; horizontal wraps).
    func isValid(_ coord: HexCoord) -> Bool {
        let offset = HexLayout.axialToOffset(q: coord.q, r: coord.r)
        let col = wrapping ? ((offset.col % width + width) % width) : offset.col
        return col >= 0 && col < width && offset.row >= 0 && offset.row < height
    }

    /// Minimum distance accounting for wrapping.
    func distance(from a: HexCoord, to b: HexCoord) -> Int {
        guard wrapping else { return a.distance(to: b) }

        let direct = a.distance(to: b)

        // Try wrapped variants: shift b by +width and -width in offset col
        let offsetB = HexLayout.axialToOffset(q: b.q, r: b.r)

        let wrappedRight = HexLayout.offsetToAxial(col: offsetB.col + width, row: offsetB.row)
        let wrappedLeft = HexLayout.offsetToAxial(col: offsetB.col - width, row: offsetB.row)

        let distRight = a.distance(to: wrappedRight)
        let distLeft = a.distance(to: wrappedLeft)

        return min(direct, distRight, distLeft)
    }

    /// Get all valid neighbors, with wrapping normalization.
    func neighbors(of coord: HexCoord) -> [HexCoord] {
        coord.neighbors.compactMap { neighbor in
            let normalized = normalize(neighbor)
            return isValid(normalized) ? normalized : nil
        }
    }
}
