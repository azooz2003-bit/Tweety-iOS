//
//  TypingTextView.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/10/26.
//

import SwiftUI

struct TypingTextView: View {
    let textToType: String
    let indicesToPauseAt: Set<Int>
    let typingSpeedInMS: Int
    let pausingSpeedInMS: Int

    @State var currentText = ""

    init(textToType: String, indicesToPauseAt: Set<Int>, typingSpeedInMS: Int = 50, pausingSpeedInMS: Int = 600) {
        self.textToType = textToType
        self.indicesToPauseAt = indicesToPauseAt
        self.typingSpeedInMS = typingSpeedInMS
        self.pausingSpeedInMS = pausingSpeedInMS
    }

    var body: some View {
        Text(currentText)
            .task {
                do {
                    try await scheduleTextUpdateLoop()
                } catch {
                     currentText = textToType
                }
            }
    }

    func scheduleTextUpdateLoop() async throws {
        while currentText.count < textToType.count {
            let currIndex = currentText.count - 1

            if indicesToPauseAt.contains(currIndex) {
                try await Task.sleep(for: .milliseconds(pausingSpeedInMS))
            } else {
                try await Task.sleep(for: .milliseconds(typingSpeedInMS))
            }

            guard let index = textToType.index(textToType.startIndex, offsetBy: currIndex + 1, limitedBy: textToType.endIndex) else {
                break
            }
            currentText += "\(textToType[index])"
        }
    }
}

#Preview {
    TypingTextView(
        textToType: "Hey, it's Tweety",
        indicesToPauseAt: [3]
    )
}
