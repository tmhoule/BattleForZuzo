import Foundation
import Combine
import SpriteKit

class GameState: ObservableObject {
    // MARK: - Published State
    @Published var map: GameMap?
    @Published var players: [Player] = []
    @Published var units: [Unit] = []
    @Published var currentPlayerIndex: Int = 0
    @Published var turnNumber: Int = 1
    @Published var selectedUnit: Unit?
    @Published var selectedCity: City?
    @Published var reachableHexes: Set<HexCoord> = []
    @Published var attackableHexes: Set<HexCoord> = []
    @Published var gamePhase: GamePhase = .setup
    @Published var victoryState: VictoryState = .ongoing
    @Published var statusMessage: String = ""
    @Published var showCityPanel: Bool = false
    @Published var showUnitPanel: Bool = false

    // MARK: - Systems
    var movementSystem: MovementSystem?
    var combatSystem: CombatSystem?
    var citySystem: CitySystem?
    var turnManager: TurnManager?
    var fogOfWarSystem: FogOfWarSystem?
    var victorySystem: VictorySystem?
    var aiController: AIController?
    let tutorial = TutorialSystem()

    // MARK: - Computed Properties

    var currentPlayer: Player? {
        guard currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }

    var humanPlayer: Player? {
        players.first { $0.isHuman }
    }

    var isHumanTurn: Bool {
        currentPlayer?.isHuman == true
    }

    func units(for playerID: UUID) -> [Unit] {
        units.filter { $0.ownerID == playerID && $0.isAlive && !$0.isLoaded }
    }

    func unit(at coord: HexCoord) -> Unit? {
        let norm = map?.normalize(coord) ?? coord
        return units.first { $0.position == norm && $0.isAlive && !$0.isLoaded }
    }

    func units(at coord: HexCoord) -> [Unit] {
        let norm = map?.normalize(coord) ?? coord
        return units.filter { $0.position == norm && $0.isAlive }
    }

    // MARK: - Setup

    func setupGame(mapSize: Constants.MapSize, mapType: Constants.MapType, playerCount: Int) {
        let generator = MapGenerator(mapSize: mapSize, mapType: mapType)
        let generatedMap = generator.generate()
        self.map = generatedMap

        // Create players
        players = []
        for i in 0..<playerCount {
            let player = Player(
                name: i == 0 ? "You" : "AI \(i)",
                color: Constants.playerColors[i],
                isHuman: i == 0
            )
            players.append(player)
        }

        // Assign starting cities to players (maximally far apart)
        assignStartingPositions(on: generatedMap)

        // Initialize systems
        movementSystem = MovementSystem(gameState: self)
        combatSystem = CombatSystem(gameState: self)
        citySystem = CitySystem(gameState: self)
        fogOfWarSystem = FogOfWarSystem(gameState: self)
        victorySystem = VictorySystem(gameState: self)
        turnManager = TurnManager(gameState: self)
        aiController = AIController(gameState: self)

        // Initial fog reveal
        fogOfWarSystem?.updateVisibility(for: players[0])
        for player in players {
            fogOfWarSystem?.updateVisibility(for: player)
        }

        currentPlayerIndex = 0
        turnNumber = 1
        gamePhase = .playing
        statusMessage = "Your turn - select a unit"
    }

    private func assignStartingPositions(on map: GameMap) {
        let allCities = Array(map.cities.values)
        guard !allCities.isEmpty else { return }

        var assignedCities: [City] = []

        // Pick first city randomly
        if let first = allCities.randomElement() {
            assignedCities.append(first)
        }

        // For remaining players, pick city farthest from all assigned cities
        for _ in 1..<players.count {
            var bestCity: City?
            var bestMinDist = -1

            for city in allCities {
                guard !assignedCities.contains(where: { $0.id == city.id }) else { continue }
                let minDist = assignedCities.map { map.topology.distance(from: city.position, to: $0.position) }.min() ?? 0
                if minDist > bestMinDist {
                    bestMinDist = minDist
                    bestCity = city
                }
            }

            if let city = bestCity {
                assignedCities.append(city)
            }
        }

        // Assign cities and spawn starting units
        for (i, player) in players.enumerated() {
            guard i < assignedCities.count else { break }
            let city = assignedCities[i]
            city.ownerID = player.id

            let startingUnits = UnitFactory.createStartingUnits(for: player.id, near: city, on: map)
            units.append(contentsOf: startingUnits)
        }
    }

    // MARK: - Selection

    func selectUnit(_ unit: Unit?) {
        selectedUnit = unit
        selectedCity = nil
        showUnitPanel = unit != nil
        showCityPanel = false

        if let unit = unit, unit.ownerID == currentPlayer?.id {
            reachableHexes = movementSystem?.reachableHexes(for: unit) ?? []
            attackableHexes = movementSystem?.attackableHexes(for: unit) ?? []
            tutorial.onUnitSelected()
        } else {
            reachableHexes = []
            attackableHexes = []
        }
    }

