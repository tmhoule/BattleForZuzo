import SwiftUI
import SpriteKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            switch appState.currentScreen {
            case .mainMenu:
                MainMenuView()
            case .gameSetup:
                GameSetupView()
            case .playing:
                GamePlayView()
            case .victory:
                VictoryView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.currentScreen)
    }
}

struct GamePlayView: View {
    @EnvironmentObject var appState: AppState
    @State private var scene: GameScene?
    @State private var gameCoordinator: GameCoordinator?

    var body: some View {
        ZStack {
            // SpriteKit game view
            if let scene = scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            }

            // SwiftUI HUD overlay
            GameHUDView(coordinator: gameCoordinator)
        }
        .onAppear {
            setupScene()
        }
        .onChange(of: appState.gameState.gamePhase) { _, newPhase in
            if newPhase == .gameOver {
                appState.currentScreen = .victory
            }
        }
    }

    private func setupScene() {
        let newScene = GameScene(size: UIScreen.main.bounds.size)
        newScene.scaleMode = .resizeFill
        newScene.gameState = appState.gameState

        let coordinator = GameCoordinator(gameState: appState.gameState, scene: newScene)
        newScene.gameSceneDelegate = coordinator

        self.scene = newScene
        self.gameCoordinator = coordinator

        // Trigger initial render after scene is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            newScene.renderAll()
        }
    }
}

// MARK: - Game Coordinator

class GameCoordinator: ObservableObject, GameSceneDelegate {
    let gameState: GameState
    let scene: GameScene

    init(gameState: GameState, scene: GameScene) {
        self.gameState = gameState
        self.scene = scene
    }

    func didTapUnit(_ unit: Unit) {
        guard gameState.isHumanTurn else { return }

        // If we already have a selected unit owned by us...
        if let selected = gameState.selectedUnit, selected.ownerID == gameState.currentPlayer?.id {
            // Tapping an enemy unit that's attackable -> attack
            if unit.ownerID != gameState.currentPlayer?.id,
               gameState.attackableHexes.contains(unit.position) {
                let result = gameState.attackUnit(selected, target: unit)
                if let result = result {
                    if result.defenderDestroyed {
                        gameState.statusMessage = "\(selected.type.displayName) destroyed \(unit.type.displayName)!"
                    } else if result.attackerDestroyed {
                        gameState.statusMessage = "\(selected.type.displayName) was destroyed!"
                    } else {
                        gameState.statusMessage = "Attack dealt \(result.attackerDamageDealt) damage"
                    }
                }
                gameState.clearSelection()
                scene.updateRendering()
                return
            }

            // Tapping the same unit -> toggle to city if one exists, else deselect
            if unit.id == selected.id {
                if let city = gameState.map?.city(at: unit.position) {
                    gameState.selectCity(city)
                } else {
                    gameState.clearSelection()
                }
                scene.updateRendering()
                return
            }
        }

        // Select the tapped unit (own or enemy for info)
        gameState.selectUnit(unit)
        scene.updateRendering()
    }

    func didTapCity(_ city: City) {
        guard gameState.isHumanTurn else { return }

        // If selected unit can move to city hex, move there
        if let selected = gameState.selectedUnit,
           selected.ownerID == gameState.currentPlayer?.id,
           gameState.reachableHexes.contains(city.position) {
            _ = gameState.moveUnit(selected, to: city.position)
            gameState.selectUnit(selected)  // Re-select to update reachable
            scene.updateRendering()
            return
        }

        // Otherwise select the city to show info/production panel
        gameState.selectCity(city)
        scene.updateRendering()
    }

    func didTapEmpty(at coord: HexCoord) {
        guard gameState.isHumanTurn else { return }

        // If selected unit can move here, move
        if let selected = gameState.selectedUnit,
           selected.ownerID == gameState.currentPlayer?.id,
           gameState.reachableHexes.contains(coord) {
            _ = gameState.moveUnit(selected, to: coord)
            gameState.selectUnit(selected)  // Re-select to update reachable
            scene.updateRendering()
            return
        }

        // If selected unit is a carrier with cargo, try to unload
        if let selected = gameState.selectedUnit,
           selected.ownerID == gameState.currentPlayer?.id,
           selected.type.canCarryUnits,
           !selected.carriedUnits.isEmpty {
            if gameState.unloadUnit(from: selected, to: coord) {
                gameState.statusMessage = "Unit disembarked!"
                gameState.selectUnit(selected)
                scene.updateRendering()
                return
            }
        }

        gameState.clearSelection()
        scene.updateRendering()
    }
}
