//
//  VoiceService.swift
//  GrokMode
//
//  Created by Claude Code on 12/18/25.
//

import Foundation

/// Protocol defining the interface for voice service implementations
protocol VoiceService: AnyObject {
    // Session state
    var sessionState: SessionState { get }

    // Service-specific sample rate requirement
    var requiredSampleRate: Int { get }

    // Callbacks - use abstracted VoiceEvent instead of service-specific types
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: ((Error?) -> Void)? { get set }
    var onEvent: ((VoiceEvent) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    // Connection management
    func connect() async throws
    func disconnect()

    // Session configuration - use abstracted types
    func configureSession(config: VoiceSessionConfig, tools: [VoiceToolDefinition]?) throws

    // Audio streaming
    func sendAudioChunk(_ audioData: Data) throws
    func commitAudioBuffer() throws
    func createResponse() throws

    // Tool handling - use abstracted types
    func sendToolOutput(_ output: VoiceToolOutput) throws
}

/// Common errors that can occur with voice services
enum VoiceServiceError: LocalizedError {
    case notConnected
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case authenticationFailed
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Voice service is not connected"
        case .invalidResponse:
            return "Received invalid response from server"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .authenticationFailed:
            return "Failed to authenticate with voice service"
        case .configurationFailed:
            return "Failed to configure voice session"
        }
    }
}
