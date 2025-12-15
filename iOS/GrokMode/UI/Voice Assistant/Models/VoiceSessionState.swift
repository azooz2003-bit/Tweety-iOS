//
//  VoiceSessionState.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/14/25.
//

import Foundation

enum VoiceSessionState: Equatable {
    case disconnected
    case connecting
    case connected
    case listening
    case grokSpeaking(itemId: String?)
    case error(String)

    var isConnected: Bool {
        switch self {
        case .connected, .listening, .grokSpeaking: return true
        default: return false
        }
    }

    var isConnecting: Bool {
        if case .connecting = self { return true }
        return false
    }

    var isListening: Bool {
        if case .listening = self { return true }
        return false
    }

    var isGrokSpeaking: Bool {
        if case .grokSpeaking = self { return true }
        return false
    }

    var canStartListening: Bool {
        if case .connected = self { return true }
        return false
    }
}
