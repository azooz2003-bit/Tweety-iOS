//
//  XAIVoiceService.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import Foundation
import OSLog

class XAIVoiceService {
    private let baseProxyURL: URL = Config.baseXAIProxyURL
    private let baseURL: URL = Config.baseXAIURL
    private var sessionURL: URL { baseProxyURL.appending(path: "v1/realtime/client_secrets") }
    private var websocketURL: URL { baseURL.appending(path: "v1/realtime")}

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    let sessionState: SessionState

    // Configuration
    let voice = ConversationEvent.SessionConfig.Voice.Eve
    var instructions = """
    You are Tweety, a voice assistant that acts as the voice gateway to everything in a user's X account. You do everything reliably, and you know when to prioritize speed.

    Requirements:
    - Always validate that the parameters of tool calls are going to be correct. For instance, if a tool parameter's description notes a specific value range, prevent all tool calls that violate that. Another example, if you're unsure about whether an ID passed as a param will be correct, try finding out via another tool call.
    - DO NOT READ RAW METADATA FROM TOOL RESPONSES such as Ids (including but not limited to tweet ids, user profile ids, etc.). This is the most important thing.
    - Keep it conversational. You are talking over voice. Short, punchy sentences.
    - ALWAYS use tool calls
    - Don't excessively repeat yourself, make sure you don't repeat info too many times. Especially when you get multiple tool call results.
    - Whenever a user asks for a name, the username doesn't have to match it exactly.

    VOICE CONFIRMATION:
    - When a tool requires user confirmation, you will receive a response saying "This action requires user confirmation." The response will include the tool call ID.
    - When this happens, clearly ask the user: "Should I do this? Say yes to confirm or no to cancel."
    - Wait for their voice response
    - If they say "yes", "confirm", "do it", "go ahead", or similar affirmations, call the confirm_action tool with the tool_call_id parameter set to the original tool call's ID
    - If they say "no", "cancel", "don't", "stop", or similar rejections, call the cancel_action tool with the tool_call_id parameter set to the original tool call's ID
    - IMPORTANT: Always pass the tool_call_id parameter when calling confirm_action or cancel_action - this tells the system which action you're confirming or cancelling
    - Only use these tools when you've received a confirmation request, not at any other time

    CURRENT MISSION:
    - You do NOT ask for permission to look things up. You just do it.
    - You are concise in your answers to save the user's time.
    - Always aim to provide a summary rather than the whole answer. For instance, if you're prompted to fetch any content, don't read all of them verbatim unless explicitly asked to do so.
    - Always plan the chain of tool calls you plan to make meticulously. For instance, if you need to search the authenticated user's followers before dm'ing that follower (the user asked you "dm person XYZ from my followers"), start by calling get_authenticated_user => then get_user_followers => then finally send_dm_to_participant. Plan your tool calls carefully and as it makes sense.
    - If you make multiple tool calls, or are in the process of making multiple tool calls, don't speak until all the tool calls you've made are done.
    """
    let sampleRate: ConversationEvent.AudioFormatType.SampleRate // Common sample rate for voice

    // Callbacks
    var onConnected: (() -> Void)?
    var onDisconnected: ((Error?) -> Void)?
    var onMessageReceived: ((ConversationEvent) -> Void)?
    var onError: ((Error) -> Void)?

    init(sessionState: SessionState, sampleRate: ConversationEvent.AudioFormatType.SampleRate = .twentyFourKHz) {
        self.sessionState = sessionState
        self.sampleRate = sampleRate
        self.urlSession = URLSession(configuration: .default)
    }

    // MARK: - Token Acquisition
    func getEphemeralToken() async throws -> SessionToken {
        AppLogger.network.info("Requesting ephemeral token")

        var request = URLRequest(url: sessionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.appSecret, forHTTPHeaderField: "X-App-Secret")

        let requestBody = ["expires_after": ["seconds": 300]]
        request.httpBody = try JSONEncoder().encode(requestBody)

        #if DEBUG
        AppLogger.network.debug("Token request URL: \(self.sessionURL.absoluteString)")
        AppLogger.logSensitive(AppLogger.network, level: .debug, "Request headers: \(request.allHTTPHeaderFields?.description ?? "none")")
        #endif

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.network.error("Invalid HTTP response type")
                throw XAIVoiceError.invalidResponse
            }

            #if DEBUG
            AppLogger.network.debug("Response status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                AppLogger.logSensitive(AppLogger.network, level: .debug, "Response body: \(responseString)")
            }
            #endif

