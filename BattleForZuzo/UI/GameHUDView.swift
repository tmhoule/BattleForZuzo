import SwiftUI

struct GameHUDView: View {
    @EnvironmentObject var appState: AppState
    var coordinator: GameCoordinator?
    @State private var showEndTurnConfirm = false
    @State private var showHowToPlay = false
    @State private var showTurnBanner = false
    @State private var showMenuConfirm = false

    private var gs: GameState { appState.gameState }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar - turn info and end turn
            topBar

            Spacer()

            // Bottom panel - always shows something
            bottomPanel
        }
        .allowsHitTesting(false)  // entire container passes touches through...
        .overlay(alignment: .topTrailing) {
            // ...except interactive elements, which explicitly allow hit testing
            if gs.isHumanTurn {
                HStack(spacing: 8) {
                    // Menu button
                    Button(action: { showMenuConfirm = true }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.gray.opacity(0.6)))
                    }
                    .allowsHitTesting(true)

                    // Help button
                    Button(action: { showHowToPlay = true }) {
                        Text("?")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.gray.opacity(0.6)))
                    }
                    .allowsHitTesting(true)

                    endTurnButton
                        .allowsHitTesting(true)
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
        }
        .overlay(alignment: .bottom) {
            if gs.showCityPanel, let city = gs.selectedCity,
               city.ownerID == gs.currentPlayer?.id {
                productionPanel(for: city)
                    .allowsHitTesting(true)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 12)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if gs.showUnitPanel, let unit = gs.selectedUnit,
               unit.type == .construction,
               unit.ownerID == gs.currentPlayer?.id,
               gs.isHumanTurn {
                buildRoadButton(for: unit)
                    .allowsHitTesting(true)
                    .padding(.trailing, 12)
                    .padding(.bottom, 60)
            }
        }
        .overlay(alignment: .bottomLeading) {
            MinimapView(gameState: gs, onTapLocation: { position in
                coordinator?.scene.cameraController.centerOn(position, animated: true)
            })
            .allowsHitTesting(true)
            .padding(.leading, 8)
            .padding(.bottom, 60)
        }
        .overlay {
            TutorialOverlayView(tutorial: gs.tutorial)
                .allowsHitTesting(gs.tutorial.isActive)
        }
        .sheet(isPresented: $showHowToPlay) {
            HowToPlayView()
        }
        .alert("Return to Menu?", isPresented: $showMenuConfirm) {
            Button("Save & Quit", role: .destructive) {
                appState.saveGame()
                appState.returnToMenu()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your game will be saved. You can resume from the main menu.")
        }
        .alert("End Turn?", isPresented: $showEndTurnConfirm) {
            Button("End Turn", role: .destructive) {
                gs.tutorial.onEndTurn()
                appState.gameState.endTurn()
                coordinator?.scene.updateRendering()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let remaining = gs.units(for: gs.currentPlayer?.id ?? UUID())
                .filter { $0.movementRemaining == Double($0.type.movement) && !$0.hasAttacked }.count
            Text("\(remaining) unit(s) haven't moved this turn.")
        }
        .overlay {
            if showTurnBanner {
                Text("YOUR TURN")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(6)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.7))
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            gs.tutorial.startIfNeeded()
        }
        .onChange(of: gs.isHumanTurn) { _, isHuman in
            if isHuman {
                coordinator?.scene.updateRendering()
                withAnimation(.easeOut(duration: 0.3)) {
                    showTurnBanner = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeIn(duration: 0.4)) {
                        showTurnBanner = false
                    }
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Turn \(gs.turnNumber)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(gs.statusMessage)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // Player indicators
            HStack(spacing: 8) {
                ForEach(gs.players.indices, id: \.self) { i in
                    let player = gs.players[i]
                    PlayerIndicator(
                        player: player,
                        isActive: i == gs.currentPlayerIndex
                    )
                }
            }

            Spacer()
            // Space for end turn button overlay
            Rectangle().fill(Color.clear).frame(width: 100, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.black.opacity(0.6))
    }

    // MARK: - End Turn Button

    private var endTurnButton: some View {
        Button(action: {
            let playerUnits = gs.units(for: gs.currentPlayer?.id ?? UUID())
            let unmoved = playerUnits.filter { $0.movementRemaining == Double($0.type.movement) && !$0.hasAttacked }
            if unmoved.isEmpty {
                gs.tutorial.onEndTurn()
                appState.gameState.endTurn()
                coordinator?.scene.updateRendering()
            } else {
                showEndTurnConfirm = true
            }
        }) {
            Text("END TURN")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.8))
                )
        }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        HStack(spacing: 0) {
            if gs.showUnitPanel, let unit = gs.selectedUnit {
                unitInfo(unit)
            } else if gs.showCityPanel, let city = gs.selectedCity {
                cityInfo(city)
            } else {
                turnSummary
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Unit Info

    private func unitInfo(_ unit: Unit) -> some View {
        HStack(spacing: 16) {
            // Unit icon
            ZStack {
                Circle()
                    .fill(playerColor(for: unit.ownerID))
                    .frame(width: 40, height: 40)
                Text(unit.type.symbol)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(unit.type.displayName)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                // HP bar
                HStack(spacing: 4) {
                    Text("HP")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(hpColor(unit))
                                .frame(width: geo.size.width * CGFloat(unit.hp) / CGFloat(unit.type.maxHP))
                        }
                    }
                    .frame(width: 60, height: 8)
                    Text("\(unit.hp)/\(unit.type.maxHP)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                statRow(label: "MOV", value: "\(formatMov(unit.movementRemaining))/\(unit.type.movement)")
                statRow(label: "ATK", value: "\(unit.type.damage)")
                statRow(label: "VIS", value: "\(unit.type.visibility)")
            }

            // Construction unit stats hint (button is in overlay for hit testing)
            if unit.type == .construction {
                let tile = gs.map?.tile(at: unit.position)
                let alreadyRoad = tile?.hasRoad ?? false
                if alreadyRoad {
                    Text("Road")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
        }
    }

    // MARK: - City Info

    private func cityInfo(_ city: City) -> some View {
        HStack(spacing: 12) {
            // City icon
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(playerColor(for: city.ownerID))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(45))
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(city.name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    if city.isCoastal {
                        Text("coastal")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    if city.isNeutral {
                        Text("neutral")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }

                if let producing = city.productionQueue {
                    let turnsLeft = producing.productionCost - city.productionProgress
                    HStack(spacing: 4) {
                        Text("Building: \(producing.displayName)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                        Text("\(turnsLeft) turn\(turnsLeft == 1 ? "" : "s") left")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                } else if city.ownerID == gs.currentPlayer?.id {
                    Text("Tap again to set production")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.yellow)
                } else {
                    Text("No production")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }

            Spacer()
        }
    }

    // MARK: - Production Panel (interactive overlay)

    private func productionPanel(for city: City) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SET PRODUCTION")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(2)

            ForEach(city.availableProductions, id: \.self) { unitType in
                let isActive = city.productionQueue == unitType
                let turnsLeft = isActive
                    ? unitType.productionCost - city.productionProgress
                    : unitType.productionCost
                Button(action: {
                    appState.gameState.citySystem?.setProduction(for: city, unitType: unitType)
                    appState.gameState.objectWillChange.send()
                }) {
                    HStack(spacing: 8) {
                        Text(unitType.symbol)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .frame(width: 20)
                        Text(unitType.displayName)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Text("\(turnsLeft) turn\(turnsLeft == 1 ? "" : "s")")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    .foregroundColor(isActive ? .orange : .white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isActive ?
                                  Color.orange.opacity(0.2) : Color.white.opacity(0.05))
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 260)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Turn Summary (no selection)

    private var turnSummary: some View {
        HStack(spacing: 16) {
            if let player = gs.currentPlayer {
                let unitCount = gs.units(for: player.id).count
                let cityCount = gs.map?.citiesForPlayer(player.id).count ?? 0

                statRow(label: "UNITS", value: "\(unitCount)")
                statRow(label: "CITIES", value: "\(cityCount)")
            }
            Spacer()
            Text("Tap a unit to select it")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Build Road Button (overlay)

    private func buildRoadButton(for unit: Unit) -> some View {
        let tile = gs.map?.tile(at: unit.position)
        let alreadyRoad = tile?.hasRoad ?? false
        let canBuild = unit.canBuildRoad && !alreadyRoad

        return Button(action: {
            appState.gameState.buildRoad(with: unit)
            appState.gameState.selectUnit(unit)
            coordinator?.scene.updateRendering()
        }) {
            Text("BUILD ROAD")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(canBuild ? Color.yellow.opacity(0.8) : Color.gray.opacity(0.4))
                )
        }
        .disabled(!canBuild)
    }

    // MARK: - Helpers

    private func statRow(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
    }

    private func playerColor(for ownerID: UUID?) -> Color {
        guard let id = ownerID,
              let player = gs.players.first(where: { $0.id == id }) else {
            return Color.gray
        }
        return Color(player.color)
    }

    private func formatMov(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : String(format: "%.1f", value)
    }

    private func hpColor(_ unit: Unit) -> Color {
        let ratio = Double(unit.hp) / Double(unit.type.maxHP)
        if ratio > 0.5 { return .green }
        if ratio > 0.25 { return .yellow }
        return .red
    }
}

struct PlayerIndicator: View {
    let player: Player
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(Color(player.color))
            .frame(width: isActive ? 16 : 12, height: isActive ? 16 : 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isActive ? 2 : 0)
            )
            .opacity(player.isEliminated ? 0.3 : 1.0)
    }
}
