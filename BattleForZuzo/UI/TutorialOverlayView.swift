import SwiftUI

struct TutorialOverlayView: View {
    @ObservedObject var tutorial: TutorialSystem

    var body: some View {
        if tutorial.isActive, let step = tutorial.currentStep {
            VStack {
                if step == .welcome {
                    Spacer()
                }

                calloutView(step: step)

                if step != .welcome {
                    Spacer()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: step)
        }
    }

    private func calloutView(step: TutorialStep) -> some View {
        VStack(spacing: 12) {
            Text(step.message)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                Button(action: {
                    tutorial.skipTutorial()
                }) {
                    Text("SKIP")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }

                if step == .welcome || step == .endTurn {
                    Button(action: {
                        tutorial.advanceStep()
                    }) {
                        Text(step == .endTurn ? "DONE" : "NEXT")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.6))
                            )
                    }
                } else {
                    Text("(do it to continue)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }

            // Step indicator
            HStack(spacing: 4) {
                ForEach(TutorialStep.allCases, id: \.rawValue) { s in
                    Circle()
                        .fill(s == step ? Color.white : Color.gray.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.4), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 60)
        .allowsHitTesting(true)
    }
}