            guard httpResponse.statusCode == 200 else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                AppLogger.network.error("Token request failed: HTTP \(httpResponse.statusCode) - \(errorText)")
                throw XAIVoiceError.apiError(statusCode: httpResponse.statusCode, message: errorText)
            }

            let sessionToken = try JSONDecoder().decode(SessionToken.self, from: data)

            #if DEBUG
            AppLogger.logSensitive(AppLogger.network, level: .info, "Token acquired: \(AppLogger.redacted(sessionToken.value))")
            AppLogger.network.debug("Token expires in: \(Int(sessionToken.expiresAt - Date().timeIntervalSince1970))s")
            #else
            AppLogger.network.info("Token acquired successfully")
            #endif

            return sessionToken

        } catch let error as XAIVoiceError {
            throw error
        } catch {
            AppLogger.network.error("Token request failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - WebSocket Connection
    func connect() async throws {
        AppLogger.voice.info("Connecting to XAI Voice API")

        let token = try await getEphemeralToken()

        var request = URLRequest(url: websocketURL)
        request.setValue("Bearer \(token.value)", forHTTPHeaderField: "Authorization")

        #if DEBUG
        AppLogger.voice.debug("WebSocket URL: \(self.websocketURL.absoluteString)")
        #endif

        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()

        receiveMessages()

        AppLogger.voice.info("WebSocket connected successfully")
    }

    // MARK: - Session Configuration

    func configureSession(tools: [ConversationEvent.ToolDefinition]? = nil) throws {
        AppLogger.voice.info("Configuring voice session")

        let sessionConfig = ConversationEvent(
            type: .sessionUpdate,
            audio: nil,
            text: nil,
            delta: nil,
            session: ConversationEvent.SessionConfig(
                instructions: instructions + "\n\nToday's Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none)).",
                voice: voice,
                audio: ConversationEvent.AudioConfig(
                    input: ConversationEvent.AudioFormat(
                        format: ConversationEvent.AudioFormatType(
                            type: .audioPcm,
                            rate: sampleRate
                        )
                    ),
                    output: ConversationEvent.AudioFormat(
                        format: ConversationEvent.AudioFormatType(
                            type: .audioPcm,
                            rate: sampleRate
                        )
                    )
                ),
                turnDetection: ConversationEvent.TurnDetection(type: .serverVad),
                tools: tools,
                tool_choice: tools != nil ? "auto" : nil
            ),
            item: nil,
            event_id: nil,
            previous_item_id: nil,
            response_id: nil,
            output_index: nil,
            item_id: nil,
            content_index: nil,
            audio_start_ms: nil,
            audio_end_ms: nil,
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
        let message = ConversationEvent(
            type: .inputAudioBufferAppend,
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
            audio_end_ms: nil,
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
        )
        try sendMessage(message)
    }

    func commitAudioBuffer() throws {
        let message = ConversationEvent(
            type: .inputAudioBufferCommit,
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
            audio_end_ms: nil,
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
        )
        try sendMessage(message)
    }

    func createResponse() throws {
        let message = ConversationEvent(
            type: .responseCreate,
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
            audio_end_ms: nil,
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
        )
        try sendMessage(message)
    }
    
    func sendToolOutput(toolCallId: String, output: String, success: Bool) throws {
        // Log response to SessionState
        sessionState.updateResponse(id: toolCallId, responseString: output, success: success)
        
        let toolOutput = ConversationEvent(
            type: .conversationItemCreate,
            audio: nil,
            text: nil,
            delta: nil,
            session: nil,
            item: ConversationEvent.ConversationItem(
                id: nil,
                object: nil,
                type: "function_call_output",
                status: nil,
                role: nil,
                content: nil,
                tool_calls: nil,
                call_id: toolCallId,
                output: output,
                name: nil,
                arguments: nil
            ),
            event_id: nil,
            previous_item_id: nil,
            response_id: nil,
            output_index: nil,
            item_id: nil,
            content_index: nil,
            audio_start_ms: nil,
            audio_end_ms: nil,
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
        )
        try sendMessage(toolOutput)
        
        // Trigger response creation if needed immediately
        // try createResponse()
    }

    func sendTruncationEvent(itemId: String, audioEndMs: Int, contentIndex: Int = 0) throws {
        AppLogger.voice.debug("Truncating item \(itemId) at \(audioEndMs)ms")
        let message = ConversationEvent(
            type: .conversationItemTruncate,
            audio: nil,
            text: nil,
            delta: nil,
            session: nil,
            item: nil,
            tools: nil,
            tool_call_id: nil,
            call_id: nil,
            name: nil,
            arguments: nil,
            event_id: nil,
            previous_item_id: nil,
            response_id: nil,
            output_index: nil,
            item_id: itemId,
            content_index: contentIndex,
            audio_start_ms: nil,
            audio_end_ms: audioEndMs,
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
        )
        try sendMessage(message)
    }

    // MARK: - Message Handling

    internal func sendMessage(_ message: ConversationEvent) throws {
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            throw XAIVoiceError.notConnected
        }

        let jsonData = try JSONEncoder().encode(message)
        let messageString = String(data: jsonData, encoding: .utf8)!

        let wsMessage = URLSessionWebSocketTask.Message.string(messageString)

        #if DEBUG
        AppLogger.voice.debug("Sending event: \(message.type.rawValue)")
        #endif

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
                AppLogger.voice.error("WebSocket receive error: \(error.localizedDescription)")
                self.onDisconnected?(error)
            }
        }
    }

    private func handleTextMessage(_ text: String) {
        guard let message = try? JSONDecoder().decode(ConversationEvent.self, from: Data(text.utf8)) else {
            #if DEBUG
            AppLogger.voice.warning("Received unanticipated message format")
            AppLogger.logSensitive(AppLogger.voice, level: .debug, "Message content: \(text)")
            #endif
            return
        }

        onMessageReceived?(message)

        #if DEBUG
        AppLogger.voice.debug("Received message: \(message.type.rawValue)")
        #endif

        switch message.type {
        case .conversationCreated:
            AppLogger.voice.info("Conversation created, configuring session")
            try? configureSession()

        case .sessionUpdated:
            AppLogger.voice.info("Session configured successfully")
            onConnected?()

        case .responseFunctionCallArgumentsDone:
             if let callId = message.call_id,
                let name = message.name,
                let arguments = message.arguments {

                 AppLogger.tools.info("Tool call received: \(name)")
                 let params: [String: Any]? = {
                     guard let data = arguments.data(using: .utf8) else { return nil }
                     return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                 }()

                 sessionState.addCall(id: callId, toolName: name, parameters: params ?? ["raw": arguments])
             }

        default:
            break
        }
    }

    private func handleDataMessage(_ data: Data) {
        #if DEBUG
        AppLogger.voice.debug("Received binary data: \(data.count) bytes")
        #endif
    }

    // MARK: - Connection Management

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        AppLogger.voice.info("WebSocket disconnected")
    }

    deinit {
        disconnect()
    }
}
