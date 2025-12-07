//
//  VoiceAssistantViewModel.swift
//  GrokMode
//
//  Created by Claude Code on 12/7/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Conversation Item Models

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

// MARK: - Voice Assistant ViewModel

@Observable
class VoiceAssistantViewModel: NSObject, AudioStreamerDelegate {
    // MARK: - State Properties

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

    // Conversation
    var conversationItems: [ConversationItem] = []

    // Tool Confirmation
    var pendingToolCall: PendingToolCall?

    // X Auth
    var isXAuthenticated = false
    var xUserHandle: String?

    // MARK: - Private Properties

    private var xaiService: XAIVoiceService?
    private var audioStreamer: AudioStreamer!
    private var sessionState = SessionState()
    private var authCancellable: AnyCancellable?

    // Truncation tracking
    private var currentItemId: String?
    private var currentAudioStartTime: Date?

    // Configuration
    private let scenarioTopic = "Grok"

    // MARK: - Initialization

    override init() {
        super.init()

        audioStreamer = AudioStreamer()
        audioStreamer.delegate = self

        setupAuthObservation()
        checkPermissions()
    }

    // MARK: - Setup

    private func setupAuthObservation() {
        isXAuthenticated = XAuthService.shared.isAuthenticated
        xUserHandle = XAuthService.shared.currentUserHandle

        authCancellable = XAuthService.shared.$isAuthenticated
            .receive(on: RunLoop.main)
            .sink { [weak self] isAuthenticated in
                self?.isXAuthenticated = isAuthenticated
                self?.xUserHandle = XAuthService.shared.currentUserHandle
            }
    }

    // MARK: - Permissions

