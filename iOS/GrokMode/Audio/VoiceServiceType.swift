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
            return "circle.slash" // Uses existing grok image asset
        case .openai:
            return "brain.head.profile" // SF Symbol for OpenAI
        }
    }

    /// Creates the appropriate voice service instance
    func createService(sessionState: SessionState) -> VoiceService {
        switch self {
        case .xai:
            return XAIVoiceService(sessionState: sessionState, sampleRate: .thirtyTwoKHz)
        case .openai:
            return OpenAIVoiceService(sessionState: sessionState, sampleRate: 24000)
        }
    }
}
