import Foundation

enum HexDirection: Int, CaseIterable, Sendable {
    case east = 0
    case northEast = 1
    case northWest = 2
    case west = 3
    case southWest = 4
    case southEast = 5

    var opposite: HexDirection {
        HexDirection(rawValue: (rawValue + 3) % 6)!
    }
}
