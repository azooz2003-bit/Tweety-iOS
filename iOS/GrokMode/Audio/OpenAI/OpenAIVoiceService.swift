//
//  OpenAIVoiceService.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/18/25.
//

import Foundation
import OSLog
import JSONSchema
internal import OrderedCollections

class OpenAIVoiceService: VoiceService {
    private let baseProxyURL: URL = Config.baseOpenAIProxyURL
    private let baseURL: URL = Config.baseOpenAIURL
    private var tokenURL: URL { baseProxyURL.appending(path: "v1/realtime/client_secrets") }
    private var websocketURL: URL { baseURL.appending(path: "v1/realtime").appending(queryItems: [URLQueryItem(name: "model", value: "gpt-realtime")]) }

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    let sessionState: SessionState

    var requiredSampleRate: Int { sampleRate }

    // Configuration - OpenAI specific
    enum Voice: String, Codable {
        case alloy, ash, ballad, coral, echo, sage, shimmer, verse
    }

    let voice: Voice
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

    PAGINATION HANDLING:
    Many tools return paginated results (tweets, DMs, followers, etc.). When you receive paginated results:

    DEFAULT BEHAVIOR (Page-by-Page):
    - After presenting results to the user, ask if they'd like to see more (e.g., "Would you like me to show you more?")
    - Only fetch the next page when the user confirms (e.g., "yes", "show me more", "continue", "next", "keep going")
    - Never automatically fetch multiple pages without user confirmation for each page
    - If you've already fetched 3+ pages, warn the user about data usage and ask if they want to continue

    EXCEPTION - Batch Fetching for "ALL" Requests:
    If the user EXPLICITLY requests ALL results using words like "all", "every", "complete", "entire" (e.g., "give me ALL my DMs with Allen", "show me EVERY tweet I liked"), you may automatically fetch multiple pages WITHOUT asking each time, BUT ONLY when:
    - The query is finite and scoped (specific conversation DMs, specific user's content, user's bookmarks, specific list members)
    - NEVER for unbounded searches (e.g., "all tweets about AI", general searches, trending topics - these are infinite)
    - Stop after 10 pages maximum and inform the user
    - Before starting, tell the user you're fetching all results (e.g., "I'll fetch all your DMs with Allen, this may take a moment...")
    - After completion, summarize total results (e.g., "I retrieved 87 messages across 4 pages")

