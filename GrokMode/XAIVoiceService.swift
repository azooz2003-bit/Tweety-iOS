//
//  XAIVoiceService.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import Foundation

// MARK: - Data Models

struct SessionToken: Codable {
    let value: String
    let expiresAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case value
        case expiresAt = "expires_at"
    }
}

struct VoiceMessage: Codable {
    let type: String
    let audio: String? // Base64 encoded audio data
    let text: String? // Text content
    let session: SessionConfig? // Session configuration
    let item: ConversationItem? // Conversation items

    // Session configuration
    struct SessionConfig: Codable {
        let instructions: String?
        let voice: String?
        let audio: AudioConfig?
        let turnDetection: TurnDetection?

        enum CodingKeys: String, CodingKey {
            case instructions, voice, audio
            case turnDetection = "turn_detection"
        }
    }

    struct AudioConfig: Codable {
        let input: AudioFormat?
        let output: AudioFormat?
    }

    struct AudioFormat: Codable {
        let format: AudioFormatType?

        enum CodingKeys: String, CodingKey {
            case format
        }
    }

    struct AudioFormatType: Codable {
        let type: String // "audio/pcm"
        let rate: Int // Sample rate
    }

    struct TurnDetection: Codable {
        let type: String // "server_vad"
    }

    struct ConversationItem: Codable {
        let type: String // "message"
        let role: String // "user" or "assistant"
        let content: [ContentItem]
    }

    struct ContentItem: Codable {
        let type: String // "input_text" or "input_audio"
        let text: String?
    }
}

// MARK: - XAI Voice Service

class XAIVoiceService {
    private let apiKey: String
    private let sessionURL = URL(string: "https://api.x.ai/v1/realtime/client_secrets")!
    private let websocketURL = URL(string: "wss://api.x.ai/v1/realtime")!

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession

    // Configuration
    private let voice = "ara"
    private let instructions = "You are a helpful voice assistant. You are speaking to a user in real-time over audio. Keep your responses conversational and concise since they will be spoken aloud."
    private let sampleRate = 24000 // Common sample rate for voice

    // Callbacks
    var onConnected: (() -> Void)?
    var onDisconnected: ((Error?) -> Void)?
    var onMessageReceived: ((VoiceMessage) -> Void)?
    var onError: ((Error) -> Void)?

    init(apiKey: String) {
        self.apiKey = apiKey
        self.urlSession = URLSession(configuration: .default)
    }

    // MARK: - Token Acquisition

