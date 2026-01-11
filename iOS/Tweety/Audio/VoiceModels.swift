//
//  VoiceModels.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/18/25.
//
//  Protocol-based abstractions for voice services

import Foundation

// MARK: - Common Voice Events

/// Events that can be received from a voice service
enum VoiceEvent {
    case sessionCreated
    case sessionConfigured
    case userSpeechStarted
    case userSpeechStopped
    case assistantSpeaking(itemId: String?)
    case audioDelta(data: Data)
    case toolCall(VoiceToolCall)
    case error(String)
    case other // For events we don't specifically handle
}

/// Represents a tool call from the assistant
struct VoiceToolCall {
    let id: String
    let name: String
    let arguments: String
    let itemId: String?
}

// MARK: - Session Configuration

/// Configuration for initializing a voice session
struct VoiceSessionConfig {
    let instructions: String
    let tools: [VoiceToolDefinition]?
    let sampleRate: Int
}

/// Tool definition for voice session
struct VoiceToolDefinition {
    let type: String
    let name: String
    let description: String
    let parameters: [String: Any]

    init(type: String, name: String, description: String, parameters: [String: Any]) {
        self.type = type
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

/// Result of sending a tool output
struct VoiceToolOutput {
    let toolCallId: String
    let output: String
    let success: Bool
    let previousItemId: String?
}
