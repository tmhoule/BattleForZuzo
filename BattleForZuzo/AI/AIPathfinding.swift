import Foundation

class AIPathfinding {
    unowned let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    /// Find path from start to end, avoiding enemy units
    func findPath(from start: HexCoord, to end: HexCoord, for unit: Unit) -> [HexCoord] {
        guard let map = gameState.map else { return [] }
        return gameState.movementSystem?.findPath(from: start, to: end, for: unit, on: map) ?? []
    }

    /// Find the nearest coord of interest (neutral city, enemy, etc.)
    func nearestCoord(from origin: HexCoord, in candidates: [HexCoord]) -> HexCoord? {
        guard let topology = gameState.map?.topology else {
            return candidates.min(by: { origin.distance(to: $0) < origin.distance(to: $1) })
        }
        return candidates.min(by: { topology.distance(from: origin, to: $0) < topology.distance(from: origin, to: $1) })
    }
}
