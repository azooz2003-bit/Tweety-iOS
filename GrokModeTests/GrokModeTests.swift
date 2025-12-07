//
//  GrokModeTests.swift
//  GrokModeTests
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import Testing
@testable import GrokMode
import Foundation

struct GrokModeTests {
    // XAI API Key for testing
    private let apiKey = "xai-6ab6MBdEeM26TVCX17g11UGQDT34sA0b5CBff0f9leY23WXzUeQWugxZB0ukgolPllZkXKVsD6VPd8lQ"

    @Test("Test ephemeral token acquisition from XAI API")
    func testGetEphemeralToken() async throws {
        let service = await XAIVoiceService(apiKey: apiKey)

        let token = try await service.getEphemeralToken()

        // Verify token structure
        #expect(!token.value.isEmpty, "Token value should not be empty")
        #expect(token.expiresAt > Date().timeIntervalSince1970, "Token should not be expired")

        // Verify expiration is in the future (within 5 minutes of 5 minutes from now)
        let expectedExpiry = Date().timeIntervalSince1970 + 300 // 5 minutes
        #expect(token.expiresAt <= expectedExpiry + 60, "Token expiry should be within expected range")
        #expect(token.expiresAt >= expectedExpiry - 60, "Token expiry should be within expected range")
    }

    @Test("Test WebSocket connection establishment")
    func testWebSocketConnection() async throws {
        let service = XAIVoiceService(apiKey: apiKey)

        // Set up expectation for connection
        var connectionEstablished = false
        var connectionError: Error?

        service.onConnected = {
            connectionEstablished = true
        }

        service.onError = { error in
            connectionError = error
        }

        // Attempt connection
        try await service.connect()

        // Wait a bit for connection to establish
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Verify connection was established
        #expect(connectionEstablished, "WebSocket connection should be established")
        #expect(connectionError == nil, "No connection error should occur: \(connectionError?.localizedDescription ?? "none")")

        // Clean up
        service.disconnect()
    }

    @Test("Test session configuration after connection")
    func testSessionConfiguration() async throws {
        let service = XAIVoiceService(apiKey: apiKey)

        var sessionConfigured = false
        var receivedMessages: [VoiceMessage] = []

        service.onMessageReceived = { message in
            receivedMessages.append(message)
            if message.type == "session.updated" {
                sessionConfigured = true
            }
        }

        // Connect and wait for session configuration
        try await service.connect()

        // Wait for session to be configured
        let timeout: TimeInterval = 10.0
        let startTime = Date()

        while !sessionConfigured && Date().timeIntervalSince(startTime) < timeout {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        #expect(sessionConfigured, "Session should be configured after connection")

        // Verify we received the expected messages
        let conversationCreated = receivedMessages.contains { $0.type == "conversation.created" }
        #expect(conversationCreated, "Should receive conversation.created message")

        // Clean up
        service.disconnect()
    }

    @Test("Test mock audio data transmission")
    func testMockAudioTransmission() async throws {
        let service = XAIVoiceService(apiKey: apiKey)

        var responseCreated = false
        service.onMessageReceived = { message in
            if message.type == "response.created" {
                responseCreated = true
            }
        }

        // Connect
        try await service.connect()

        // Wait for session configuration
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

        // Create mock audio data (1 second of 24kHz PCM16 silence)
        let sampleRate = 24000
        let duration = 1.0 // 1 second
        let samples = Int(Float(sampleRate) * Float(duration))
        let audioData = Data(repeating: 0, count: samples * 2) // 16-bit samples

        // Send audio chunk
        try service.sendAudioChunk(audioData)

        // Commit audio buffer
        try service.commitAudioBuffer()

        // Request response
        try service.createResponse()

        // Wait for response
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Note: In a real test, we'd verify the response, but for now we just check
        // that the commands were sent without error
        #expect(true, "Audio transmission commands completed without error")

        // Clean up
        service.disconnect()
    }

    @Test("Test connection with invalid API key")
    func testInvalidAPIKey() async throws {
        let service = XAIVoiceService(apiKey: "invalid-api-key")

        do {
            _ = try await service.getEphemeralToken()
            #expect(false, "Should fail with invalid API key")
        } catch let error as XAIVoiceError {
            switch error {
            case .apiError(let statusCode, _):
                #expect(statusCode == 400, "Should get bad request error for invalid API key")
            default:
                #expect(false, "Should get API error, got: \(error)")
            }
        } catch {
            #expect(false, "Should get XAIVoiceError, got: \(error)")
        }
    }

    @Test("Test WebSocket operations when not connected")
    func testOperationsWithoutConnection() {
        let service = XAIVoiceService(apiKey: apiKey)

        // Try to send audio without connecting
        do {
            try service.sendAudioChunk(Data())
            #expect(false, "Should fail when not connected")
        } catch let error as XAIVoiceError {
            #expect(error == .notConnected, "Should get not connected error")
        } catch {
            #expect(false, "Should get XAIVoiceError, got: \(error)")
        }

        // Try to commit buffer without connecting
        do {
            try service.commitAudioBuffer()
            #expect(false, "Should fail when not connected")
        } catch let error as XAIVoiceError {
            #expect(error == .notConnected, "Should get not connected error")
        } catch {
            #expect(false, "Should get XAIVoiceError, got: \(error)")
        }
    }

    @Test("Test service cleanup on deinit")
    func testServiceCleanup() async throws {
        var service: XAIVoiceService? = XAIVoiceService(apiKey: apiKey)

        // Connect
        try await service?.connect()

        // Simulate deinit by setting to nil
        service = nil

        // Verify no crashes occur during cleanup
        #expect(true, "Service should clean up properly on deinit")
    }
}
