//
//  VoiceServiceType.swift
//  GrokMode
//
//  Created by Claude Code on 12/18/25.
//

import Foundation

/// Enumeration of available voice service providers
enum VoiceServiceType: String, CaseIterable, Identifiable {
    case xai = "xAI"
    case openai = "OpenAI"

    var id: String { rawValue }

    /// Display name for the service
    var displayName: String {
        rawValue
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

    /// Creates the appropriate voice service instance
    func createService(sessionState: SessionState) -> VoiceService {
        switch self {
        case .xai:
            return XAIVoiceService(sessionState: sessionState, sampleRate: .twentyFourKHz)
        case .openai:
            return OpenAIVoiceService(sessionState: sessionState, sampleRate: 24000)
        }
    }
}