    func getEphemeralToken() async throws -> SessionToken {
        print("🔑 ===== STARTING EPHEMERAL TOKEN REQUEST =====")
        print("🔑 Requesting ephemeral token from XAI API...")
        print("🔑 URL: \(sessionURL.absoluteString)")

        var request = URLRequest(url: sessionURL)
        request.httpMethod = "POST"
        print("🔑 HTTP Method: \(request.httpMethod ?? "UNKNOWN")")

        // Set headers
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        print("🔑 Request Headers:")
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key.lowercased().contains("authorization") {
                    print("🔑   \(key): Bearer ***\(apiKey.suffix(10))***") // Hide most of API key
                } else {
                    print("🔑   \(key): \(value)")
                }
            }
        }

        // Create request body
        let requestBody = ["expires_after": ["seconds": 300]]
        print("🔑 Request Body (JSON):")
        print("🔑   \(requestBody)")

        let jsonData = try JSONEncoder().encode(requestBody)
        request.httpBody = jsonData

        print("🔑 Request Body (Raw):")
        if let bodyString = String(data: jsonData, encoding: .utf8) {
            print("🔑   \(bodyString)")
        }

        print("🔑 ===== SENDING REQUEST =====")

        do {
            let (data, response) = try await urlSession.data(for: request)

            print("🔑 ===== RECEIVED RESPONSE =====")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ ERROR: Response is not HTTPURLResponse")
                print("❌ Response type: \(type(of: response))")
                print("❌ Response: \(response)")
                throw XAIVoiceError.invalidResponse
            }

            print("🔑 Response Status Code: \(httpResponse.statusCode)")
            print("🔑 Response Status: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")

            print("🔑 Response Headers:")
            for (key, value) in httpResponse.allHeaderFields {
                print("🔑   \(key): \(value)")
            }

            print("🔑 Response Body (Raw Data Length): \(data.count) bytes")

            if let responseString = String(data: data, encoding: .utf8) {
                print("🔑 Response Body (String):")
                print("🔑   \(responseString)")
            } else {
                print("❌ ERROR: Cannot convert response data to string")
                print("❌ Response Data (Hex): \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
            }

            guard httpResponse.statusCode == 200 else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ ERROR: HTTP \(httpResponse.statusCode) - \(errorText)")
                throw XAIVoiceError.apiError(statusCode: httpResponse.statusCode, message: errorText)
            }

            print("🔑 ===== PARSING JSON RESPONSE =====")

            do {
                let sessionToken = try JSONDecoder().decode(SessionToken.self, from: data)
                print("✅ Successfully parsed JSON response")
                print("✅ Token Value: \(sessionToken.value.prefix(10))...\(sessionToken.value.suffix(10))")
                print("✅ Token Expires At: \(Date(timeIntervalSince1970: sessionToken.expiresAt))")
                print("✅ Token Expires In: \(sessionToken.expiresAt - Date().timeIntervalSince1970) seconds")

                print("✅ ===== TOKEN ACQUISITION SUCCESSFUL =====")
                return sessionToken

            } catch let decodingError {
                print("❌ ERROR: Failed to decode JSON response")
                print("❌ Decoding Error: \(decodingError)")
                print("❌ Raw Response Data: \(String(data: data, encoding: .utf8) ?? "Cannot decode")")
                throw decodingError
            }

        } catch let networkError {
            print("❌ ERROR: Network request failed")
            print("❌ Network Error: \(networkError)")
            print("❌ Error Type: \(type(of: networkError))")
            throw networkError
        }
    }

    // MARK: - WebSocket Connection

    func connect() async throws {
        print("🔌 Connecting to XAI Voice API...")

        // Get ephemeral token first
        let token = try await getEphemeralToken()

        // Create WebSocket task with protocol headers
        var request = URLRequest(url: websocketURL)
        request.setValue("realtime", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.setValue("openai-insecure-api-key.\(token.value)", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        request.setValue("openai-beta.realtime-v1", forHTTPHeaderField: "Sec-WebSocket-Protocol")

        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()

        // Start receiving messages
        receiveMessages()

        // Wait for connection to be established
        try await waitForConnection()

        print("✅ WebSocket connected to XAI API")
    }

    private func waitForConnection() async throws {
        // Simple timeout-based wait for connection
        let timeout: TimeInterval = 10.0
        let startTime = Date()

        while webSocketTask?.state != .running {
            if Date().timeIntervalSince(startTime) > timeout {
                throw XAIVoiceError.connectionTimeout
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }

    // MARK: - Session Configuration

    func configureSession() throws {
        print("⚙️ Configuring voice session...")

        let sessionConfig = VoiceMessage(
            type: "session.update",
            audio: nil,
            text: nil,
            session: VoiceMessage.SessionConfig(
                instructions: instructions,
                voice: voice,
                audio: VoiceMessage.AudioConfig(
                    input: VoiceMessage.AudioFormat(
                        format: VoiceMessage.AudioFormatType(
                            type: "audio/pcm",
                            rate: sampleRate
                        )
                    ),
                    output: VoiceMessage.AudioFormat(
                        format: VoiceMessage.AudioFormatType(
                            type: "audio/pcm",
                            rate: sampleRate
                        )
                    )
                ),
                turnDetection: VoiceMessage.TurnDetection(type: "server_vad")
            ),
            item: nil
        )

        try sendMessage(sessionConfig)
    }

    // MARK: - Audio Streaming

    func sendAudioChunk(_ audioData: Data) throws {
        let base64Audio = audioData.base64EncodedString()
        let message = VoiceMessage(
            type: "input_audio_buffer.append",
            audio: base64Audio,
            text: nil,
            session: nil,
            item: nil
        )
        try sendMessage(message)
    }

    func commitAudioBuffer() throws {
        let message = VoiceMessage(
            type: "input_audio_buffer.commit",
            audio: nil,
            text: nil,
            session: nil,
            item: nil
        )
        try sendMessage(message)
    }

    func createResponse() throws {
        let message = VoiceMessage(
            type: "response.create",
            audio: nil,
            text: nil,
            session: nil,
            item: nil
        )
        try sendMessage(message)
    }

    // MARK: - Message Handling

    private func sendMessage(_ message: VoiceMessage) throws {
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            throw XAIVoiceError.notConnected
        }

        let jsonData = try JSONEncoder().encode(message)
        let messageString = String(data: jsonData, encoding: .utf8)!

        let wsMessage = URLSessionWebSocketTask.Message.string(messageString)
        webSocketTask.send(wsMessage) { error in
            if let error = error {
                self.onError?(error)
            }
        }
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleTextMessage(text)
                case .data(let data):
                    self.handleDataMessage(data)
                @unknown default:
                    break
                }

                // Continue receiving messages
                self.receiveMessages()

            case .failure(let error):
                print("❌ WebSocket receive error: \(error)")
                self.onDisconnected?(error)
            }
        }
    }

    private func handleTextMessage(_ text: String) {
        do {
            let message = try JSONDecoder().decode(VoiceMessage.self, from: Data(text.utf8))
            print("📨 Received message: \(message.type)")

            // Handle specific message types
            switch message.type {
            case "conversation.created":
                print("💬 Conversation created, configuring session...")
                try? configureSession()

            case "session.updated":
                print("✅ Session configured, ready for voice interaction")
                onConnected?()

            default:
                onMessageReceived?(message)
            }

        } catch {
            print("❌ Failed to decode message: \(error)")
            onError?(error)
        }
    }

    private func handleDataMessage(_ data: Data) {
        // Handle binary data if needed
        print("📦 Received binary data: \(data.count) bytes")
    }

    // MARK: - Connection Management

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        print("🔌 WebSocket disconnected")
    }

    deinit {
        disconnect()
    }
}

// MARK: - Error Types

enum XAIVoiceError: Error, Equatable{
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case connectionTimeout
    case notConnected
    case invalidToken

    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .connectionTimeout:
            return "WebSocket connection timed out"
        case .notConnected:
            return "WebSocket is not connected"
        case .invalidToken:
            return "Invalid or expired token"
        }
    }
}
