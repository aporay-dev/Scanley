//
//  StartupScreen.swift
//  Scanley
//
//  Created by Claude Code on 2025-09-18.
//

import SwiftUI

struct StartupScreen: View {
    @State private var animationPhase = 0
    @State private var statusText = "Initializing..."

    var body: some View {
        ZStack {
            // Background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                Image("ScanleyLogo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.primary)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 80)
                    .scaleEffect(1.0 + sin(Double(animationPhase) * 0.1) * 0.05)
                    .accessibilityLabel("Scanley")

                
                
                VStack(){
                    Text("AI Powered Search for your photos.\n\t\tTame the chaos. Safely.")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(.primary)
                }
                .padding(.top,80)


                Spacer()

                VStack(spacing: 16) {
                    // Status Text
                    Text(statusText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Loading Animation - Similar to existing Loading.swift
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(getColorForDot(index: index))
                                .frame(width: 12, height: 12)
                                .scaleEffect(getScaleForDot(index: index))
                                .animation(
                                    Animation.easeInOut(duration: 0.8)
                                        .repeatForever()
                                        .delay(Double(index) * 0.2),
                                    value: animationPhase
                                )
                        }
                    }
                }
                .padding(.bottom, 60)
            }
            .onAppear {
                startAnimations()
                updateStatusText()
            }
        }
    }

    private func startAnimations() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            animationPhase += 1
        }
    }

    private func updateStatusText() {
        let statusMessages = [
            "Initializing...",
            "Cleaning up orphaned records...",
            "Preparing your documents...",
            "Almost ready..."
        ]

        var messageIndex = 0
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            if messageIndex < statusMessages.count {
                statusText = statusMessages[messageIndex]
                messageIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func getColorForDot(index: Int) -> Color {
        let colors: [Color] = [.purple, .orange, .cyan]
        return colors[index % colors.count]
    }

    private func getScaleForDot(index: Int) -> Double {
        let phase = Double(animationPhase % 30) / 10.0
        let offset = Double(index) * 0.5
        return 1.0 + 0.3 * sin(phase + offset)
    }
}

#Preview {
    StartupScreen()
}
