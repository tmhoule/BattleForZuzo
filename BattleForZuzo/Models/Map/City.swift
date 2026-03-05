import Foundation

class City: Codable {
    let id: UUID
    let position: HexCoord
    var name: String
    var ownerID: UUID?
    var isCoastal: Bool

    // Production
    var productionQueue: UnitType?
    var productionProgress: Int = 0

    init(id: UUID = UUID(), position: HexCoord, name: String, isCoastal: Bool = false) {
        self.id = id
        self.position = position
        self.name = name
        self.isCoastal = isCoastal
    }

    var isNeutral: Bool { ownerID == nil }

    func canProduce(_ unitType: UnitType) -> Bool {
        switch unitType.terrainAccess {
        case .water:
            return isCoastal
        case .land:
            return true
        case .any:
            return true
        }
    }

    var availableProductions: [UnitType] {
        UnitType.allCases.filter { canProduce($0) }
    }

    /// Advance production by 1 turn. Returns completed unit type if finished.
    @discardableResult
    func advanceProduction() -> UnitType? {
        guard let producing = productionQueue else { return nil }
        productionProgress += 1
        if productionProgress >= producing.productionCost {
            let completed = producing
            productionQueue = nil
            productionProgress = 0
            return completed
        }
        return nil
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, position, name, ownerID, isCoastal, productionQueue, productionProgress
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        position = try c.decode(HexCoord.self, forKey: .position)
        name = try c.decode(String.self, forKey: .name)
        ownerID = try c.decodeIfPresent(UUID.self, forKey: .ownerID)
        isCoastal = try c.decode(Bool.self, forKey: .isCoastal)
        productionQueue = try c.decodeIfPresent(UnitType.self, forKey: .productionQueue)
        productionProgress = try c.decode(Int.self, forKey: .productionProgress)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(position, forKey: .position)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(ownerID, forKey: .ownerID)
        try c.encode(isCoastal, forKey: .isCoastal)
        try c.encodeIfPresent(productionQueue, forKey: .productionQueue)
        try c.encode(productionProgress, forKey: .productionProgress)
    }
}
