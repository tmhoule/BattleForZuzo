import Foundation
import SwiftUI
import Combine

enum AppScreen {
    case mainMenu
    case gameSetup
    case playing
    case victory
}

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .mainMenu
    @Published var gameState = GameState()

    // Game setup parameters
    @Published var selectedMapSize: Constants.MapSize = .medium
    @Published var selectedMapType: Constants.MapType = .mixed
    @Published var selectedPlayerCount: Int = 4

    private var gameStateCancellable: AnyCancellable?

    init() {
        subscribeToGameState()
    }

    /// Forward gameState changes to appState so SwiftUI views re-render
    private func subscribeToGameState() {
        gameStateCancellable = gameState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var hasSavedGame: Bool {
        GamePersistence.hasSavedGame
    }

    func startNewGame() {
        GamePersistence.deleteSave()
        gameState = GameState()
        subscribeToGameState()
        gameState.setupGame(
            mapSize: selectedMapSize,
            mapType: selectedMapType,
            playerCount: selectedPlayerCount
        )
        currentScreen = .playing
    }

    func resumeGame() {
        guard let save = GamePersistence.load() else { return }
        gameState = GameState()
        subscribeToGameState()
        gameState.restoreFrom(save)
        currentScreen = .playing
    }

    func saveGame() {
        guard gameState.gamePhase == .playing else { return }
        GamePersistence.save(gameState)
    }

    func returnToMenu() {
        currentScreen = .mainMenu
    }
}