    func checkPermissions() {
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission

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
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
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

        // Set up callbacks
        xaiService?.onConnected = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = true
                self?.isConnecting = false
                self?.addSystemMessage("Connected to XAI Voice")
            }
        }

        xaiService?.onMessageReceived = { [weak self] message in
            DispatchQueue.main.async {
                self?.handleXAIMessage(message)
            }
        }

        xaiService?.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.isConnecting = false
                self?.isConnected = false
                self?.connectionError = error.localizedDescription
                self?.addSystemMessage("Error: \(error.localizedDescription)")
            }
        }

        // Start connection
        Task {
            do {
                // Pre-fetch tweets for context (with media fields and metrics)
                let toolOrchestrator = XToolOrchestrator()

                print("🔍 ===== TWEET API REQUEST =====")
                print("🔍 Query: \(scenarioTopic)")
                print("🔍 Requesting fields:")
                print("🔍   - expansions: attachments.media_keys,author_id")
                print("🔍   - media.fields: url,preview_image_url,type,width,height")
                print("🔍   - tweet.fields: public_metrics,created_at")
                print("🔍   - user.fields: name,username,profile_image_url")

                let searchResult = await toolOrchestrator.executeTool(
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

                print("🔍 ===== TWEET API RESPONSE =====")
                print("🔍 Success: \(searchResult.success)")
                if let response = searchResult.response {
                    print("🔍 Response length: \(response.count) characters")
                }

                var contextString = ""
                if searchResult.success, let response = searchResult.response {
                    contextString = response
                } else {
                    contextString = "No recent tweets found."
                }

                // Connect to XAI
                try await xaiService!.connect()

                // Configure session with tools
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

                await MainActor.run {
                    addSystemMessage("Session configured and ready")
                }

            } catch {
                await MainActor.run {
                    self.isConnecting = false
                    self.isConnected = false
                    self.connectionError = error.localizedDescription
                    self.addSystemMessage("Connection failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func disconnect() {
        xaiService?.disconnect()
        audioStreamer.stopStreaming()
        isGeraldSpeaking = false
        isListening = false
        isConnected = false
        isConnecting = false

        addSystemMessage("Disconnected")
    }

    // MARK: - Audio Streaming

    func startListening() {
        guard isConnected else { return }

        audioStreamer.startStreaming()
        isListening = true
    }

    func stopListening() {
        audioStreamer.stopStreaming()
        isListening = false
    }

    // MARK: - AudioStreamerDelegate

    func audioStreamerDidReceiveAudioData(_ data: Data) {
        do {
            try xaiService?.sendAudioChunk(data)
        } catch {
            print("Failed to send audio chunk: \(error)")
        }
    }

    func audioStreamerDidDetectSpeechStart() {
        DispatchQueue.main.async {
            // Speech detection handled automatically
        }
    }

    func audioStreamerDidDetectSpeechEnd() {
        DispatchQueue.main.async {
            try? self.xaiService?.commitAudioBuffer()
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
            audioStreamer.stopPlayback()
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
                audioStreamer.playAudio(audioData)
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

            // Special handling for Linear ticket creation
            if toolCall.function.name == "create_linear_ticket" {
                guard let title = parameters["title"] as? String else {
                    outputString = "Missing required parameter: title"
                    isSuccess = false
                    try? xaiService?.sendToolOutput(toolCallId: toolCall.id, output: outputString, success: isSuccess)
                    try? xaiService?.createResponse()
                    return
                }

                let description = parameters["description"] as? String

                let linearService = LinearAPIService(apiToken: Config.linearApiKey)

                do {
                    // Get teams first
                    let teams = try await linearService.getTeams()
                    guard let firstTeam = teams.first else {
                        throw NSError(domain: "LinearAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No teams found"])
                    }

                    // Create the issue
                    let issue = try await linearService.createIssue(title: title, description: description, teamId: firstTeam.id)

                    // Format response
                    let issueStruct = LinearIssueStruct(
                        id: issue.id,
                        title: issue.title,
                        number: issue.number,
                        url: issue.url,
                        createdAt: issue.createdAt
                    )

                    let jsonData = try JSONEncoder().encode(issueStruct)
                    outputString = String(data: jsonData, encoding: .utf8) ?? "{}"
                    isSuccess = true
                } catch {
                    outputString = "Failed to create Linear ticket: \(error.localizedDescription)"
                    isSuccess = false
                }

                try? xaiService?.sendToolOutput(toolCallId: toolCall.id, output: outputString, success: isSuccess)
                try? xaiService?.createResponse()

                await MainActor.run {
                    addConversationItem(.toolCall(name: toolCall.function.name, status: .executed(success: isSuccess)))
                    pendingToolCall = nil
                }

            } else if let tool = XTool(rawValue: toolCall.function.name) {
                // Handle X API tools through orchestrator
                let orchestrator = XToolOrchestrator()
                let result = await orchestrator.executeTool(tool, parameters: parameters, id: toolCall.id)

                if result.success, let response = result.response {
                    outputString = response
                    isSuccess = true

                    // Parse and display tweets if applicable
                    await MainActor.run {
                        parseTweetsFromResponse(response, toolName: tool.rawValue)
                    }
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

                await MainActor.run {
                    addConversationItem(.toolCall(name: toolCall.function.name, status: .executed(success: isSuccess)))
                    pendingToolCall = nil
                }
            }
        }
    }

    // MARK: - Conversation Management

    private func addConversationItem(_ type: ConversationItemType) {
        let item = ConversationItem(timestamp: Date(), type: type)
        conversationItems.append(item)
    }

    private func addSystemMessage(_ message: String) {
        addConversationItem(.systemMessage(message))
    }

    private func parseTweetsFromResponse(_ response: String, toolName: String) {
        // Try to parse tweets from JSON response
        guard let data = response.data(using: .utf8) else { return }

        // DEBUG: Log raw response
        print("🔍 RAW TWEET RESPONSE (first 500 chars):")
        print(response.prefix(500))

        do {
            if toolName == "search_recent_tweets" || toolName == "get_tweets" {
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
                        print("📊 ✓ Tweet added to conversation")
                    }
                }
                print("\n📦 ===== PARSING COMPLETE =====\n")
            }
        } catch {
            print("Failed to parse tweets: \(error)")
        }
    }

    // MARK: - X Auth

    func loginWithX() {
        XAuthService.shared.login()
    }

    func logoutX() {
        XAuthService.shared.logout()
    }
}
