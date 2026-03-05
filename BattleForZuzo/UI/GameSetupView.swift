import SwiftUI

struct GameSetupView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.15)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Header
                Text("GAME SETUP")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.top, 40)

                VStack(spacing: 24) {
                    // Map Size
                    SettingRow(title: "MAP SIZE") {
                        Picker("Map Size", selection: $appState.selectedMapSize) {
                            ForEach(Constants.MapSize.allCases, id: \.self) { size in
                                Text(size.rawValue).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Map Type
                    SettingRow(title: "MAP TYPE") {
                        Picker("Map Type", selection: $appState.selectedMapType) {
                            ForEach(Constants.MapType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Player Count
                    SettingRow(title: "OPPONENTS") {
                        Picker("Opponents", selection: $appState.selectedPlayerCount) {
                            Text("1").tag(2)
                            Text("2").tag(3)
                            Text("3").tag(4)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    MenuButton(title: "START GAME") {
                        appState.startNewGame()
                    }

                    Button("Back") {
                        appState.currentScreen = .mainMenu
                    }
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.gray)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(2)

            content
        }
    }
}
