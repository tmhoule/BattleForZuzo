import Foundation

class Unit: Identifiable, Codable {
    let id: UUID
    let type: UnitType
    var ownerID: UUID
    var position: HexCoord
    var hp: Int
    var movementRemaining: Double
    var hasAttacked: Bool = false

    // Carrier support
    var carriedUnits: [Unit] = []
    var isLoaded: Bool = false  // true if this unit is inside a carrier

    init(id: UUID = UUID(), type: UnitType, ownerID: UUID, position: HexCoord) {
        self.id = id
        self.type = type
        self.ownerID = ownerID
        self.position = position
        self.hp = type.maxHP
        self.movementRemaining = Double(type.movement)
    }

    var isAlive: Bool { hp > 0 }
    var canMove: Bool { movementRemaining > 0 && !isLoaded }
    var canAttack: Bool { type.canAttack && !hasAttacked && movementRemaining > 0 && !isLoaded }
    var isDead: Bool { hp <= 0 }
    var canBuildRoad: Bool { type == .construction && movementRemaining >= 2 && !isLoaded }

    func resetForNewTurn() {
        movementRemaining = Double(type.movement)
        hasAttacked = false
    }

    func canTraverse(terrain: Terrain) -> Bool {
        switch type.terrainAccess {
        case .land:
            if type == .tank { return terrain.isLand }  // Tanks cross all land including mountains
            if type == .construction { return true }  // Construction crosses all terrain (builds bridges on water)
            return terrain.isLand && terrain != .mountain
        case .water: return terrain.isWater
        case .any: return true
        }
    }

    /// Movement cost for this unit on given terrain (tanks have uniform land cost)
    func movementCost(for terrain: Terrain) -> Double {
        if type == .airplane { return 1 }  // Flat cost, ignores terrain
        if type == .tank && terrain.isLand { return 1 }
        if type == .construction {
            if terrain == .mountain { return 2 }
            if terrain == .water { return 2 }
        }
        return Double(terrain.movementCost)
    }

    func takeDamage(_ amount: Int) {
        hp = max(0, hp - amount)
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, type, ownerID, position, hp, movementRemaining, hasAttacked, carriedUnits, isLoaded
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        type = try c.decode(UnitType.self, forKey: .type)
        ownerID = try c.decode(UUID.self, forKey: .ownerID)
        position = try c.decode(HexCoord.self, forKey: .position)
        hp = try c.decode(Int.self, forKey: .hp)
        movementRemaining = try c.decode(Double.self, forKey: .movementRemaining)
        hasAttacked = try c.decode(Bool.self, forKey: .hasAttacked)
        carriedUnits = try c.decode([Unit].self, forKey: .carriedUnits)
        isLoaded = try c.decode(Bool.self, forKey: .isLoaded)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(ownerID, forKey: .ownerID)
        try c.encode(position, forKey: .position)
        try c.encode(hp, forKey: .hp)
        try c.encode(movementRemaining, forKey: .movementRemaining)
        try c.encode(hasAttacked, forKey: .hasAttacked)
        try c.encode(carriedUnits, forKey: .carriedUnits)
        try c.encode(isLoaded, forKey: .isLoaded)
    }

    /// Check if this unit can load onto a carrier at the given position
    func canLoadOnto(_ carrier: Unit) -> Bool {
        guard carrier.type.canCarryUnits else { return false }
        guard carrier.ownerID == ownerID else { return false }
        guard carrier.carriedUnits.count < carrier.type.carrierCapacity else { return false }
        guard type.terrainAccess == .land else { return false }
        guard position.distance(to: carrier.position) <= 1 else { return false }
        return true
    }
}

extension Unit: Equatable {
    static func == (lhs: Unit, rhs: Unit) -> Bool {
        lhs.id == rhs.id
    }
}

extension Unit: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
