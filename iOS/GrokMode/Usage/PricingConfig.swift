//
//  PricingConfig.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/25/25.
//

import Foundation

/// Pricing configuration for all services
struct PricingConfig {

    // MARK: - Grok Voice Pricing

    static let grokVoiceCostPerMinute: Decimal = 0.05

    // MARK: - OpenAI Realtime Pricing (per 1 million tokens)

    static let openAIAudioInputPer1M: Decimal = 32.00
    static let openAIAudioOutputPer1M: Decimal = 64.00
    static let openAITextInputPer1M: Decimal = 4.00
    static let openAITextOutputPer1M: Decimal = 16.00
    static let openAICachedTextInputPer1M: Decimal = 0.40

    // MARK: - X API Pricing (per request/item)

    static let xAPIPostRead: Decimal = 0.005
    static let xAPIUserRead: Decimal = 0.01
    static let xAPIDMEventRead: Decimal = 0.01
    static let xAPIContentCreate: Decimal = 0.01
    static let xAPIDMInteractionCreate: Decimal = 0.01
    static let xAPIUserInteractionCreate: Decimal = 0.015
    static func calculateOpenAICost(
        audioInputTokens: Int = 0,
        audioOutputTokens: Int = 0,
        textInputTokens: Int = 0,
        textOutputTokens: Int = 0,
        cachedTextInputTokens: Int = 0
    ) -> Decimal {
        let audioInputCost = (Decimal(audioInputTokens) / 1_000_000) * openAIAudioInputPer1M
        let audioOutputCost = (Decimal(audioOutputTokens) / 1_000_000) * openAIAudioOutputPer1M
        let textInputCost = (Decimal(textInputTokens) / 1_000_000) * openAITextInputPer1M
        let textOutputCost = (Decimal(textOutputTokens) / 1_000_000) * openAITextOutputPer1M
        let cachedTextInputCost = (Decimal(cachedTextInputTokens) / 1_000_000) * openAICachedTextInputPer1M

        return audioInputCost + audioOutputCost + textInputCost + textOutputCost + cachedTextInputCost
    }

    static func calculateGrokVoiceCost(minutes: Double) -> Decimal {
        return Decimal(minutes) * grokVoiceCostPerMinute
    }
}
