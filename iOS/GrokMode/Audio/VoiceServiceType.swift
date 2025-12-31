//
//  VoiceServiceType.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/18/25.
//

import Foundation

/// Voice options for different services
enum VoiceOption: String, CaseIterable, Identifiable {
    // OpenAI voices
    case alloy, ash, ballad, coral, echo, sage, shimmer, verse
    // xAI voices
    case ara = "Ara"
    case rex = "Rex"
    case sal = "Sal"
    case eve = "Eve"
    case una = "Una"
    case leo = "Leo"

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

/// Enumeration of available voice service providers
enum VoiceServiceType: String, CaseIterable, Identifiable {
    case xai = "xAI"
    case openai = "OpenAI"

    var id: String { rawValue }

    /// Display name for the service (model name)
    var displayName: String {
        switch self {
        case .xai:
            return "Grok"
        case .openai:
            return "GPT-Realtime"
        }
    }

    /// Assistant name shown to users (same as display name)
    var assistantName: String {
        displayName
    }

    /// Icon name for the service
    var iconName: String {
        switch self {
        case .xai:
            return "Grok" // Uses existing grok image asset
        case .openai:
            return "OpenAI" // SF Symbol for OpenAI
        }
    }

    /// Available voices for this service
    var availableVoices: [VoiceOption] {
        switch self {
        case .xai:
            return [.ara, .rex, .sal, .eve, .una, .leo]
        case .openai:
            return [.alloy, .ash, .ballad, .coral, .echo, .sage, .shimmer, .verse]
        }
    }

    /// Default voice for this service
    var defaultVoice: VoiceOption {
        switch self {
        case .xai:
            return .rex
        case .openai:
            return .coral
        }
    }

    /// Creates the appropriate voice service instance
    func createService(sessionState: SessionState, appAttestService: AppAttestService, storeManager: StoreKitManager, usageTracker: UsageTracker, voice: VoiceOption) -> VoiceService {
        switch self {
        case .xai:
            let xaiVoice = XAIConversationEvent.SessionConfig.Voice(rawValue: voice.rawValue.capitalized) ?? .Rex
            return XAIVoiceService(sessionState: sessionState, appAttestService: appAttestService, voice: xaiVoice, sampleRate: .twentyFourKHz)
        case .openai:
            let openAIVoice = OpenAIVoiceService.Voice(rawValue: voice.rawValue) ?? .coral
            return OpenAIVoiceService(sessionState: sessionState, appAttestService: appAttestService, storeManager: storeManager, usageTracker: usageTracker, voice: openAIVoice, sampleRate: 24000)
        }
    }
}
