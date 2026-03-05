import Foundation

struct TileEntry: Codable {
    let q: Int
    let r: Int
    let tile: Tile
}

struct SaveData: Codable {
    let mapWidth: Int
    let mapHeight: Int
    let tileEntries: [TileEntry]
    let cities: [City]
    let players: [Player]
    let units: [Unit]
    let currentPlayerIndex: Int
    let turnNumber: Int
    let saveDate: Date
}

enum GamePersistence {
    static var saveURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("battleforzuzo_save.json")
    }

    static var hasSavedGame: Bool {
        FileManager.default.fileExists(atPath: saveURL.path)
    }

    static func save(_ gameState: GameState) {
        guard gameState.gamePhase == .playing,
              let map = gameState.map else { return }

        var tileEntries: [TileEntry] = []
        for coord in map.allCoords {
            if let tile = map.tile(at: coord) {
                tileEntries.append(TileEntry(q: coord.q, r: coord.r, tile: tile))
            }
        }

        let saveData = SaveData(
            mapWidth: map.width,
            mapHeight: map.height,
            tileEntries: tileEntries,
            cities: Array(map.cities.values),
            players: gameState.players,
            units: gameState.units,
            currentPlayerIndex: gameState.currentPlayerIndex,
            turnNumber: gameState.turnNumber,
            saveDate: Date()
        )

        do {
            let data = try JSONEncoder().encode(saveData)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("Save failed: \(error)")
        }
    }

    static func load() -> SaveData? {
        guard hasSavedGame else { return nil }
        do {
            let data = try Data(contentsOf: saveURL)
            return try JSONDecoder().decode(SaveData.self, from: data)
        } catch {
            print("Load failed: \(error)")
            return nil
        }
    }

    static func deleteSave() {
        try? FileManager.default.removeItem(at: saveURL)
    }
}
