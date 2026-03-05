import Foundation

/// A generic container for hex-grid data, keyed by axial coordinates.
struct HexGrid<T> {
    let width: Int
    let height: Int
    var topology: MapTopology
    private var storage: [HexCoord: T] = [:]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.topology = MapTopology(width: width, height: height, wrapping: false)
    }

    /// All valid coordinates in this grid
    var allCoords: [HexCoord] {
        var coords: [HexCoord] = []
        coords.reserveCapacity(width * height)
        for col in 0..<width {
            for row in 0..<height {
                coords.append(HexLayout.offsetToAxial(col: col, row: row))
            }
        }
        return coords
    }

    func contains(_ coord: HexCoord) -> Bool {
        topology.isValid(coord)
    }

    subscript(coord: HexCoord) -> T? {
        get { storage[topology.normalize(coord)] }
        set { storage[topology.normalize(coord)] = newValue }
    }

    subscript(q: Int, r: Int) -> T? {
        get {
            let normalized = topology.normalize(HexCoord(q: q, r: r))
            return storage[normalized]
        }
        set {
            let normalized = topology.normalize(HexCoord(q: q, r: r))
            storage[normalized] = newValue
        }
    }

    var count: Int { storage.count }

    var values: Dictionary<HexCoord, T>.Values { storage.values }
    var keys: Dictionary<HexCoord, T>.Keys { storage.keys }

    mutating func removeAll() {
        storage.removeAll()
    }

    func filter(_ isIncluded: (HexCoord, T) -> Bool) -> [(HexCoord, T)] {
        storage.filter { isIncluded($0.key, $0.value) }
    }
}