    func selectCity(_ city: City?) {
        selectedCity = city
        selectedUnit = nil
        showCityPanel = city != nil
        showUnitPanel = false
        reachableHexes = []
        attackableHexes = []
    }

    func clearSelection() {
        selectedUnit = nil
        selectedCity = nil
        showUnitPanel = false
        showCityPanel = false
        reachableHexes = []
        attackableHexes = []
    }

    /// Auto-cycle to next unmoved unit after an action completes
    func selectNextAvailableUnit() {
        guard let player = currentPlayer, player.isHuman else { return }
        let playerUnits = units(for: player.id)
        let available = playerUnits.filter { $0.canMove || $0.canAttack }
        guard let next = available.first else {
            clearSelection()
            return
        }
        selectUnit(next)
    }

    // MARK: - Actions

    func moveUnit(_ unit: Unit, to destination: HexCoord) -> Bool {
        guard let result = movementSystem?.moveUnit(unit, to: destination) else { return false }
        if result {
            // Check for city at destination
            if let city = map?.city(at: destination), city.isNeutral || city.ownerID != unit.ownerID {
                // City capture handled in turn resolution
            }
            fogOfWarSystem?.updateVisibility(for: currentPlayer!)
            tutorial.onUnitMoved()
            objectWillChange.send()
        }
        return result
    }

    func attackUnit(_ attacker: Unit, target: Unit) -> CombatResult? {
        guard let result = combatSystem?.resolveAttack(attacker: attacker, defender: target) else { return nil }

        // Remove dead units
        units.removeAll { $0.isDead }

        fogOfWarSystem?.updateVisibility(for: currentPlayer!)
        tutorial.onAttack()

        // Check victory after combat
        if let victoryResult = victorySystem?.checkVictory(), victoryResult != .ongoing {
            victoryState = victoryResult
            gamePhase = .gameOver
        }

        objectWillChange.send()
        return result
    }

    func buildRoad(with unit: Unit) {
        guard unit.type == .construction, unit.movementRemaining >= 2 else { return }
        guard let map = map else { return }
        guard var tile = map.tile(at: unit.position) else { return }
        guard tile.terrain != .deepWater, !tile.hasRoad else { return }
        tile.hasRoad = true
        map.setTile(tile, at: unit.position)
        unit.movementRemaining = 0
        statusMessage = "Road built!"
        objectWillChange.send()
    }

    func endTurn() {
        turnManager?.endTurn()
    }

    func removeUnit(_ unit: Unit) {
        units.removeAll { $0.id == unit.id }
    }

    // MARK: - Restore from Save

    func restoreFrom(_ save: SaveData) {
        // Rebuild map
        let restoredMap = GameMap(width: save.mapWidth, height: save.mapHeight)
        restoredMap.topology = MapTopology(width: save.mapWidth, height: save.mapHeight, wrapping: false)
        for entry in save.tileEntries {
            let coord = HexCoord(q: entry.q, r: entry.r)
            restoredMap.setTile(entry.tile, at: coord)
        }
        for city in save.cities {
            restoredMap.cities[city.id] = city
        }
        self.map = restoredMap

        // Restore state
        self.players = save.players
        self.units = save.units
        self.currentPlayerIndex = save.currentPlayerIndex
        self.turnNumber = save.turnNumber

        // Initialize systems
        movementSystem = MovementSystem(gameState: self)
        combatSystem = CombatSystem(gameState: self)
        citySystem = CitySystem(gameState: self)
        fogOfWarSystem = FogOfWarSystem(gameState: self)
        victorySystem = VictorySystem(gameState: self)
        turnManager = TurnManager(gameState: self)
        aiController = AIController(gameState: self)

        // Update fog for all players
        for player in players {
            fogOfWarSystem?.updateVisibility(for: player)
        }

        gamePhase = .playing
        statusMessage = "Turn \(turnNumber) - Your turn"
    }
}

// MARK: - Enums

enum GamePhase: Equatable, Codable {
    case setup
    case playing
    case gameOver
}

enum VictoryState: Equatable, Codable {
    case ongoing
    case victory(playerName: String)
    case defeat

    enum CodingKeys: String, CodingKey {
        case type, playerName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "victory":
            let name = try c.decode(String.self, forKey: .playerName)
            self = .victory(playerName: name)
        case "defeat":
            self = .defeat
        default:
            self = .ongoing
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ongoing:
            try c.encode("ongoing", forKey: .type)
        case .victory(let name):
            try c.encode("victory", forKey: .type)
            try c.encode(name, forKey: .playerName)
        case .defeat:
            try c.encode("defeat", forKey: .type)
        }
    }
}
