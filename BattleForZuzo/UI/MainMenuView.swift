import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var appState: AppState
    @State private var showHowToPlay = false
    @State private var hasSave = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.15),
                    Color(red: 0.1, green: 0.15, blue: 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Text("BATTLE FOR")
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(8)

                    Text("ZUZO")
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(12)
                        .shadow(color: .blue.opacity(0.5), radius: 20)
                }

                Spacer()

                // Buttons
                VStack(spacing: 16) {
                    if hasSave {
                        MenuButton(title: "RESUME GAME") {
                            appState.resumeGame()
                        }
                    }

                    MenuButton(title: "NEW GAME") {
                        appState.currentScreen = .gameSetup
                    }

                    MenuButton(title: "HOW TO PLAY") {
                        showHowToPlay = true
                    }
                }

                Spacer()

                // Version
                Text("v1.0")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
        .onAppear { hasSave = GamePersistence.hasSavedGame }
        .sheet(isPresented: $showHowToPlay) {
            HowToPlayView()
        }
    }
}

struct MenuButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 240, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                        )
                )
        }
    }
}
