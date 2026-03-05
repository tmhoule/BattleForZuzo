import SwiftUI

struct VictoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                switch appState.gameState.victoryState {
                case .victory(let playerName):
                    VStack(spacing: 12) {
                        Text("VICTORY")
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.5), radius: 20)

                        Text("\(playerName) conquered all!")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                case .defeat:
                    VStack(spacing: 12) {
                        Text("DEFEAT")
                            .font(.system(size: 48, weight: .black, design: .monospaced))
                            .foregroundColor(.red)
                            .shadow(color: .red.opacity(0.5), radius: 20)

                        Text("Your empire has fallen...")
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                case .ongoing:
                    EmptyView()
                }

                Spacer()

                // Stats
                VStack(spacing: 8) {
                    Text("TURNS: \(appState.gameState.turnNumber)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(spacing: 12) {
                    MenuButton(title: "NEW GAME") {
                        appState.currentScreen = .gameSetup
                    }

                    Button("Main Menu") {
                        appState.returnToMenu()
                    }
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.gray)
                }
                .padding(.bottom, 40)
            }
        }
    }
}
