import Foundation

class GameMap {
    let width: Int
    let height: Int
    var tiles: HexGrid<Tile>
    var cities: [UUID: City] = [:]
    var topology: MapTopology

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.topology = MapTopology(width: width, height: height, wrapping: false)
        self.tiles = HexGrid<Tile>(width: width, height: height)
        self.tiles.topology = self.topology
    }

    func tile(at coord: HexCoord) -> Tile? {
        tiles[coord]
    }

    func setTile(_ tile: Tile, at coord: HexCoord) {
        tiles[coord] = tile
    }

    func isValid(_ coord: HexCoord) -> Bool {
        topology.isValid(coord)
    }

    func normalize(_ coord: HexCoord) -> HexCoord {
        topology.normalize(coord)
    }

    func city(at coord: HexCoord) -> City? {
        let norm = normalize(coord)
        guard let tile = tiles[norm], let cityID = tile.cityID else { return nil }
        return cities[cityID]
    }

    func citiesForPlayer(_ playerID: UUID) -> [City] {
        cities.values.filter { $0.ownerID == playerID }
    }

    func allCityCoords() -> [HexCoord] {
        cities.values.map { $0.position }
    }

    var allCoords: [HexCoord] {
        tiles.allCoords
    }

    func neighbors(of coord: HexCoord) -> [HexCoord] {
        topology.neighbors(of: coord)
    }

    func isWaterAdjacent(_ coord: HexCoord) -> Bool {
        neighbors(of: coord).contains { tile(at: $0)?.terrain.isWater == true }
    }
}
