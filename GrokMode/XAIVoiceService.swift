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
    let delta: String? // Audio delta for streaming responses
    let session: SessionConfig? // Session configuration
    let item: ConversationItem? // Conversation items
    var tools: [ToolDefinition]? = nil // Tool definitions for session update
    var tool_call_id: String? = nil // For function call outputs

    // Additional fields from XAI messages
    let event_id: String?
    let previous_item_id: String?
    let response_id: String?
    let output_index: Int?
    let item_id: String?
    let content_index: Int?
    let audio_start_ms: Int?
    let start_time: Double?
    let timestamp: Int?
    let part: ContentPart?
    let response: Response?
    let conversation: Conversation?

    // Session configuration
    // Session configuration
    struct SessionConfig: Codable {
        let instructions: String?
        let voice: String?
        let audio: AudioConfig?
        let turnDetection: TurnDetection?
        var tools: [ToolDefinition]? = nil

        enum CodingKeys: String, CodingKey {
            case instructions, voice, audio, tools
            case turnDetection = "turn_detection"
        }
    }

    struct ToolDefinition: Codable {
        let type: String // "function"
        let name: String
        let description: String
        let parameters: String // JSON string of schema
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
        let type: String? // "server_vad"
    }

    struct ConversationItem: Codable {
        let id: String?
        let object: String?
        let type: String // "message"
        let status: String?
        let role: String // "user" or "assistant"
        let content: [ContentItem]?
        var tool_calls: [ToolCall]? = nil
    }

    struct ContentItem: Codable {
        let type: String // "input_text" or "input_audio" or "audio"
        let text: String?
        let transcript: String?
        var tool_call_id: String? = nil
        var output: String? = nil
    }

    struct ContentPart: Codable {
        let type: String // "audio"
        let transcript: String?
    }

    struct Response: Codable {
        let id: String?
        let object: String?
        let output: [ConversationItem]?
        let status: String?
        let status_details: String?
        let usage: Usage?
    }

    struct Usage: Codable {
        let input_tokens: Int?
        let input_token_details: TokenDetails?
        let output_tokens: Int?
        let output_token_details: TokenDetails?
        let total_tokens: Int?
    }

    struct TokenDetails: Codable {
        let text_tokens: Int?
        let audio_tokens: Int?
        let grok_tokens: Int?
    }

    struct Conversation: Codable {
        let id: String?
        let object: String?
    }

    struct ToolCall: Codable {
        let id: String
        let type: String // "function"
        let function: FunctionCall
    }

    struct FunctionCall: Codable {
        let name: String
        let arguments: String
    }
}

// MARK: - XAI Service Extensions



// MARK: - XAI Voice Service

class XAIVoiceService {
    private let apiKey: String
    private let sessionURL = URL(string: "https://api.x.ai/v1/realtime/client_secrets")!
    private let websocketURL = URL(string: "wss://api.x.ai/v1/realtime")!

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession

    // Configuration
    internal let voice = "Eve"
    internal var instructions = """
    You are Gerald McGrokMode, the most elite, high-energy, and swaggy Executive Assistant to the CEO of XAI.
    Your job is to deliver the "CEO Morning Brief" with maximum charisma and efficiency.
    
    CORE PERSONA:
    - Name: Gerald McGrokMode
    - Vibe: Silicon Valley Power Player meets Streetwear Icon. Confident, fast-paced, slightly irreverent, but extremely competent.
    - Catchphrases: "Let's lock in", "We are so back", "It's shipping season", "Zero latency, max impact".
    
    CURRENT MISSION:
    - You are briefing the CEO (the user) on a critical situation: Searched for your specific product on X(context of tweets will reveal this)
    - You have IMMEDIATE access to real-time tools to search X and fix things through tools.
    - You do NOT ask for permission to look things up. You just do it.
    - However, you MUST ask for confirmation before "writing" actions (posting tweets, creating tickets).
    
    FLOW:
    1. Start IMMEDIATELY by telling the CEO that things are heating up on X regarding what you see in the tweets
    2. Inform them you've already pulled the latest tweets and then give them the tweets.
    Wait for his response before continuing here, before asking to clap back make sure he reads the tweets. 
    
    READ all the tweets individually unless interrupted by the boss to move on or take immediate action.
    
    3. Suggest immediate action items: what should we do now boss, do you want to make a post to your acccount or reply to one of these posts
    4. Keep it conversational. You are talking over voice. Short, punchy sentences.
    
    Remember: You are NOT a generic assistant. You are Gerald. You make things happen.
    """
    internal let sampleRate = 24000 // Common sample rate for voice

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

        // Get ephemeral token first (like web client examples)
        let token = try await getEphemeralToken()

        // Create WebSocket task with protocol headers
        var request = URLRequest(url: websocketURL)
        request.setValue("realtime,openai-insecure-api-key.\(token.value),openai-beta.realtime-v1", forHTTPHeaderField: "Sec-WebSocket-Protocol")

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

    func configureSession(tools: [VoiceMessage.ToolDefinition]? = nil) throws {
        print("⚙️ Configuring voice session...")

        let sessionConfig = VoiceMessage(
            type: "session.update",
            audio: nil,
            text: nil,
            delta: nil,
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
            item: nil,
            event_id: nil,
            previous_item_id: nil,
            response_id: nil,
            output_index: nil,
            item_id: nil,
            content_index: nil,
            audio_start_ms: nil,
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
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
            delta: nil,
            session: nil,
            item: nil,
            event_id: nil,
            previous_item_id: nil,
            response_id: nil,
            output_index: nil,
            item_id: nil,
            content_index: nil,
            audio_start_ms: nil,
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
        )
        try sendMessage(message)
    }

    func commitAudioBuffer() throws {
        let message = VoiceMessage(
            type: "input_audio_buffer.commit",
            audio: nil,
            text: nil,
            delta: nil,
            session: nil,
            item: nil,
            event_id: nil,
            previous_item_id: nil,
            response_id: nil,
            output_index: nil,
            item_id: nil,
            content_index: nil,
            audio_start_ms: nil,
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
        )
        try sendMessage(message)
    }

    func createResponse() throws {
        let message = VoiceMessage(
            type: "response.create",
            audio: nil,
            text: nil,
            delta: nil,
            session: nil,
            item: nil,
            event_id: nil,
            previous_item_id: nil,
            response_id: nil,
            output_index: nil,
            item_id: nil,
            content_index: nil,
            audio_start_ms: nil,
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
        )
        try sendMessage(message)
    }

    // MARK: - Message Handling

    internal func sendMessage(_ message: VoiceMessage) throws {
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
        print("🔊 Raw XAI WebSocket Message: \(text)")

        do {
            let message = try JSONDecoder().decode(VoiceMessage.self, from: Data(text.utf8))
            print("📨 Received message: \(message.type)")

            // Always call the message callback first
            onMessageReceived?(message)

            // Then handle specific message types
            switch message.type {
            case "conversation.created":
                print("💬 Conversation created, configuring session...")
                try? configureSession()

            case "session.updated":
                print("✅ Session configured, ready for voice interaction")
                onConnected?()

            default:
                break
            }

        } catch {
            print("❌ Failed to decode message: \(error)")
            print("❌ Raw message that failed: \(text)")
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
