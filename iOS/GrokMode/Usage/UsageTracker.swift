//
//  UsageTracker.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/25/25.
//

import Foundation
import SwiftUI

/// Tracks usage and costs across all services
@Observable
class UsageTracker {
    static let shared = UsageTracker()

    // MARK: - Usage Data

    var grokVoiceUsage = GrokVoiceUsage()
    var openAIUsage = OpenAIUsage()
    var xAPIUsage = XAPIUsage()

    // MARK: - Computed Totals

    var totalCost: Decimal {
        grokVoiceUsage.totalCost + openAIUsage.totalCost + xAPIUsage.totalCost
    }

    private init() {
        loadUsage()
    }

    // MARK: - Tracking Methods

    /// Track a complete Grok voice minute
    func trackGrokVoiceMinute() {
        grokVoiceUsage.totalMinutes += 1.0
        saveUsage()
    }

    /// Track partial Grok voice usage (for remaining seconds at session end)
    func trackGrokVoicePartialMinute(seconds: TimeInterval) {
        let minutes = seconds / 60.0
        grokVoiceUsage.totalMinutes += minutes
        saveUsage()
    }

    /// Track OpenAI Realtime API usage
    func trackOpenAIUsage(
        audioInputTokens: Int = 0,
        audioOutputTokens: Int = 0,
        textInputTokens: Int = 0,
        textOutputTokens: Int = 0,
        cachedTextInputTokens: Int = 0
    ) {
        openAIUsage.audioInputTokens += audioInputTokens
        openAIUsage.audioOutputTokens += audioOutputTokens
        openAIUsage.textInputTokens += textInputTokens
        openAIUsage.textOutputTokens += textOutputTokens
        openAIUsage.cachedTextInputTokens += cachedTextInputTokens
        saveUsage()
    }

    /// Track X API usage by operation type
    func trackXAPIUsage(operation: XAPIOperation, count: Int = 1) {
        switch operation {
        case .postRead:
            xAPIUsage.postsRead += count
        case .userRead:
            xAPIUsage.usersRead += count
        case .dmEventRead:
            xAPIUsage.dmEventsRead += count
        case .contentCreate:
            xAPIUsage.contentCreates += count
        case .dmInteractionCreate:
            xAPIUsage.dmInteractionCreates += count
        case .userInteractionCreate:
            xAPIUsage.userInteractionCreates += count
        }
        saveUsage()
    }

    /// Reset all usage data
    func resetUsage() {
        grokVoiceUsage = GrokVoiceUsage()
        openAIUsage = OpenAIUsage()
        xAPIUsage = XAPIUsage()
        saveUsage()
    }

    // MARK: - Persistence

    private func saveUsage() {
        if let grokData = try? JSONEncoder().encode(grokVoiceUsage) {
            UserDefaults.standard.set(grokData, forKey: "grokVoiceUsage")
        }
        if let openAIData = try? JSONEncoder().encode(openAIUsage) {
            UserDefaults.standard.set(openAIData, forKey: "openAIUsage")
        }
        if let xAPIData = try? JSONEncoder().encode(xAPIUsage) {
            UserDefaults.standard.set(xAPIData, forKey: "xAPIUsage")
        }
    }

    private func loadUsage() {
        if let grokData = UserDefaults.standard.data(forKey: "grokVoiceUsage"),
           let loaded = try? JSONDecoder().decode(GrokVoiceUsage.self, from: grokData) {
            grokVoiceUsage = loaded
        }
        if let openAIData = UserDefaults.standard.data(forKey: "openAIUsage"),
           let loaded = try? JSONDecoder().decode(OpenAIUsage.self, from: openAIData) {
            openAIUsage = loaded
        }
        if let xAPIData = UserDefaults.standard.data(forKey: "xAPIUsage"),
           let loaded = try? JSONDecoder().decode(XAPIUsage.self, from: xAPIData) {
            xAPIUsage = loaded
        }
    }
}

// MARK: - Usage Models

struct GrokVoiceUsage: Codable {
    var totalMinutes: Double = 0

    var totalCost: Decimal {
        PricingConfig.calculateGrokVoiceCost(minutes: totalMinutes)
    }
}

struct OpenAIUsage: Codable {
    var audioInputTokens: Int = 0
    var audioOutputTokens: Int = 0
    var textInputTokens: Int = 0
    var textOutputTokens: Int = 0
    var cachedTextInputTokens: Int = 0

    var totalCost: Decimal {
        PricingConfig.calculateOpenAICost(
            audioInputTokens: audioInputTokens,
            audioOutputTokens: audioOutputTokens,
            textInputTokens: textInputTokens,
            textOutputTokens: textOutputTokens,
            cachedTextInputTokens: cachedTextInputTokens
        )
    }
}

struct XAPIUsage: Codable {
    var postsRead: Int = 0
    var usersRead: Int = 0
    var dmEventsRead: Int = 0
    var contentCreates: Int = 0
    var dmInteractionCreates: Int = 0
    var userInteractionCreates: Int = 0

    var totalCost: Decimal {
        (Decimal(postsRead) * PricingConfig.xAPIPostRead) +
        (Decimal(usersRead) * PricingConfig.xAPIUserRead) +
        (Decimal(dmEventsRead) * PricingConfig.xAPIDMEventRead) +
        (Decimal(contentCreates) * PricingConfig.xAPIContentCreate) +
        (Decimal(dmInteractionCreates) * PricingConfig.xAPIDMInteractionCreate) +
        (Decimal(userInteractionCreates) * PricingConfig.xAPIUserInteractionCreate)
    }
}

enum XAPIOperation {
    case postRead
    case userRead
    case dmEventRead
    case contentCreate
    case dmInteractionCreate
    case userInteractionCreate
}
