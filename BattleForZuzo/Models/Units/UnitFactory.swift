import Foundation

struct UnitFactory {
    static func createUnit(type: UnitType, ownerID: UUID, position: HexCoord) -> Unit {
        Unit(type: type, ownerID: ownerID, position: position)
    }

    static func createStartingUnits(for playerID: UUID, near city: City, on map: GameMap) -> [Unit] {
        var units: [Unit] = []

        // Give each player a tank at their starting city
        let tank = createUnit(type: .tank, ownerID: playerID, position: city.position)
        units.append(tank)

        // Place a construction unit nearby
        let neighbors = map.neighbors(of: city.position)
        if let landNeighbor = neighbors.first(where: { coord in
            guard let tile = map.tile(at: coord) else { return false }
            return tile.isPassableByLand
        }) {
            let construction = createUnit(type: .construction, ownerID: playerID, position: landNeighbor)
            units.append(construction)
        }

        return units
    }
}
