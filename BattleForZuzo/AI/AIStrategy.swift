import Foundation

class AIStrategy {
    unowned let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    func determineMode(for player: Player) -> AIMode {
        guard let map = gameState.map else { return .expand }

        let ownCities = map.citiesForPlayer(player.id)
        let ownUnits = gameState.units(for: player.id)
        let neutralCities = map.cities.values.filter { $0.isNeutral }

        // If there are neutral cities nearby, expand
        if !neutralCities.isEmpty && ownCities.count < 5 {
            return .expand
        }

        // If we have threatened cities, defend
        let topo = map.topology
        let threatened = ownCities.filter { city in
            let nearbyEnemies = gameState.units.filter { unit in
                unit.ownerID != player.id && unit.isAlive &&
                topo.distance(from: unit.position, to: city.position) <= 3
            }
            return !nearbyEnemies.isEmpty
        }

        if !threatened.isEmpty && ownUnits.count <= threatened.count * 2 {
            return .defend
        }

        // Otherwise attack
        return .attack
    }

    func chooseProduction(for city: City, player: Player) -> UnitType {
        let available = city.availableProductions
        guard !available.isEmpty else { return .tank }

        let ownUnits = gameState.units(for: player.id)
        let tankCount = ownUnits.filter { $0.type == .tank }.count
        let artilleryCount = ownUnits.filter { $0.type == .artillery }.count
        let navalCount = ownUnits.filter { $0.type == .submarine || $0.type == .carrier }.count

        // Balance: prefer tanks, then artillery, then naval
        if city.isCoastal && navalCount < 2 && available.contains(.submarine) {
            return .submarine
        }

        if artilleryCount < tankCount && available.contains(.artillery) {
            return .artillery
        }

        if available.contains(.airplane) && ownUnits.filter({ $0.type == .airplane }).count < 2 {
            return .airplane
        }

        // Occasionally produce a construction unit for road building
        let constructionCount = ownUnits.filter { $0.type == .construction }.count
        let combatCount = ownUnits.filter { $0.type.canAttack }.count
        if constructionCount < 2 && combatCount > 4 && available.contains(.construction) {
            return .construction
        }

        return available.contains(.tank) ? .tank : available[0]
    }
}
