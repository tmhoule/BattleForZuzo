import Foundation

class CitySystem {
    unowned let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    /// Process all cities for the given player at start of their turn
    func processCities(for playerID: UUID) {
        guard let map = gameState.map else { return }

        let playerCities = map.citiesForPlayer(playerID)
        for city in playerCities {
            // Check for conquest: enemy unit on city
            if let occupant = gameState.unit(at: city.position), occupant.ownerID != playerID {
                conquerCity(city, by: occupant.ownerID)
                continue
            }

            // Advance production
            if let completedType = city.advanceProduction() {
                spawnUnit(type: completedType, at: city)
            }
        }
    }

    /// Check and process conquest for neutral cities too
    func checkConquest(at coord: HexCoord, by playerID: UUID) {
        guard let map = gameState.map,
              let city = map.city(at: coord) else { return }

        if city.ownerID != playerID {
            conquerCity(city, by: playerID)
        }
    }

    private func conquerCity(_ city: City, by newOwnerID: UUID) {
        city.ownerID = newOwnerID
        city.productionQueue = nil
        city.productionProgress = 0

        if let player = gameState.players.first(where: { $0.id == newOwnerID }) {
            gameState.statusMessage = "\(player.name) captured \(city.name)!"
            if player.isHuman {
                gameState.tutorial.onCityCapture()
            }
        }
    }

    private func spawnUnit(type: UnitType, at city: City) {
        guard let map = gameState.map else { return }

        // Try to spawn at city location first
        let spawnCoord: HexCoord?
        if gameState.unit(at: city.position) == nil {
            spawnCoord = city.position
        } else {
            // Find adjacent empty hex
            spawnCoord = map.neighbors(of: city.position).first { coord in
                guard let tile = map.tile(at: coord) else { return false }
                guard gameState.unit(at: coord) == nil else { return false }
                let unit = Unit(type: type, ownerID: city.ownerID!, position: coord)
                return unit.canTraverse(terrain: tile.terrain)
            }
        }

        if let coord = spawnCoord, let ownerID = city.ownerID {
            let unit = UnitFactory.createUnit(type: type, ownerID: ownerID, position: coord)
            unit.movementRemaining = 0  // Can't move on spawn turn
            gameState.units.append(unit)

            let player = gameState.players.first { $0.id == ownerID }
            if player?.isHuman == true {
                gameState.statusMessage = "\(city.name) completed \(type.displayName)"
            }
        }
    }

    /// Set production for a city
    func setProduction(for city: City, unitType: UnitType) {
        city.productionQueue = unitType
        city.productionProgress = 0
        gameState.tutorial.onProductionSet()
    }
}
