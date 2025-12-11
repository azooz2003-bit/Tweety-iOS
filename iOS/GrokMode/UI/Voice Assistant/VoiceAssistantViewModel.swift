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

struct PendingToolCall: Identifiable {
    let id: String
    let functionName: String
    let arguments: String
    let previewTitle: String
    let previewContent: String
}

enum ConversationItemType {
    case userSpeech(transcript: String)
    case assistantSpeech(text: String)
    case tweet(XTweet, author: XUser?, mediaUrls: [String])
    case toolCall(name: String, status: ToolCallStatus)
    case systemMessage(String)
}

enum ToolCallStatus {
    case pending
    case approved
    case rejected
    case executed(success: Bool)
}

struct ConversationItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: ConversationItemType
}

@Observable
@MainActor
class VoiceAssistantViewModel: NSObject, AudioStreamerDelegate {
    // Permissions
    var micPermissionGranted = false
    var micPermissionStatus = "Checking..."

    // Connection
    var isConnected = false
    var isConnecting = false
    var connectionError: String?

    // Audio
    var isListening = false
    var isGeraldSpeaking = false
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

        audioStreamer = try? AudioStreamer.make()
        audioStreamer?.delegate = self

        checkPermissions()
    }

    // MARK: - Permissions

    func checkPermissions() {
        let permissionStatus = AVAudioApplication.shared.recordPermission

        switch permissionStatus {
        case .granted:
            micPermissionGranted = true
            micPermissionStatus = "Granted"
        case .denied:
            micPermissionGranted = false
            micPermissionStatus = "Denied"
        case .undetermined:
            micPermissionGranted = false
            micPermissionStatus = "Not Requested"
        @unknown default:
            micPermissionGranted = false
            micPermissionStatus = "Unknown"
        }
    }

    func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.micPermissionGranted = granted
                self?.micPermissionStatus = granted ? "Granted" : "Denied"
            }
        }
    }

    // MARK: - Connection Management

    var canConnect: Bool {
        return micPermissionGranted && !isConnected && !isConnecting
    }

    func connect() {
        guard canConnect else { return }

        isConnecting = true
        connectionError = nil

        addSystemMessage("Connecting to XAI Voice...")

        // Initialize XAI service
        xaiService = XAIVoiceService(apiKey: Config.xAiApiKey, sessionState: sessionState)

        // Set up callbacks (already on main actor)
        xaiService?.onConnected = { [weak self] in
            Task { @MainActor in
                self?.isConnected = true
                self?.isConnecting = false
                self?.addSystemMessage("Connected to XAI Voice")
            }
        }

        xaiService?.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleXAIMessage(message)
            }
        }

        xaiService?.onError = { [weak self] error in
            Task { @MainActor in
                print("🔴 XAI Error: \(error.localizedDescription)")

                // Stop audio streaming immediately to prevent cascade of errors
                self?.stopListening()

                self?.isConnecting = false
                self?.isConnected = false
                self?.connectionError = error.localizedDescription
                self?.addSystemMessage("Error: \(error.localizedDescription)")
            }
        }

        // Start connection
        Task {
            do {
                // Execute tweet pre-fetch and XAI connection in parallel
                print("🔍 ===== TWEET API REQUEST =====")
                print("🔍 Query: \(scenarioTopic)")

                async let searchResult = {
                    let toolOrchestrator = XToolOrchestrator(authService: authViewModel.authService)
                    return await toolOrchestrator.executeTool(
                        .searchRecentTweets,
                        parameters: [
                            "query": scenarioTopic,
                            "max_results": 10,
                            "expansions": "attachments.media_keys,author_id",
                            "media.fields": "url,preview_image_url,type,width,height",
                            "tweet.fields": "public_metrics,created_at",
                            "user.fields": "name,username,profile_image_url"
                        ]
                    )
                }()

                // Connect to XAI in parallel with tweet fetch
                async let xaiConnection: () = xaiService!.connect()

                // Wait for both to complete
                let (tweets, _) = try await (searchResult, xaiConnection)

                print("🔍 ===== TWEET API RESPONSE =====")
                print("🔍 Success: \(tweets.success)")
                if let response = tweets.response {
                    print("🔍 Response length: \(response.count) characters")
                }

                var contextString = ""
                if tweets.success, let response = tweets.response {
                    contextString = response
                } else {
                    contextString = "No recent tweets found."
                }

                // Configure session with tools (must be after connection)
                let tools = XToolIntegration.getToolDefinitions()
                try xaiService!.configureSession(tools: tools)

                // Send context as a user message
                let contextMessage = VoiceMessage(
                    type: "conversation.item.create",
                    audio: nil,
                    text: nil,
                    delta: nil,
                    session: nil,
                    item: VoiceMessage.ConversationItem(
                        id: nil,
                        object: nil,
                        type: "message",
                        status: nil,
                        role: "user",
                        content: [VoiceMessage.ContentItem(
                            type: "input_text",
                            text: "SYSTEM CONTEXT: You have just searched for '\(self.scenarioTopic)' and found these recent tweets: \(contextString). Use this context for the conversation.",
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
                try xaiService!.sendMessage(contextMessage)

                addSystemMessage("Session configured and ready")

            } catch {
                self.isConnecting = false
                self.isConnected = false
                self.connectionError = error.localizedDescription
                self.addSystemMessage("Connection failed: \(error.localizedDescription)")
            }
        }
    }

    func disconnect() {
        xaiService?.disconnect()
        audioStreamer?.stopStreaming()
        isGeraldSpeaking = false
        isListening = false
        isConnected = false
        isConnecting = false

        addSystemMessage("Disconnected")
    }

    func reconnect() {
        print("🔄 Reconnecting...")

        // Stop any existing streams
        isListening = false
        audioStreamer?.stopStreaming()
        isGeraldSpeaking = false

        // Disconnect existing service
        xaiService?.disconnect()

        // Clear error state
        connectionError = nil

        // Reconnect
        connect()
    }

    // MARK: - Audio Streaming

    func startListening() throws {
        guard isConnected else { return }

        isListening = true
        try audioStreamer?.startStreaming()
    }

    func stopListening() {
        audioStreamer?.stopStreaming()
        isListening = false
        currentAudioLevel = 0.0  // Reset waveform to baseline
    }

    // MARK: - AudioStreamerDelegate

    nonisolated func audioStreamerDidReceiveAudioData(_ data: Data) {
        Task { @MainActor in
            // Only send audio if we're connected
            guard isConnected else {
                stopListening()
                return
            }

            do {
                try xaiService?.sendAudioChunk(data)
            } catch {
                print("❌ Failed to send audio chunk: \(error)")
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

    private func handleXAIMessage(_ message: VoiceMessage) {
        switch message.type {
        case "conversation.created":
            // Session initialized
            break

        case "session.updated":
            // Session configured
            break

        case "response.created":
            // Assistant started responding
            break

        case "response.function_call_arguments.done":
            if let callId = message.call_id,
               let name = message.name,
               let args = message.arguments {
                let toolCall = VoiceMessage.ToolCall(
                    id: callId,
                    type: "function",
                    function: VoiceMessage.FunctionCall(name: name, arguments: args)
                )
                handleToolCall(toolCall)
            }

        case "response.output_item.added":
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

        case "response.done":
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

        case "input_audio_buffer.speech_started":
            // User started speaking
            audioStreamer?.stopPlayback()
            isGeraldSpeaking = false

            // Handle truncation
            if let itemId = currentItemId, let startTime = currentAudioStartTime {
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                try? xaiService?.sendTruncationEvent(itemId: itemId, audioEndMs: elapsed)
                currentItemId = nil
                currentAudioStartTime = nil
            }

        case "input_audio_buffer.speech_stopped":
            // User stopped speaking
            break

        case "input_audio_buffer.committed":
            // Audio sent for processing
            break

        case "response.output_audio.delta":
            if let delta = message.delta, let audioData = Data(base64Encoded: delta) {
                do {
                    try audioStreamer?.playAudio(audioData) // TODO: handle error
                } catch {
                    os_log("Failed to play audio: \(error)")
                }
                isGeraldSpeaking = true

                // Track start time of first audio chunk
                if currentAudioStartTime == nil {
                    currentAudioStartTime = Date()
                }
            }

        case "error":
            if let errorText = message.text {
                addSystemMessage("Error: \(errorText)")
            }

        default:
            break
        }
    }

    // MARK: - Tool Handling

    private func isSafeTool(_ functionName: String) -> Bool {
        return functionName.hasPrefix("get") ||
               functionName.hasPrefix("search") ||
               functionName.hasPrefix("list")
    }

    private func handleToolCall(_ toolCall: VoiceMessage.ToolCall) {
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

        let voiceToolCall = VoiceMessage.ToolCall(
            id: toolCall.id,
            type: "function",
            function: VoiceMessage.FunctionCall(
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

    private func executeTool(_ toolCall: VoiceMessage.ToolCall) {
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
            print("⚠️ Skipping duplicate system message: \(message)")
            return
        }

        addConversationItem(.systemMessage(message))
    }

    private func parseTweetsFromResponse(_ response: String, toolName: String) {
        // Try to parse tweets from JSON response
        guard let data = response.data(using: .utf8) else { return }

        // DEBUG: Log raw response
        print("🔍 RAW TWEET RESPONSE (first 500 chars):")
        print(response.prefix(500))

        do {
            if toolName == "search_recent_tweets" || toolName == "search_all_tweets" || toolName == "get_tweets" || toolName == "get_tweet" || toolName == "get_user_liked_tweets" {
                struct TweetResponse: Codable {
                    let data: [XTweet]?
                    let includes: Includes?

                    struct Includes: Codable {
                        let users: [XUser]?
                        let media: [XMedia]?
                    }
                }

                let tweetResponse = try JSONDecoder().decode(TweetResponse.self, from: data)

                print("📦 ===== PARSED TWEET DATA =====")
                print("📦 Total tweets: \(tweetResponse.data?.count ?? 0)")
                print("📦 Total users in includes: \(tweetResponse.includes?.users?.count ?? 0)")
                print("📦 Total media in includes: \(tweetResponse.includes?.media?.count ?? 0)")

                if let tweets = tweetResponse.data {
                    for (index, tweet) in tweets.enumerated() {
                        print("\n📊 ===== TWEET #\(index + 1) =====")
                        print("📊 ID: \(tweet.id)")
                        print("📊 Text: \(tweet.text.prefix(50))...")
                        print("📊 Author ID: \(tweet.author_id ?? "nil")")
                        print("📊 Created At: \(tweet.created_at ?? "nil")")

                        let author = tweetResponse.includes?.users?.first { $0.id == tweet.author_id }
                        print("📊 Author Found: \(author != nil)")
                        if let author = author {
                            print("📊   - Name: \(author.name)")
                            print("📊   - Username: @\(author.username)")
                        }

                        // Log attachments
                        if let attachments = tweet.attachments {
                            print("📊 Attachments: \(attachments.media_keys?.count ?? 0) media items")
                        } else {
                            print("📊 Attachments: none")
                        }

                        // Log metrics in detail
                        print("📊 Public Metrics Object: \(tweet.public_metrics != nil ? "EXISTS" : "NIL")")
                        if let metrics = tweet.public_metrics {
                            print("📊   ✓ Like Count: \(metrics.like_count ?? 0)")
                            print("📊   ✓ Retweet Count: \(metrics.retweet_count ?? 0)")
                            print("📊   ✓ Reply Count: \(metrics.reply_count ?? 0)")
                            print("📊   ✓ Quote Count: \(metrics.quote_count ?? 0)")
                            print("📊   ✓ Impression Count (Views): \(metrics.impression_count ?? 0)")
                            print("📊   ✓ Bookmark Count: \(metrics.bookmark_count ?? 0)")
                        } else {
                            print("📊   ✗ NO METRICS IN RESPONSE")
                        }

                        // Extract media URLs for this tweet
                        var mediaUrls: [String] = []
                        if let mediaKeys = tweet.attachments?.media_keys,
                           let allMedia = tweetResponse.includes?.media {
                            print("📊 Processing \(mediaKeys.count) media keys...")
                            for mediaKey in mediaKeys {
                                if let media = allMedia.first(where: { $0.media_key == mediaKey }),
                                   let displayUrl = media.displayUrl {
                                    mediaUrls.append(displayUrl)
                                    print("📊   ✓ Media URL: \(displayUrl.prefix(50))...")
                                }
                            }
                        }
                        print("📊 Total Media URLs: \(mediaUrls.count)")

                        addConversationItem(.tweet(tweet, author: author, mediaUrls: mediaUrls))
                        print("📊 ✓ Tweet #\(index + 1) added to conversation")
                    }
                }
                print("\n📦 ===== PARSING COMPLETE =====\n")
            }
        } catch {
            print("Failed to parse tweets: \(error)")
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
