import Foundation

/// Axial hex coordinate (q, r) with cube coordinate support.
/// Uses flat-top hex orientation.
struct HexCoord: Hashable, Codable, Sendable {
    let q: Int
    let r: Int

    var s: Int { -q - r }

    static let zero = HexCoord(q: 0, r: 0)

    // MARK: - Neighbors

    static let directions: [HexCoord] = [
        HexCoord(q: 1, r: 0),   // East
        HexCoord(q: 1, r: -1),  // NE
        HexCoord(q: 0, r: -1),  // NW
        HexCoord(q: -1, r: 0),  // West
        HexCoord(q: -1, r: 1),  // SW
        HexCoord(q: 0, r: 1),   // SE
    ]

    func neighbor(_ direction: HexDirection) -> HexCoord {
        let d = HexCoord.directions[direction.rawValue]
        return HexCoord(q: q + d.q, r: r + d.r)
    }

    var neighbors: [HexCoord] {
        HexCoord.directions.map { HexCoord(q: q + $0.q, r: r + $0.r) }
    }

    // MARK: - Distance

    func distance(to other: HexCoord) -> Int {
        let dq = abs(q - other.q)
        let dr = abs(r - other.r)
        let ds = abs(s - other.s)
        return max(dq, dr, ds)
    }

    // MARK: - Ring & Range

    func ring(radius: Int) -> [HexCoord] {
        guard radius > 0 else { return [self] }
        var results: [HexCoord] = []
        var current = HexCoord(q: q + HexCoord.directions[4].q * radius,
                               r: r + HexCoord.directions[4].r * radius)
        for direction in 0..<6 {
            for _ in 0..<radius {
                results.append(current)
                let d = HexCoord.directions[direction]
                current = HexCoord(q: current.q + d.q, r: current.r + d.r)
            }
        }
        return results
    }

    func hexesInRange(radius: Int) -> [HexCoord] {
        var results: [HexCoord] = []
        for dq in -radius...radius {
            let rMin = max(-radius, -dq - radius)
            let rMax = min(radius, -dq + radius)
            for dr in rMin...rMax {
                results.append(HexCoord(q: q + dq, r: r + dr))
            }
        }
        return results
    }

    // MARK: - Arithmetic

    static func + (lhs: HexCoord, rhs: HexCoord) -> HexCoord {
        HexCoord(q: lhs.q + rhs.q, r: lhs.r + rhs.r)
    }

    static func - (lhs: HexCoord, rhs: HexCoord) -> HexCoord {
        HexCoord(q: lhs.q - rhs.q, r: lhs.r - rhs.r)
    }

    static func * (lhs: HexCoord, rhs: Int) -> HexCoord {
        HexCoord(q: lhs.q * rhs, r: lhs.r * rhs)
    }

    // MARK: - Line drawing

    static func line(from a: HexCoord, to b: HexCoord) -> [HexCoord] {
        let n = a.distance(to: b)
        guard n > 0 else { return [a] }
        var results: [HexCoord] = []
        for i in 0...n {
            let t = Double(i) / Double(n)
            let fq = Double(a.q) * (1.0 - t) + Double(b.q) * t
            let fr = Double(a.r) * (1.0 - t) + Double(b.r) * t
            results.append(HexCoord.round(fq: fq, fr: fr))
        }
        return results
    }

    static func round(fq: Double, fr: Double) -> HexCoord {
        let fs = -fq - fr
        var rq = Darwin.round(fq)
        var rr = Darwin.round(fr)
        let rs = Darwin.round(fs)
        let qDiff = abs(rq - fq)
        let rDiff = abs(rr - fr)
        let sDiff = abs(rs - fs)
        if qDiff > rDiff && qDiff > sDiff {
            rq = -rr - rs
        } else if rDiff > sDiff {
            rr = -rq - rs
        }
        return HexCoord(q: Int(rq), r: Int(rr))
    }
}

extension HexCoord: CustomStringConvertible {
    var description: String { "(\(q),\(r))" }
}
