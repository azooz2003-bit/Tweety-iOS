//
//  VoiceAssistantViewModel.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI
import AVFoundation
import Combine
import OSLog

@Observable
class VoiceAssistantViewModel: NSObject, AudioStreamerDelegate {
    // State
    var micPermission: MicPermissionState = .checking
    var voiceSessionState: VoiceSessionState = .disconnected
    var isSessionActivated: Bool = false
    var currentAudioLevel: Float = 0.0

    // Conversation
    var conversationItems: [ConversationItem] = []

    // Tool Confirmation
    var pendingToolCall: PendingToolCall?

    // MARK: - Private Properties

    private var xaiService: XAIVoiceService?
    private var audioStreamer: AudioStreamer?
    private var sessionState = SessionState()
    private let authViewModel: AuthViewModel

    // Truncation tracking
    private var currentItemId: String?
    private var currentAudioStartTime: Date?

    // Configuration
    private let scenarioTopic = "Grok"
    private let serverSampleRate: ConversationEvent.AudioFormatType.SampleRate = .twentyFourKHz

    // X Auth - computed properties from AuthViewModel
    var isXAuthenticated: Bool {
        authViewModel.isAuthenticated
    }

    var xUserHandle: String? {
        authViewModel.currentUserHandle
    }

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        super.init()

        audioStreamer = try? AudioStreamer.make(xaiSampleRate: Double(serverSampleRate.rawValue))
        audioStreamer?.delegate = self

