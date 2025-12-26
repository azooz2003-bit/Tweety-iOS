//
//  SessionTimerView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/25/25.
//

import SwiftUI

/// Isolated timer view that updates independently without triggering parent view redraws
struct SessionTimerView: View {
    let sessionStartTime: Date?

    @State private var currentTime = Date()
    @State private var timer: Timer?

    var body: some View {
        Text(formattedDuration)
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .onAppear {
                startTimer()
            }
            .onDisappear {
                stopTimer()
            }
            .onChange(of: sessionStartTime) { _, _ in
                currentTime = Date()
            }
    }

    private var formattedDuration: String {
        guard let startTime = sessionStartTime else {
            return "0:00"
        }

        let elapsed = currentTime.timeIntervalSince(startTime)
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: elapsed) ?? "0:00"
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
