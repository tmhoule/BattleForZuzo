import Foundation

class VictorySystem {
    unowned let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    /// Check victory conditions:
    /// - A player with 0 cities is eliminated (even if units remain)
    /// - A player who owns all cities wins (domination)
    /// - Last player standing wins
    func checkVictory() -> VictoryState {
        guard let map = gameState.map else { return .ongoing }

        let allCities = Array(map.cities.values)
        let totalCities = allCities.count

        var activePlayers: [Player] = []

        for player in gameState.players {
            guard !player.isEliminated else { continue }

            let cities = map.citiesForPlayer(player.id)

            // A player with no cities is eliminated
            if cities.isEmpty {
                player.isEliminated = true
                if player.isHuman {
                    return .defeat
                }
                continue
            }

            // Check domination — player owns all cities
            if cities.count == totalCities {
                if player.isHuman {
                    return .victory(playerName: player.name)
                } else {
                    return .defeat
                }
            }

            activePlayers.append(player)
        }

        // If only one player remains, they win
        if activePlayers.count == 1 {
            let winner = activePlayers[0]
            if winner.isHuman {
                return .victory(playerName: winner.name)
            } else {
                return .defeat
            }
        }

        // Check if human is eliminated
        if let human = gameState.humanPlayer, human.isEliminated {
            return .defeat
        }

        return .ongoing
    }
}