        checkPermissions()
    }

    // MARK: - Permissions

    func checkPermissions() {
        let permissionStatus = AVAudioApplication.shared.recordPermission

        switch permissionStatus {
        case .granted:
            micPermission = .granted
        case .denied:
            micPermission = .denied
        case .undetermined:
            micPermission = .checking
        @unknown default:
            micPermission = .denied
        }
    }

    func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.micPermission = granted ? .granted : .denied
            }
        }
    }

    // MARK: - Connection Management

    var canConnect: Bool {
        return micPermission.isGranted && !voiceSessionState.isConnected && !voiceSessionState.isConnecting
    }

    func connect() {
        guard canConnect else { return }

        voiceSessionState = .connecting

        addSystemMessage("Connecting to XAI Voice...")

        // Initialize XAI service
        let xaiService = XAIVoiceService(sessionState: sessionState, sampleRate: serverSampleRate)
        self.xaiService = xaiService

        // Set up callbacks (already on main actor)
        xaiService.onConnected = { [weak self] in
            Task { @MainActor in
                self?.voiceSessionState = .connected
                self?.addSystemMessage("Connected to XAI Voice")
            }
        }

        xaiService.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleXAIMessage(message)
            }
        }

        xaiService.onError = { [weak self] error in
            Task { @MainActor in
                AppLogger.voice.error("XAI Error: \(error.localizedDescription)")

                // Stop audio streaming immediately to prevent cascade of errors
                self?.stopListening()

                self?.voiceSessionState = .error(error.localizedDescription)
                self?.addSystemMessage("Error: \(error.localizedDescription)")
            }
        }

        // Start connection
        Task {
            do {
                // Execute user profile fetch and XAI connection in parallel
                #if DEBUG
                AppLogger.network.debug("===== USER PROFILE REQUEST =====")
                #endif

                let xToolOrchestrator = XToolOrchestrator(authService: self.authViewModel.authService)

                // Connect to XAI in parallel with user profile fetch
                async let connect: () = xaiService.connect()
                async let userProfileResult = xToolOrchestrator.executeTool(.getAuthenticatedUser, parameters: [:])

                // Await both operations
                let (profileResult, _) = (await userProfileResult, try await connect)

                // Configure session with tools (must be after connection)
                let tools = XToolIntegration.getToolDefinitions()
                try xaiService.configureSession(tools: tools)

                // Send context as a user message
                let contextString = profileResult.success ? (profileResult.response ?? "No profile data") : "Failed to fetch profile"
                let contextMessage = ConversationEvent(
                    type: .conversationItemCreate,
                    audio: nil,
                    text: nil,
                    delta: nil,
                    session: nil,
                    item: ConversationEvent.ConversationItem(
                        id: nil,
                        object: nil,
                        type: "message",
                        status: nil,
                        role: "user",
                        content: [ConversationEvent.ContentItem(
                            type: "input_text",
                            text: "SYSTEM CONTEXT: Here is your user profile information: \(contextString). Use this context for the conversation.",
                            transcript: nil
                        )]
                    ),
                    tools: nil,
                    tool_call_id: nil,
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
                try xaiService.sendMessage(contextMessage)

                addSystemMessage("Session configured and ready")

            } catch {
                self.voiceSessionState = .error(error.localizedDescription)
                self.addSystemMessage("Connection failed: \(error.localizedDescription)")
            }
        }
    }

    func disconnect() {
        xaiService?.disconnect()
        audioStreamer?.stopStreaming()
        voiceSessionState = .disconnected
        isSessionActivated = false

        addSystemMessage("Disconnected")
    }

    func reconnect() {
        AppLogger.voice.info("Reconnecting...")

        // Stop any existing streams
        audioStreamer?.stopStreaming()

        // Disconnect existing service
        xaiService?.disconnect()

        // Reconnect (this will set state to .connecting)
        connect()
    }

    // MARK: - Audio Streaming

    func startListening() {
        guard voiceSessionState.isConnected else { return }

        // Set state immediately for instant UI feedback
        isSessionActivated = true
        voiceSessionState = .listening

        // Start audio asynchronously on dedicated audio queue to avoid blocking main thread
        audioStreamer?.startStreamingAsync { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    AppLogger.audio.error("Failed to start audio streaming: \(error.localizedDescription)")
                    self?.voiceSessionState = .error("Microphone access failed")
                }
            }
        }
    }

    func stopListening() {
        isSessionActivated = false
        audioStreamer?.stopStreaming()
        // Return to connected state if still connected, otherwise keep current state
        if voiceSessionState.isConnected {
            voiceSessionState = .connected
        }
        currentAudioLevel = 0.0  // Reset waveform to baseline
    }

    // MARK: - AudioStreamerDelegate

    nonisolated func audioStreamerDidReceiveAudioData(_ data: Data) {
        Task { @MainActor in
            // Only send audio if we're connected
            guard voiceSessionState.isConnected else {
                stopListening()
                return
            }

            do {
                try xaiService?.sendAudioChunk(data)
            } catch {
                AppLogger.audio.error("Failed to send audio chunk: \(error.localizedDescription)")
                // Stop streaming to prevent error cascade
                stopListening()
            }
        }
    }

    nonisolated func audioStreamerDidDetectSpeechStart() {
        Task { @MainActor in
            // Speech detection handled automatically
        }
    }

    nonisolated func audioStreamerDidDetectSpeechEnd() {
        Task { @MainActor in
            try? self.xaiService?.commitAudioBuffer()
        }
    }

    nonisolated func audioStreamerDidUpdateAudioLevel(_ level: Float) {
        Task { @MainActor in
            self.currentAudioLevel = level
        }
    }

    // MARK: - Message Handling

    private func handleXAIMessage(_ message: ConversationEvent) {
        switch message.type {
        case .conversationCreated:
            // Session initialized
            break

        case .sessionUpdated:
            // Session configured
            break

        case .responseCreated:
            // Assistant started responding
            break

        case .responseFunctionCallArgumentsDone:
            if let callId = message.call_id,
               let name = message.name,
               let args = message.arguments {
                let toolCall = ConversationEvent.ToolCall(
                    id: callId,
                    type: "function",
                    function: ConversationEvent.FunctionCall(name: name, arguments: args)
                )
                handleToolCall(toolCall)
            }

        case .responseOutputItemAdded:
            if let item = message.item, let toolCalls = item.tool_calls {
                for toolCall in toolCalls {
                    handleToolCall(toolCall)
                }
            }

            // Track item ID for truncation
            if let item = message.item {
                currentItemId = item.id
                currentAudioStartTime = nil
            }

        case .responseDone:
            // Check for tool calls in completed response
            if let output = message.response?.output {
                for item in output {
                    if let toolCalls = item.tool_calls {
                        for toolCall in toolCalls {
                            handleToolCall(toolCall)
                        }
                    }
                }
            }

        case .inputAudioBufferSpeechStarted:
            // User started speaking
            audioStreamer?.stopPlayback()
            voiceSessionState = .listening

            // Handle truncation
            if let itemId = currentItemId, let startTime = currentAudioStartTime {
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                try? xaiService?.sendTruncationEvent(itemId: itemId, audioEndMs: elapsed)
                currentItemId = nil
                currentAudioStartTime = nil
            }

        case .inputAudioBufferSpeechStopped:
            // User stopped speaking
            break

        case .inputAudioBufferCommitted:
            // Audio sent for processing
            break

        case .responseOutputAudioDelta:
            if let delta = message.delta, let audioData = Data(base64Encoded: delta) {
                do {
                    try audioStreamer?.playAudio(audioData) // TODO: handle error
                } catch {
                    os_log("Failed to play audio: \(error)")
                }
                voiceSessionState = .grokSpeaking(itemId: currentItemId)

                // Track start time of first audio chunk
                if currentAudioStartTime == nil {
                    currentAudioStartTime = Date()
                }
            }

        case .error:
            if let errorText = message.text {
                addSystemMessage("Error: \(errorText)")
            }

        default:
            break
        }
    }

    // MARK: - Tool Handling

    private func isSafeTool(_ functionName: String) -> Bool {
        guard let _ = XTool(rawValue: functionName) else {
            return true
        }

        return functionName.hasPrefix("get") ||
               functionName.hasPrefix("search") ||
               functionName.hasPrefix("list")
    }

    private func handleToolCall(_ toolCall: ConversationEvent.ToolCall) {
        let functionName = toolCall.function.name

        if isSafeTool(functionName) {
            executeTool(toolCall)
        } else {
            pendingToolCall = PendingToolCall(
                id: toolCall.id,
                functionName: functionName,
                arguments: toolCall.function.arguments,
                previewTitle: "Allow \(functionName)?",
                previewContent: toolCall.function.arguments
            )

            addConversationItem(.toolCall(name: functionName, status: .pending))
        }
    }

    func approveToolCall() {
        guard let toolCall = pendingToolCall else { return }
        pendingToolCall = nil

        let voiceToolCall = ConversationEvent.ToolCall(
            id: toolCall.id,
            type: "function",
            function: ConversationEvent.FunctionCall(
                name: toolCall.functionName,
                arguments: toolCall.arguments
            )
        )
        executeTool(voiceToolCall)
    }

    func rejectToolCall() {
        guard let toolCall = pendingToolCall else { return }

        try? xaiService?.sendToolOutput(
            toolCallId: toolCall.id,
            output: "User denied this action.",
            success: false
        )

        addConversationItem(.toolCall(name: toolCall.functionName, status: .rejected))
        pendingToolCall = nil
    }

    private func executeTool(_ toolCall: ConversationEvent.ToolCall) {
        Task {
            guard let data = toolCall.function.arguments.data(using: .utf8),
                  let parameters = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }

            let outputString: String
            let isSuccess: Bool

            if let tool = XTool(rawValue: toolCall.function.name) {
                // Handle X API tools through orchestrator
                let orchestrator = XToolOrchestrator(authService: authViewModel.authService)
                let result = await orchestrator.executeTool(tool, parameters: parameters, id: toolCall.id)

                if result.success, let response = result.response {
                    outputString = response
                    isSuccess = true

                    // Parse and display tweets if applicable
                    parseTweetsFromResponse(response, toolName: tool.rawValue)
                } else {
                    outputString = result.error?.message ?? "Unknown error"
                    isSuccess = false
                }

                // Send result back to XAI
                try? xaiService?.sendToolOutput(
                    toolCallId: toolCall.id,
                    output: outputString,
                    success: isSuccess
                )

                // Trigger response creation
                try? xaiService?.createResponse()

                addConversationItem(.toolCall(name: toolCall.function.name, status: .executed(success: isSuccess)))
                pendingToolCall = nil
            }
        }
    }

    // MARK: - Conversation Management

    private func addConversationItem(_ type: ConversationItemType) {
        let item = ConversationItem(timestamp: Date(), type: type)
        conversationItems.append(item)
    }

    private func addSystemMessage(_ message: String) {
        // Prevent consecutive duplicate system messages (especially errors)
        if let lastItem = conversationItems.last,
           case .systemMessage(let lastMessage) = lastItem.type,
           lastMessage == message {
            #if DEBUG
            AppLogger.voice.debug("Skipping duplicate system message: \(message)")
            #endif
            return
        }

        addConversationItem(.systemMessage(message))
    }

    private func parseTweetsFromResponse(_ response: String, toolName: String) {
        // Try to parse tweets from JSON response
        guard let data = response.data(using: .utf8) else { return }

        #if DEBUG
        // DEBUG: Log raw response
        AppLogger.network.debug("RAW TWEET RESPONSE (first 500 chars):")
        AppLogger.logSensitive(AppLogger.network, level: .debug, String(response.prefix(500)))
        #endif

        do {
            if let xTool = XTool(rawValue: toolName), xTool == .searchRecentTweets || xTool == .searchAllTweets || xTool == .getTweets || xTool == .getTweet || xTool == .getUserLikedTweets {
                struct TweetResponse: Codable {
                    let data: [XTweet]?
                    let includes: Includes?

                    struct Includes: Codable {
                        let users: [XUser]?
                        let media: [XMedia]?
                    }
                }

                let tweetResponse = try JSONDecoder().decode(TweetResponse.self, from: data)

                #if DEBUG
                AppLogger.network.debug("===== PARSED TWEET DATA =====")
                AppLogger.network.debug("Total tweets: \(tweetResponse.data?.count ?? 0)")
                AppLogger.network.debug("Total users in includes: \(tweetResponse.includes?.users?.count ?? 0)")
                AppLogger.network.debug("Total media in includes: \(tweetResponse.includes?.media?.count ?? 0)")
                #endif

                if let tweets = tweetResponse.data {
                    for (index, tweet) in tweets.enumerated() {
                        #if DEBUG
                        AppLogger.network.debug("===== TWEET #\(index + 1) =====")
                        AppLogger.network.debug("ID: \(tweet.id)")
                        AppLogger.network.debug("Text: \(String(tweet.text.prefix(50)))...")
                        AppLogger.network.debug("Author ID: \(tweet.author_id ?? "nil")")
                        AppLogger.network.debug("Created At: \(tweet.created_at ?? "nil")")
                        #endif

                        let author = tweetResponse.includes?.users?.first { $0.id == tweet.author_id }
                        #if DEBUG
                        AppLogger.network.debug("Author Found: \(author != nil)")
                        if let author = author {
                            AppLogger.network.debug("  - Name: \(author.name)")
                            AppLogger.network.debug("  - Username: @\(author.username)")
                        }

                        // Log attachments
                        if let attachments = tweet.attachments {
                            AppLogger.network.debug("Attachments: \(attachments.media_keys?.count ?? 0) media items")
                        } else {
                            AppLogger.network.debug("Attachments: none")
                        }

                        // Log metrics in detail
                        AppLogger.network.debug("Public Metrics Object: \(tweet.public_metrics != nil ? "EXISTS" : "NIL")")
                        if let metrics = tweet.public_metrics {
                            AppLogger.network.debug("  ✓ Like Count: \(metrics.like_count ?? 0)")
                            AppLogger.network.debug("  ✓ Retweet Count: \(metrics.retweet_count ?? 0)")
                            AppLogger.network.debug("  ✓ Reply Count: \(metrics.reply_count ?? 0)")
                            AppLogger.network.debug("  ✓ Quote Count: \(metrics.quote_count ?? 0)")
                            AppLogger.network.debug("  ✓ Impression Count (Views): \(metrics.impression_count ?? 0)")
                            AppLogger.network.debug("  ✓ Bookmark Count: \(metrics.bookmark_count ?? 0)")
                        } else {
                            AppLogger.network.debug("  ✗ NO METRICS IN RESPONSE")
                        }
                        #endif

                        // Extract media URLs for this tweet
                        var mediaUrls: [String] = []
                        if let mediaKeys = tweet.attachments?.media_keys,
                           let allMedia = tweetResponse.includes?.media {
                            #if DEBUG
                            AppLogger.network.debug("Processing \(mediaKeys.count) media keys...")
                            #endif
                            for mediaKey in mediaKeys {
                                if let media = allMedia.first(where: { $0.media_key == mediaKey }),
                                   let displayUrl = media.displayUrl {
                                    mediaUrls.append(displayUrl)
                                    #if DEBUG
                                    AppLogger.network.debug("  ✓ Media URL: \(String(displayUrl.prefix(50)))...")
                                    #endif
                                }
                            }
                        }
                        #if DEBUG
                        AppLogger.network.debug("Total Media URLs: \(mediaUrls.count)")
                        #endif

                        addConversationItem(.tweet(tweet, author: author, mediaUrls: mediaUrls))
                        #if DEBUG
                        AppLogger.network.debug("✓ Tweet #\(index + 1) added to conversation")
                        #endif
                    }
                }
                #if DEBUG
                AppLogger.network.debug("===== PARSING COMPLETE =====")
                #endif
            }
        } catch {
            AppLogger.network.error("Failed to parse tweets: \(error.localizedDescription)")
        }
    }

    // MARK: - X Auth

    func loginWithX() async throws {
        try await authViewModel.login()
    }

    func logoutX() async {
        await authViewModel.logout()
    }
}
