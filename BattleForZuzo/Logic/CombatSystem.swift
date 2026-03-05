import Foundation

struct CombatResult {
    let attackerDamageDealt: Int
    let defenderDamageDealt: Int
    let attackerDestroyed: Bool
    let defenderDestroyed: Bool
    let attackerUnit: Unit
    let defenderUnit: Unit
}

class CombatSystem {
    unowned let gameState: GameState

    init(gameState: GameState) {
        self.gameState = gameState
    }

    /// Resolve an attack between units (melee or ranged)
    func resolveAttack(attacker: Unit, defender: Unit) -> CombatResult? {
        guard attacker.canAttack else { return nil }
        let dist = gameState.map?.topology.distance(from: attacker.position, to: defender.position) ?? attacker.position.distance(to: defender.position)
        guard dist <= attacker.type.attackRange else { return nil }
        guard attacker.ownerID != defender.ownerID else { return nil }

        // Attacker deals full damage minus terrain defense bonus
        let defenderTerrain = gameState.map?.tile(at: defender.position)?.terrain
        let defenseBonus = Int(defenderTerrain?.defenseBonus ?? 0)
        let attackDamage = max(1, attacker.type.damage - defenseBonus)
        defender.takeDamage(attackDamage)

        // Defender counter-attacks at half damage if alive, can attack, and in melee range
        var counterDamage = 0
        if dist <= 1 && defender.isAlive && defender.type.canAttack {
            counterDamage = max(1, defender.type.damage / 2)
            attacker.takeDamage(counterDamage)
        }

        // Attacker used their turn
        attacker.hasAttacked = true
        attacker.movementRemaining = 0

        let result = CombatResult(
            attackerDamageDealt: attackDamage,
            defenderDamageDealt: counterDamage,
            attackerDestroyed: attacker.isDead,
            defenderDestroyed: defender.isDead,
            attackerUnit: attacker,
            defenderUnit: defender
        )

        return result
    }

    /// Check if an attack is possible
    func canAttack(attacker: Unit, defender: Unit) -> Bool {
        guard attacker.canAttack else { return false }
        let dist = gameState.map?.topology.distance(from: attacker.position, to: defender.position) ?? attacker.position.distance(to: defender.position)
        guard dist <= attacker.type.attackRange else { return false }
        guard attacker.ownerID != defender.ownerID else { return false }
        return true
    }
}
