import Foundation

class AIController {
    unowned let gameState: GameState
    private let strategy: AIStrategy
    private let tactical: AITactical
    private let pathfinding: AIPathfinding

    init(gameState: GameState) {
        self.gameState = gameState
        self.strategy = AIStrategy(gameState: gameState)
        self.tactical = AITactical(gameState: gameState)
        self.pathfinding = AIPathfinding(gameState: gameState)
    }

    @MainActor
    func executeTurn(for player: Player) async {
        guard let map = gameState.map else { return }

        let mode = strategy.determineMode(for: player)
        let units = gameState.units(for: player.id)

        // Process each unit
        for unit in units {
            guard unit.isAlive && unit.canMove else { continue }

            // Small delay so human can see AI moves
            try? await Task.sleep(nanoseconds: UInt64(Constants.aiMoveDelay * 1_000_000_000))

            let action = tactical.decidAction(for: unit, mode: mode, player: player)
            await executeAction(action, for: unit)
        }

        // Handle city production
        let cities = map.citiesForPlayer(player.id)
        for city in cities {
            if city.productionQueue == nil {
                let unitType = strategy.chooseProduction(for: city, player: player)
                gameState.citySystem?.setProduction(for: city, unitType: unitType)
            }
        }
    }

    @MainActor
    private func executeAction(_ action: AIAction, for unit: Unit) async {
        switch action {
        case .move(let destination):
            let path = gameState.movementSystem?.findPath(
                from: unit.position, to: destination, for: unit, on: gameState.map!
            ) ?? []
            if !path.isEmpty {
                _ = gameState.moveUnit(unit, to: destination)
            }

        case .attack(let targetID):
            if let target = gameState.units.first(where: { $0.id == targetID }) {
                _ = gameState.attackUnit(unit, target: target)
            }

        case .moveAndAttack(let moveTarget, let attackTargetID):
            _ = gameState.moveUnit(unit, to: moveTarget)
            try? await Task.sleep(nanoseconds: UInt64(Constants.aiMoveDelay * 0.5 * 1_000_000_000))
            if let target = gameState.units.first(where: { $0.id == attackTargetID }) {
                _ = gameState.attackUnit(unit, target: target)
            }

        case .buildRoad:
            gameState.buildRoad(with: unit)

        case .hold:
            break
        }
    }
}

enum AIAction {
    case move(HexCoord)
    case attack(UUID)
    case moveAndAttack(HexCoord, UUID)
    case buildRoad
    case hold
}

enum AIMode {
    case expand    // Grab neutral cities
    case attack    // Push enemy territory
    case defend    // Protect threatened cities
}