    Listen carefully to user intent, not just keywords
    If unclear, ask for clarification rather than guessing
    """
    private let sampleRate: Int

    // Track current assistant response item for truncation
    private var currentAssistantItemId: String?
    private var currentAudioDurationMs: Int = 0

    private let appAttestService: AppAttestService
    private let storeManager: StoreKitManager
    private let usageTracker: UsageTracker

    // Callbacks - using abstracted types
    var onConnected: (() -> Void)?
    var onDisconnected: ((Error?) -> Void)?
    var onEvent: ((VoiceEvent) -> Void)?
    var onError: ((Error) -> Void)?

    init(sessionState: SessionState, appAttestService: AppAttestService, storeManager: StoreKitManager, usageTracker: UsageTracker, voice: Voice = .coral, sampleRate: Int = 24000) {
        self.sessionState = sessionState
        self.appAttestService = appAttestService
        self.storeManager = storeManager
        self.usageTracker = usageTracker
        self.voice = voice
        self.sampleRate = sampleRate
        self.urlSession = URLSession(configuration: .default)
    }

    // MARK: - Translation Helpers

    /// Translate VoiceToolDefinition to OpenAI format
    private func translateToolDefinition(_ tool: VoiceToolDefinition) -> OpenAIRealtimeEvent.ToolDefinition {
        let params = tool.parameters

        // Convert existing parameters to JSONSchema
        let schema: JSONSchema
        do {
            let data = try JSONSerialization.data(withJSONObject: params)
            schema = try JSONDecoder().decode(JSONSchema.self, from: data)
        } catch {
            // Fallback with dummy parameter
            schema = .object(
                properties: [
                    "_unused": .string(description: "Unused parameter - this function takes no parameters")
                ],
                required: [],
                additionalProperties: nil
            )
        }

        return OpenAIRealtimeEvent.ToolDefinition(
            type: tool.type,
            name: tool.name,
            description: tool.description,
            parameters: schema
        )
    }

    /// Translate OpenAI event to abstracted VoiceEvent
    private func translateEvent(_ message: OpenAIRealtimeEvent) -> VoiceEvent {
        switch message.type {
        case .conversationCreated, .sessionCreated:
            return .sessionCreated

        case .sessionUpdated:
            return .sessionConfigured

        case .inputAudioBufferSpeechStarted:
            return .userSpeechStarted

        case .inputAudioBufferSpeechStopped:
            return .userSpeechStopped

        case .responseOutputAudioDelta:
            if let delta = message.delta, let audioData = Data(base64Encoded: delta) {
                // Track item_id from audio events for truncation
                if let itemId = message.item_id {
                    currentAssistantItemId = itemId
                }

                // Track audio duration for truncation (24kHz, 16-bit PCM, mono)
                let durationMs = (audioData.count / 2) * 1000 / sampleRate  // 2 bytes per sample
                currentAudioDurationMs += durationMs
                return .audioDelta(data: audioData)
            }
            return .other

        case .responseFunctionCallArgumentsDone:
            if let callId = message.call_id,
               let name = message.name,
               let arguments = message.arguments {
                let toolCall = VoiceToolCall(
                    id: callId,
                    name: name,
                    arguments: arguments,
                    itemId: message.item_id
                )
                return .toolCall(toolCall)
            }
            return .other

        case .error:
            if let error = message.error {
                let errorMsg = "\(error.type ?? "Error"): \(error.message ?? "Unknown error") (code: \(error.code ?? "none"))"
                return .error(errorMsg)
            } else if let errorText = message.text {
                return .error(errorText)
            }
            return .error("Unknown error")

        default:
            return .other
        }
    }

    // MARK: - Token Acquisition
    func getEphemeralToken() async throws -> SessionToken {
        AppLogger.network.info("Requesting OpenAI ephemeral token")

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // OpenAI requires session configuration wrapped in "session" key
        let requestBody: [String: Any] = [
            "session": [
                "type": "realtime",
                "model": "gpt-realtime",
                "audio": [
                    "output": [
                        "voice": voice.rawValue
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        try await request.addAppAttestHeaders(appAttestService: appAttestService)

        #if DEBUG
        AppLogger.network.debug("Token request URL: \(self.tokenURL.absoluteString)")
        AppLogger.logSensitive(AppLogger.network, level: .debug, "Request body:\n\(AppLogger.prettyJSON(request.httpBody!))")
        #endif

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.network.error("Invalid HTTP response type")
                throw VoiceServiceError.invalidResponse
            }

            #if DEBUG
            AppLogger.network.debug("Response status: \(httpResponse.statusCode)")
            AppLogger.logSensitive(AppLogger.network, level: .debug, "Response body:\n\(AppLogger.prettyJSON(data))")
            #endif

            guard httpResponse.statusCode == 200 else {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                AppLogger.network.error("Token request failed: HTTP \(httpResponse.statusCode) - \(errorText)")
                throw VoiceServiceError.apiError(statusCode: httpResponse.statusCode, message: errorText)
            }

            // OpenAI returns: {"value": "token", "expires_at": timestamp}
            let sessionToken = try JSONDecoder().decode(SessionToken.self, from: data)

            #if DEBUG
            AppLogger.logSensitive(AppLogger.network, level: .info, "Token acquired: \(AppLogger.redacted(sessionToken.value))")
            AppLogger.network.debug("Token expires in: \(Int(sessionToken.expiresAt - Date().timeIntervalSince1970))s")
            #else
            AppLogger.network.info("Token acquired successfully")
            #endif

            return sessionToken

        } catch let error as VoiceServiceError {
            throw error
        } catch {
            AppLogger.network.error("Token request failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - WebSocket Connection
    func connect() async throws {
        AppLogger.voice.info("Connecting to OpenAI Voice API via WebSocket")

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
    func configureSession(config: VoiceSessionConfig, tools: [VoiceToolDefinition]?) throws {
        AppLogger.voice.info("Configuring OpenAI voice session")

        // Translate abstracted tool definitions to OpenAI format
        let openAITools = tools?.map { translateToolDefinition($0) }

        // OpenAI format: voice and turn_detection are nested in audio.input/output
        let sessionConfig = OpenAIRealtimeEvent(
            type: .sessionUpdate,
            event_id: nil,
            error: nil,
            session: OpenAIRealtimeEvent.SessionConfig(
                id: nil,
                object: nil,
                type: "realtime",
                model: "gpt-realtime",
                instructions: config.instructions + "\n\nToday's Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none)).\nUser's Locale: \(Locale.current.identifier) (Language: \(Locale.current.language.languageCode?.identifier ?? "unknown"), Region: \(Locale.current.region?.identifier ?? "unknown"))",
                voice: nil, // Not used in OpenAI - it's in audio.output.voice
                audio: OpenAIRealtimeEvent.AudioConfig(
                    input: OpenAIRealtimeEvent.AudioConfig.Input(
                        format: OpenAIRealtimeEvent.AudioConfig.Input.Format(
                            type: "audio/pcm",
                            rate: config.sampleRate
                        ),
                        transcription: nil,
                        noise_reduction: nil,
                        turn_detection: .serverVad(
                            OpenAIRealtimeEvent.TurnDetection.ServerVAD(create_response: true, idle_timeout_ms: 5000, interrupt_response: true, prefix_padding_ms: 300, silence_duration_ms: 800, threshold: 0.3)
                        )
                    ),
                    output: OpenAIRealtimeEvent.AudioConfig.Output(
                        format: OpenAIRealtimeEvent.AudioConfig.Output.Format(
                            type: "audio/pcm",
                            rate: config.sampleRate
                        ),
                        voice: voice.rawValue,
                        speed: nil
                    )
                ),
                turn_detection: nil, // Not used in OpenAI - it's in audio.input.turn_detection
                tools: openAITools,
                tool_choice: openAITools != nil ? "auto" : nil,
                output_modalities: ["audio"], // OpenAI only supports ["audio"] or ["text"], not both
                max_output_tokens: nil,
                tracing: nil,
                truncation: nil,
                prompt: nil,
                expires_at: nil,
                include: nil
            ),
            audio: nil,
            delta: nil,
            item: nil,
            item_id: nil,
            previous_item_id: nil,
            response: nil,
            response_id: nil,
            output_index: nil,
            content_index: nil,
            call_id: nil,
            name: nil,
            arguments: nil,
            transcript: nil,
            text: nil,
            audio_end_ms: nil
        )

        try sendMessage(sessionConfig)
    }

    // MARK: - Audio Streaming
    func sendAudioChunk(_ audioData: Data) throws {
        let base64Audio = audioData.base64EncodedString()
        let message = OpenAIRealtimeEvent(
            type: .inputAudioBufferAppend,
            event_id: nil,
            error: nil,
            session: nil,
            audio: base64Audio,
            delta: nil,
            item: nil,
            item_id: nil,
            previous_item_id: nil,
            response: nil,
            response_id: nil,
            output_index: nil,
            content_index: nil,
            call_id: nil,
            name: nil,
            arguments: nil,
            transcript: nil,
            text: nil,
            audio_end_ms: nil
        )
        try sendMessage(message)
    }

    func commitAudioBuffer() throws {
        let message = OpenAIRealtimeEvent(
            type: .inputAudioBufferCommit,
            event_id: nil,
            error: nil,
            session: nil,
            audio: nil,
            delta: nil,
            item: nil,
            item_id: nil,
            previous_item_id: nil,
            response: nil,
            response_id: nil,
            output_index: nil,
            content_index: nil,
            call_id: nil,
            name: nil,
            arguments: nil,
            transcript: nil,
            text: nil,
            audio_end_ms: nil
        )
        try sendMessage(message)
    }

    func createResponse() throws {
        let message = OpenAIRealtimeEvent(
            type: .responseCreate,
            event_id: nil,
            error: nil,
            session: nil,
            audio: nil,
            delta: nil,
            item: nil,
            item_id: nil,
            previous_item_id: nil,
            response: nil,
            response_id: nil,
            output_index: nil,
            content_index: nil,
            call_id: nil,
            name: nil,
            arguments: nil,
            transcript: nil,
            text: nil,
            audio_end_ms: nil
        )
        try sendMessage(message)
    }

    func sendToolOutput(_ output: VoiceToolOutput) throws {
        sessionState.updateResponse(id: output.toolCallId, responseString: output.output, success: output.success)

        let toolOutput = OpenAIRealtimeEvent(
            type: .conversationItemCreate,
            event_id: nil,
            error: nil,
            session: nil,
            audio: nil,
            delta: nil,
            item: OpenAIRealtimeEvent.Item(
                id: nil,
                object: nil,
                type: "function_call_output",
                status: nil,
                role: nil,
                content: nil,
                call_id: output.toolCallId,
                output: output.output,
                name: nil,
                arguments: nil
            ),
            item_id: nil,
            previous_item_id: output.previousItemId,
            response: nil,
            response_id: nil,
            output_index: nil,
            content_index: nil,
            call_id: nil,
            name: nil,
            arguments: nil,
            transcript: nil,
            text: nil,
            audio_end_ms: nil
        )
        try sendMessage(toolOutput)
    }

    func truncateResponse() throws {
        guard let itemId = currentAssistantItemId else {
            AppLogger.voice.warning("No assistant item to truncate")
            return
        }

        let truncateMessage = OpenAIRealtimeEvent(
            type: .conversationItemTruncate,
            event_id: nil,
            error: nil,
            session: nil,
            audio: nil,
            delta: nil,
            item: nil,
            item_id: itemId,
            previous_item_id: nil,
            response: nil,
            response_id: nil,
            output_index: nil,
            content_index: 0, // Always 0 per OpenAI docs
            call_id: nil,
            name: nil,
            arguments: nil,
            transcript: nil,
            text: nil,
            audio_end_ms: currentAudioDurationMs
        )

        AppLogger.voice.info("Truncating response at \(self.currentAudioDurationMs)ms for item: \(itemId)")
        try sendMessage(truncateMessage)

        currentAssistantItemId = nil
        currentAudioDurationMs = 0
    }

    // MARK: - Message Handling
    func sendMessage(_ message: OpenAIRealtimeEvent) throws {
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            throw VoiceServiceError.notConnected
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
        guard let webSocketTask = webSocketTask, webSocketTask.state == .running else {
            AppLogger.voice.warning("Attempted to receive on disconnected socket")
            return
        }

        webSocketTask.receive { [weak self] result in
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
        guard let message = try? JSONDecoder().decode(OpenAIRealtimeEvent.self, from: Data(text.utf8)) else {
            #if DEBUG
            AppLogger.voice.warning("Received unanticipated message format")
            AppLogger.logSensitive(AppLogger.voice, level: .debug, "Message content: \(text)")
            #endif
            return
        }

        // Emit abstracted event
        onEvent?(translateEvent(message))

        #if DEBUG
        AppLogger.voice.debug("Received message: \(message.type.rawValue)")
        #endif

        switch message.type {
        case .conversationCreated, .sessionCreated:
            AppLogger.voice.info("Conversation/session created")

        case .sessionUpdated:
            AppLogger.voice.info("Session configured successfully")
            onConnected?()

        case .responseCreated:
            currentAudioDurationMs = 0
            currentAssistantItemId = nil
            AppLogger.voice.debug("New response created, reset audio tracking")

        case .responseFunctionCallArgumentsDone:
            if let callId = message.call_id,
               let name = message.name,
               let arguments = message.arguments {
                AppLogger.tools.info("Tool call received: \(name)")
                let params: [String: Any]? = {
                    guard let data = arguments.data(using: .utf8) else { return nil }
                    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                }()
                sessionState.addCall(id: callId, toolName: name, parameters: params ?? ["raw": arguments], itemId: message.item_id)
            }
        case .responseDone:
            if let messageData = try? JSONEncoder().encode(message),
               let jsonString = String(data: messageData, encoding: .utf8) {
                AppLogger.voice.info("Received response.done event")
                AppLogger.logSensitive(AppLogger.voice, level: .debug, "response.done JSON:\n\(AppLogger.prettyJSON(jsonString))")
            }

            // Track OpenAI usage with server registration
            if let usage = message.response?.usage {
                let audioInputTokens = usage.input_token_details?.audio_tokens ?? 0
                let audioOutputTokens = usage.output_token_details?.audio_tokens ?? 0
                let textInputTokens = usage.input_token_details?.text_tokens ?? 0
                let textOutputTokens = usage.output_token_details?.text_tokens ?? 0
                let cachedTextInputTokens = usage.input_token_details?.cached_tokens ?? 0

                Task { @MainActor in
                    do {
                        let userId = try await storeManager.getOrCreateAppAccountToken().uuidString
                        let result = await usageTracker.trackAndRegisterOpenAIUsage(
                            audioInputTokens: audioInputTokens,
                            audioOutputTokens: audioOutputTokens,
                            textInputTokens: textInputTokens,
                            textOutputTokens: textOutputTokens,
                            cachedTextInputTokens: cachedTextInputTokens,
                            userId: userId
                        )

                        switch result {
                        case .success(let balance):
                            if balance.remaining <= 0 {
                                AppLogger.voice.error("OpenAI usage reached ")
                                self.onError?(VoiceServiceError.insufficientCredits(balance: balance.remaining.rounded(toPlaces: 2)))
                            }
                        case .failure(let error):
                            AppLogger.voice.error("OpenAI usage tracking failed: \(error)")
                            self.onError?(VoiceServiceError.usageTrackingFailed(error))
                        }
                    } catch {
                        AppLogger.voice.error("Failed to track OpenAI usage: \(error)")
                        self.onError?(VoiceServiceError.usageTrackingFailed(error))
                    }
                }
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
