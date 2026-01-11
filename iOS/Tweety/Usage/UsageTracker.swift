//
//  UsageTracker.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/25/25.
//

import Foundation
import SwiftUI
internal import os

/// Tracks usage and costs across all services
@Observable
class UsageTracker {
    private let creditsService: RemoteCreditsService

    var grokVoiceUsage = GrokVoiceUsage()
    var openAIUsage = OpenAIUsage()
    var xAPIUsage = XAPIUsage()
    var usagePeriodStart: Date = Date()

    var totalCost: Decimal {
        grokVoiceUsage.totalCost + openAIUsage.totalCost + xAPIUsage.totalCost
    }

    init(creditsService: RemoteCreditsService) {
        self.creditsService = creditsService
        loadUsage()
    }

    func trackGrokVoiceMinute() {
        grokVoiceUsage.totalMinutes += 1.0
        saveUsage()
    }

    func trackGrokVoicePartialMinute(seconds: TimeInterval) {
        let minutes = seconds / 60.0
        grokVoiceUsage.totalMinutes += minutes
        saveUsage()
    }

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

    func resetUsage() {
        grokVoiceUsage = GrokVoiceUsage()
        openAIUsage = OpenAIUsage()
        xAPIUsage = XAPIUsage()
        usagePeriodStart = Date()
        saveUsage()
    }

    // MARK: - Server-Side Tracking Methods

    func trackAndRegisterOpenAIUsage(
        audioInputTokens: Int = 0,
        audioOutputTokens: Int = 0,
        textInputTokens: Int = 0,
        textOutputTokens: Int = 0,
        cachedTextInputTokens: Int = 0,
        userId: String
    ) async -> Result<CreditBalance, Error> {
        // Track locally first
        trackOpenAIUsage(
            audioInputTokens: audioInputTokens,
            audioOutputTokens: audioOutputTokens,
            textInputTokens: textInputTokens,
            textOutputTokens: textOutputTokens,
            cachedTextInputTokens: cachedTextInputTokens
        )

        // Register with server
        do {
            let usage = UsageDetails.openAI(OpenAIUsageDetails(
                audioInputTokens: audioInputTokens,
                audioOutputTokens: audioOutputTokens,
                textInputTokens: textInputTokens,
                textOutputTokens: textOutputTokens,
                cachedTextInputTokens: cachedTextInputTokens
            ))

            let response = try await creditsService.trackUsage(
                userId: userId,
                service: "openai_realtime",
                usage: usage
            )

            let balance = CreditBalance(
                userId: userId,
                spent: response.spent,
                total: response.total,
                remaining: response.remaining
            )

            return .success(balance)
        } catch {
            AppLogger.usage.error("OpenAI usage registration failed: \(error)")
            return .failure(error)
        }
    }

    func trackAndRegisterXAIUsage(
        minutes: Double,
        userId: String
    ) async -> Result<CreditBalance, Error> {
        trackGrokVoicePartialMinute(seconds: minutes * 60.0)

        do {
            let usage = UsageDetails.grokVoice(GrokVoiceUsageDetails(minutes: minutes))

            let response = try await creditsService.trackUsage(
                userId: userId,
                service: "grok_voice",
                usage: usage
            )

            let balance = CreditBalance(
                userId: userId,
                spent: response.spent,
                total: response.total,
                remaining: response.remaining
            )

            return .success(balance)
        } catch {
            AppLogger.usage.error("xAI usage registration failed: \(error)")
            return .failure(error)
        }
    }

    func trackAndRegisterXAPIUsage(
        operation: XAPIOperation,
        count: Int,
        userId: String
    ) async -> Result<CreditBalance, Error> {
        trackXAPIUsage(operation: operation, count: count)

        do {
            var postsRead: Int? = nil
            var usersRead: Int? = nil
            var dmEventsRead: Int? = nil
            var contentCreates: Int? = nil
            var dmInteractionCreates: Int? = nil
            var userInteractionCreates: Int? = nil

            switch operation {
            case .postRead:
                postsRead = count
            case .userRead:
                usersRead = count
            case .dmEventRead:
                dmEventsRead = count
            case .contentCreate:
                contentCreates = count
            case .dmInteractionCreate:
                dmInteractionCreates = count
            case .userInteractionCreate:
                userInteractionCreates = count
            }

            let usage = UsageDetails.xAPI(XAPIUsageDetails(
                postsRead: postsRead,
                usersRead: usersRead,
                dmEventsRead: dmEventsRead,
                contentCreates: contentCreates,
                dmInteractionCreates: dmInteractionCreates,
                userInteractionCreates: userInteractionCreates
            ))

            let response = try await creditsService.trackUsage(
                userId: userId,
                service: "x_api",
                usage: usage
            )

            let balance = CreditBalance(
                userId: userId,
                spent: response.spent,
                total: response.total,
                remaining: response.remaining
            )

            return .success(balance)
        } catch {
            AppLogger.usage.error("X API usage registration failed: \(error)")
            return .failure(error)
        }
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
        UserDefaults.standard.set(usagePeriodStart, forKey: "usagePeriodStart")
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
        if let periodStart = UserDefaults.standard.object(forKey: "usagePeriodStart") as? Date {
            usagePeriodStart = periodStart
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
