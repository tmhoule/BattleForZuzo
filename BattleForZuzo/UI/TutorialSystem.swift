import Foundation

enum TutorialStep: Int, CaseIterable {
    case welcome = 0
    case selectUnit
    case moveUnit
    case attackEnemy
    case captureCity
    case setProduction
    case endTurn

    var message: String {
        switch self {
        case .welcome:
            return "Welcome to Battle for Zuzo! Conquer all cities to win. Let's learn the basics."
        case .selectUnit:
            return "Tap one of your units to select it. Blue hexes show where it can move."
        case .moveUnit:
            return "Tap a blue hex to move your unit there. Different terrain costs different movement."
        case .attackEnemy:
            return "Red hexes show enemies you can attack. Tap a red hex to attack! Terrain gives defense bonuses."
        case .captureCity:
            return "Move a land unit onto a neutral or enemy city to capture it. Cities produce new units."
        case .setProduction:
            return "Tap a city you own to see its info, then tap again to set what unit it should build."
        case .endTurn:
            return "When all your units have moved, tap END TURN. The AI will then take its turn. Good luck!"
        }
    }

    var nextStep: TutorialStep? {
        TutorialStep(rawValue: rawValue + 1)
    }
}

class TutorialSystem: ObservableObject {
    @Published var currentStep: TutorialStep?
    @Published var isActive: Bool = false

    private let completedKey = "tutorialCompleted"

    var hasCompletedTutorial: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    func startIfNeeded() {
        guard !hasCompletedTutorial else { return }
        currentStep = .welcome
        isActive = true
    }

    func advanceStep() {
        guard let step = currentStep else { return }
        if let next = step.nextStep {
            currentStep = next
        } else {
            completeTutorial()
        }
    }

    func skipTutorial() {
        completeTutorial()
    }

    private func completeTutorial() {
        currentStep = nil
        isActive = false
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    func resetTutorial() {
        UserDefaults.standard.set(false, forKey: completedKey)
    }

    /// Auto-advance based on game events
    func onUnitSelected() {
        if currentStep == .selectUnit { advanceStep() }
    }

    func onUnitMoved() {
        if currentStep == .moveUnit { advanceStep() }
    }

    func onAttack() {
        if currentStep == .attackEnemy { advanceStep() }
    }

    func onCityCapture() {
        if currentStep == .captureCity { advanceStep() }
    }

    func onProductionSet() {
        if currentStep == .setProduction { advanceStep() }
    }

    func onEndTurn() {
        if currentStep == .endTurn { advanceStep() }
    }
}
