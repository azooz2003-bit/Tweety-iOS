//
//  UsageDashboardView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/25/25.
//

import SwiftUI

struct UsageDashboardView: View {
    @State private var tracker = UsageTracker.shared

    var body: some View {
        NavigationStack {
            List {
                // Total Cost Section
                Section {
                    HStack {
                        Text("Total Cost")
                            .font(.headline)
                        Spacer()
                        Text(formatCurrency(tracker.totalCost))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }

                // Grok Voice Section
                Section("Grok Voice") {
                    HStack {
                        Text("Total Minutes")
                        Spacer()
                        Text(String(format: "%.2f min", tracker.grokVoiceUsage.totalMinutes))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Cost")
                        Spacer()
                        Text(formatCurrency(tracker.grokVoiceUsage.totalCost))
                            .fontWeight(.semibold)
                    }
                }

                // OpenAI Realtime Section
                Section("GPT-Realtime") {
                    HStack {
                        Text("Audio Input Tokens")
                        Spacer()
                        Text("\(tracker.openAIUsage.audioInputTokens.formatted())")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Audio Output Tokens")
                        Spacer()
                        Text("\(tracker.openAIUsage.audioOutputTokens.formatted())")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Text Input Tokens")
                        Spacer()
                        Text("\(tracker.openAIUsage.textInputTokens.formatted())")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Text Output Tokens")
                        Spacer()
                        Text("\(tracker.openAIUsage.textOutputTokens.formatted())")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Cached Text Input")
                        Spacer()
                        Text("\(tracker.openAIUsage.cachedTextInputTokens.formatted())")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Cost")
                        Spacer()
                        Text(formatCurrency(tracker.openAIUsage.totalCost))
                            .fontWeight(.semibold)
                    }
                }

                // X API Section
                Section("X API") {
                    HStack {
                        Text("Posts Read")
                        Spacer()
                        Text("\(tracker.xAPIUsage.postsRead)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Users Read")
                        Spacer()
                        Text("\(tracker.xAPIUsage.usersRead)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("DM Events Read")
                        Spacer()
                        Text("\(tracker.xAPIUsage.dmEventsRead)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Content Creates")
                        Spacer()
                        Text("\(tracker.xAPIUsage.contentCreates)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("DM Interactions")
                        Spacer()
                        Text("\(tracker.xAPIUsage.dmInteractionCreates)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("User Interactions")
                        Spacer()
                        Text("\(tracker.xAPIUsage.userInteractionCreates)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Cost")
                        Spacer()
                        Text(formatCurrency(tracker.xAPIUsage.totalCost))
                            .fontWeight(.semibold)
                    }
                }

                // Reset Button
                Section {
                    Button(role: .destructive) {
                        tracker.resetUsage()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset Usage Data")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Usage & Costs")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
}

#Preview {
    UsageDashboardView()
}
