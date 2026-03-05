import Foundation

class TurnManager {
    unowned let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    func endTurn() {
        gameState.clearSelection()

        // Move to next non-eliminated player
        repeat {
            gameState.currentPlayerIndex = (gameState.currentPlayerIndex + 1) % gameState.players.count
            if gameState.currentPlayerIndex == 0 {
                gameState.turnNumber += 1
            }
        } while gameState.currentPlayer?.isEliminated == true

        guard let currentPlayer = gameState.currentPlayer else { return }

        // Process start-of-turn for current player
        startTurn(for: currentPlayer)
    }

    private func startTurn(for player: Player) {
        // Reset unit movement
        let playerUnits = gameState.units(for: player.id)
        for unit in playerUnits {
            unit.resetForNewTurn()
        }

        // Heal units on friendly cities (+1 HP per turn)
        if let map = gameState.map {
            for unit in playerUnits {
                if let city = map.city(at: unit.position),
                   city.ownerID == player.id,
                   unit.hp < unit.type.maxHP {
                    unit.hp = min(unit.type.maxHP, unit.hp + 1)
                }
            }
        }

        // Process city production and conquest
        gameState.citySystem?.processCities(for: player.id)

        // Capture any cities occupied by this player's units
        checkCityConquests(for: player)

        // Update fog of war
        gameState.fogOfWarSystem?.updateVisibility(for: player)

        // Check victory conditions
        if let result = gameState.victorySystem?.checkVictory() {
            gameState.victoryState = result
            if result != .ongoing {
                gameState.gamePhase = .gameOver
                return
            }
        }

        if player.isHuman {
            GamePersistence.save(gameState)
            gameState.statusMessage = "Turn \(gameState.turnNumber) - Your turn"
        } else {
            gameState.statusMessage = "\(player.name) is thinking..."
            // AI takes its turn
            Task { @MainActor in
                await gameState.aiController?.executeTurn(for: player)
                endTurn()
            }
        }
    }

    private func checkCityConquests(for player: Player) {
        guard let map = gameState.map else { return }
        let playerUnits = gameState.units(for: player.id)

        for unit in playerUnits {
            if let city = map.city(at: unit.position), city.ownerID != player.id {
                gameState.citySystem?.checkConquest(at: unit.position, by: player.id)
            }
        }
    }
}
