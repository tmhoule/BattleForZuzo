import Foundation
import SpriteKit

class Player: Identifiable, Codable {
    let id: UUID
    let name: String
    let color: SKColor
    let isHuman: Bool
    var isEliminated: Bool = false
    var exploredTiles: Set<HexCoord> = []

    init(id: UUID = UUID(), name: String, color: SKColor, isHuman: Bool) {
        self.id = id
        self.name = name
        self.color = color
        self.isHuman = isHuman
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, colorR, colorG, colorB, colorA, isHuman, isEliminated, exploredTiles
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let r = try c.decode(CGFloat.self, forKey: .colorR)
        let g = try c.decode(CGFloat.self, forKey: .colorG)
        let b = try c.decode(CGFloat.self, forKey: .colorB)
        let a = try c.decode(CGFloat.self, forKey: .colorA)
        color = SKColor(red: r, green: g, blue: b, alpha: a)
        isHuman = try c.decode(Bool.self, forKey: .isHuman)
        isEliminated = try c.decode(Bool.self, forKey: .isEliminated)
        exploredTiles = try c.decode(Set<HexCoord>.self, forKey: .exploredTiles)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        try c.encode(r, forKey: .colorR)
        try c.encode(g, forKey: .colorG)
        try c.encode(b, forKey: .colorB)
        try c.encode(a, forKey: .colorA)
        try c.encode(isHuman, forKey: .isHuman)
        try c.encode(isEliminated, forKey: .isEliminated)
        try c.encode(exploredTiles, forKey: .exploredTiles)
    }
}
