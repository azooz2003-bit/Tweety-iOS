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
class VoiceAssistantViewModel: NSObject {
    // MARK: State
    var micPermission: MicPermissionState = .checking
    var voiceSessionState: VoiceSessionState = .disconnected
    var isSessionActivated: Bool = false
    var currentAudioLevel: Float = 0.0
    var selectedServiceType: VoiceServiceType = .openai

    // MARK: Session
    var sessionElapsedTime: TimeInterval = 0
    private var sessionStartTime: Date?
    private var sessionTimer: Timer?
    /// For serializing sessions start and stops
    private var sessionStartStopTask: Task<Void, Never>?

    var formattedSessionDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: sessionElapsedTime) ?? "0:00"
    }

    var conversationItems: [ConversationItem] = []

    private var pendingToolCallQueue: [PendingToolCall] = []
    var currentPendingToolCall: PendingToolCall? {
        pendingToolCallQueue.first
    }

    // MARK: - Private Properties
    private var voiceService: VoiceService?
    private var audioStreamer: AudioStreamer?
    private var sessionState = SessionState()
    private let authViewModel: AuthViewModel

    // MARK: Authentication
    var isXAuthenticated: Bool {
        authViewModel.isAuthenticated
    }
    var xUserHandle: String? {
        authViewModel.currentUserHandle
    }

    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        super.init()
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

    // MARK: - Connection Management

    func connect() async {
        voiceSessionState = .connecting

        let serviceName = selectedServiceType.displayName
        addSystemMessage("Connecting to \(serviceName) Voice...")

        // Clean up existing audio streamer if switching services
        if let existingStreamer = audioStreamer {
            existingStreamer.stopStreaming()
            self.audioStreamer = nil
        }

        // Initialize the selected voice service
        let voiceService = selectedServiceType.createService(sessionState: sessionState)
        self.voiceService = voiceService

        // Initialize audio streamer with service-specific sample rate
        audioStreamer = try? await AudioStreamer.make(xaiSampleRate: Double(voiceService.requiredSampleRate))
        audioStreamer?.delegate = self

        // Set up callbacks (already on main actor)
        voiceService.onConnected = { [weak self] in
            Task { @MainActor in
                self?.voiceSessionState = .connected
                self?.addSystemMessage("Connected to \(serviceName) Voice")
            }
        }

        voiceService.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleVoiceEvent(event)
            }
        }

        voiceService.onError = { [weak self] error in
            Task { @MainActor in
                AppLogger.voice.error("\(serviceName) Error: \(error.localizedDescription)")

                // Stop audio streaming immediately to prevent cascade of errors
                self?.stopSession()

                self?.voiceSessionState = .error(error.localizedDescription)
                #if DEBUG
                self?.addSystemMessage("Error: \(error.localizedDescription)")
                #endif
            }
        }

        voiceService.onDisconnected = { [weak self] error in
            Task { @MainActor in
                guard self?.voiceSessionState != .disconnected else { return }

                if let error = error {
                    AppLogger.voice.error("WebSocket disconnected with error: \(error.localizedDescription)")
                } else {
                    AppLogger.voice.info("WebSocket disconnected normally")
                }

                // Stop the session to clean up resources
                self?.stopSession()

                // Update state
                if let error = error {
                    self?.voiceSessionState = .error("Disconnected: \(error.localizedDescription)")
                }
            }
        }

        // Start connection
        do {
            // Execute user profile fetch and XAI connection in parallel
            #if DEBUG
            AppLogger.network.debug("===== USER PROFILE REQUEST =====")
            #endif

            let xToolOrchestrator = XToolOrchestrator(authService: self.authViewModel.authService)

            // Connect to voice service in parallel with user profile fetch
            async let connect: () = voiceService.connect()
            async let userProfileResult = xToolOrchestrator.executeTool(.getAuthenticatedUser, parameters: [:])

            // Await both operations
            let (_, _) = (await userProfileResult, try await connect)

            // Configure session with tools (must be after connection)
            let tools = XToolIntegration.getToolDefinitions()

            // Get service-specific instructions
            let instructions: String
            if let xaiService = voiceService as? XAIVoiceService {
                instructions = xaiService.instructions
            } else if let openAIService = voiceService as? OpenAIVoiceService {
                instructions = openAIService.instructions
            } else {
                instructions = "You are a helpful voice assistant."
            }

            let sessionConfig = VoiceSessionConfig(
                instructions: instructions,
                tools: tools,
                sampleRate: voiceService.requiredSampleRate
            )
            try voiceService.configureSession(config: sessionConfig, tools: tools)

            // TODO: Send context message in service-specific way if needed
            // For now, context can be integrated into instructions or sent via tool

            addSystemMessage("Session configured and ready")

            // Start audio streaming now that session is configured
            audioStreamer?.startStreamingAsync { [weak self] error in
                if let error = error {
                    Task { @MainActor in
                        AppLogger.audio.error("Failed to start audio streaming: \(error.localizedDescription)")
                        self?.voiceSessionState = .error("Microphone access failed")
                    }
                }
            }

        } catch {
            self.voiceSessionState = .error(error.localizedDescription)
            self.addSystemMessage("Connection failed: \(error.localizedDescription)")
        }
    }

    func disconnect() {
        voiceSessionState = .disconnected
        voiceService?.disconnect()
        audioStreamer?.stopStreaming()

        addSystemMessage("Disconnected")
    }

    // MARK: - Audio Streaming

    func startSession() {
        isSessionActivated = true
        sessionStartStopTask?.cancel()
        sessionStartStopTask = Task { @MainActor in
            // Already connected, start listening
            await connect()

            guard !Task.isCancelled else { return }

            // Start session duration timer
            sessionStartTime = Date()
            sessionElapsedTime = 0
            sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self, let startTime = self.sessionStartTime else { return }
                self.sessionElapsedTime = Date().timeIntervalSince(startTime)
            }

            guard !Task.isCancelled else { return }

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
    }

    func stopSession() {
        isSessionActivated = false
        sessionStartStopTask?.cancel()
        sessionStartStopTask = Task { @MainActor in
            // Stop session duration timer
            sessionTimer?.invalidate()
            sessionTimer = nil
            sessionStartTime = nil
            sessionElapsedTime = 0

            self.disconnect()
            currentAudioLevel = 0.0  // Reset waveform to baseline
        }
    }

    // MARK: - Event Handling

    private func handleVoiceEvent(_ event: VoiceEvent) {
        switch event {
        case .sessionCreated:
            // Session initialized
            break

        case .sessionConfigured:
            // Session configured
            break

        case .userSpeechStarted:
            // User started speaking - truncate ongoing response and stop playback
            try? voiceService?.truncateResponse()
            audioStreamer?.stopPlayback()
            voiceSessionState = .listening

        case .userSpeechStopped:
            // User stopped speaking (server-side VAD)
            voiceSessionState = .connected

        case .assistantSpeaking(let itemId):
            voiceSessionState = .grokSpeaking(itemId: itemId)

        case .audioDelta(let data):
            guard !voiceSessionState.isListening else {
                AppLogger.audio.debug("User speaking, skipping assistant audio")
                return
            }

            do {
                try audioStreamer?.playAudio(data)
            } catch {
                AppLogger.audio.error("Failed to play audio: \(error.localizedDescription)")
            }
            voiceSessionState = .grokSpeaking(itemId: nil)

        case .toolCall(let toolCall):
            handleToolCall(toolCall)

        case .error(let errorMessage):
            AppLogger.voice.error("Error event received: \(errorMessage)")
#if DEBUG
            addSystemMessage("Error: \(errorMessage)")
#endif

        case .other:
            // Other events we don't specifically handle
            break
        }
    }

    // MARK: - Tool Handling

    private func handleToolCall(_ toolCall: VoiceToolCall) {
        let functionName = toolCall.name

        guard let tool = XTool(rawValue: functionName) else {
            // Unknown tool - execute anyway
            executeTool(toolCall)
            return
        }

        switch tool.previewBehavior {
        case .none:
            // Safe tool - execute immediately
            executeTool(toolCall)

        case .requiresConfirmation:
            // Check if this will be the focused tool (first in queue)
            let isFirstInQueue = pendingToolCallQueue.isEmpty

            // Add to queue with placeholder
            let newPendingTool = PendingToolCall(
                id: toolCall.id,
                functionName: functionName,
                arguments: toolCall.arguments,
                previewTitle: "Allow \(functionName)?",
                previewContent: "Loading preview..."
            )
            pendingToolCallQueue.append(newPendingTool)

            addConversationItem(.toolCall(name: functionName, status: .pending))

            // Only notify voice assistant if this is the focused (first) tool
            if isFirstInQueue {
                try? voiceService?.sendToolOutput(VoiceToolOutput(
                    toolCallId: toolCall.id,
                    output: "This action requires user confirmation. Tool call ID: \(toolCall.id). Waiting for the user to confirm or cancel. Ask the user: 'Should I do this? Say yes to confirm or no to cancel.'. Send a confirm_action tool call if the user indicates that they'd like to confirm this action.",
                    success: false,
                    previousItemId: toolCall.itemId
                ))
                try? voiceService?.createResponse()
            }

            // Fetch rich preview asynchronously to update UI
            Task { @MainActor in
                let xToolOrchestrator = XToolOrchestrator(authService: authViewModel.authService)
                let preview = await tool.generatePreview(from: toolCall.arguments, orchestrator: xToolOrchestrator)

                // Update with rich preview if still in queue
                if let index = pendingToolCallQueue.firstIndex(where: { $0.id == toolCall.id }) {
                    pendingToolCallQueue[index] = PendingToolCall(
                        id: toolCall.id,
                        functionName: functionName,
                        arguments: toolCall.arguments,
                        previewTitle: preview?.title ?? "Allow \(functionName)?",
                        previewContent: preview?.content ?? "Review and confirm this action"
                    )
                }
            }
        }
    }

    func approveToolCall() {
        guard let toolCall = pendingToolCallQueue.first else { return }

        // Execute the approved tool
        let voiceToolCall = VoiceToolCall(
            id: toolCall.id,
            name: toolCall.functionName,
            arguments: toolCall.arguments,
            itemId: nil
        )
        executeTool(voiceToolCall)

        // Move to next tool in queue
        moveToNextPendingTool()
    }

    func rejectToolCall() {
        guard let toolCall = pendingToolCallQueue.first else { return }

        try? voiceService?.sendToolOutput(VoiceToolOutput(
            toolCallId: toolCall.id,
            output: "User denied this action.",
            success: false,
            previousItemId: nil
        ))

        addConversationItem(.toolCall(name: toolCall.functionName, status: .rejected))

        // Move to next tool in queue
        moveToNextPendingTool()
    }

    private func moveToNextPendingTool() {
        // Remove the current focused tool
        pendingToolCallQueue.removeFirst()

        // Notify voice assistant about the next focused tool if there is one
        if let nextTool = pendingToolCallQueue.first {
            try? voiceService?.sendToolOutput(VoiceToolOutput(
                toolCallId: nextTool.id,
                output: "This action requires user confirmation. Tool call ID: \(nextTool.id). Waiting for the user to confirm or cancel. Ask the user: 'Should I do this? Say yes to confirm or no to cancel.'",
                success: false,
                previousItemId: nil
            ))
            try? voiceService?.createResponse()
        }
    }

    private func executeTool(_ toolCall: VoiceToolCall) {
        Task {
            // Handle voice confirmation tools specially
            if let tool = XTool(rawValue: toolCall.name), tool == .confirmAction || tool == .cancelAction {

                struct ConfirmationParams: Codable {
                    let tool_call_id: String
                }

                let params = try? JSONDecoder().decode(
                    ConfirmationParams.self,
                    from: toolCall.arguments.data(using: .utf8) ?? Data()
                )
                let originalToolCallId = params?.tool_call_id ?? "unknown"
                let originalItemId = sessionState.toolCalls.first { $0.id == originalToolCallId }?.call.itemId

                switch tool {
                case .confirmAction:
                    try? voiceService?.sendToolOutput(VoiceToolOutput(
                        toolCallId: toolCall.id,
                        output: "CONFIRMATION ACKNOWLEDGED: User has confirmed the action for tool call ID \(originalToolCallId). The action is now being executed. IMPORTANT: You will receive the actual execution result in a separate message momentarily. You can say anything, however don't misguide the user assuming the request is done - because it isn't.",
                        success: true,
                        previousItemId: originalItemId
                    ))
                    try? voiceService?.createResponse()
                    addConversationItem(.toolCall(name: toolCall.name, status: .executed(success: true)))
                    approveToolCall()
                case .cancelAction:
                    rejectToolCall()
                    try? voiceService?.sendToolOutput(VoiceToolOutput(
                        toolCallId: toolCall.id,
                        output: "User cancelled the action. Original tool call ID: \(originalToolCallId). The action was not executed.",
                        success: true,
                        previousItemId: originalItemId
                    ))
                    try? voiceService?.createResponse()
                    addConversationItem(.toolCall(name: toolCall.name, status: .executed(success: true)))
                default: fatalError("Will never happen.")
                }

                return
            }
            // Handle remaining X tools normally
            else if let tool = XTool(rawValue: toolCall.name),
                      let data = toolCall.arguments.data(using: .utf8),
                      let parameters = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let outputString: String
                let isSuccess: Bool

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

                // Send result back to voice service
                try? voiceService?.sendToolOutput(VoiceToolOutput(
                    toolCallId: toolCall.id,
                    output: outputString,
                    success: isSuccess,
                    previousItemId: toolCall.itemId
                ))

                // Request assistant to respond with the tool result
                try? voiceService?.createResponse()

                addConversationItem(.toolCall(name: toolCall.name, status: .executed(success: isSuccess)))
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
        struct TweetResponse: Codable {
            let data: [XTweet]?
            let includes: Includes?
            struct Includes: Codable {
                let users: [XUser]?
                let media: [XMedia]?
                let tweets: [XTweet]?
            }
        }

        let tweetTools: Set<XTool> = [
            .searchRecentTweets, .searchAllTweets, .getTweets, .getTweet,
            .getUserLikedTweets, .getUserTweets, .getUserMentions, .getHomeTimeline, .getRepostsOfMe
        ]

        guard let data = response.data(using: .utf8),
              let tool = XTool(rawValue: toolName),
              tweetTools.contains(tool),
              let tweetResponse = try? JSONDecoder().decode(TweetResponse.self, from: data),
              let tweets = tweetResponse.data else {
            AppLogger.voice.error("Failed to parse tweets from response.")
            return
        }

        tweets.forEach { tweet in
            // Check if this is a retweet
            if tweet.isRetweet,
               let retweetedId = tweet.retweetedTweetId,
               let originalTweet = tweetResponse.includes?.tweets?.first(where: { $0.id == retweetedId }) {
                // This is a retweet - show original tweet's content, but use retweet ID for URL
                let retweeter = tweetResponse.includes?.users?.first { $0.id == tweet.author_id }
                let author = tweetResponse.includes?.users?.first { $0.id == originalTweet.author_id }
                let media = originalTweet.attachments?.media_keys?.compactMap { key in
                    tweetResponse.includes?.media?.first { $0.media_key == key }
                } ?? []
                addConversationItem(.tweet(originalTweet, author: author, media: media, retweeter: retweeter, retweetId: tweet.id))
            } else {
                // Regular tweet or quote tweet
                let author = tweetResponse.includes?.users?.first { $0.id == tweet.author_id }
                let media = tweet.attachments?.media_keys?.compactMap { key in
                    tweetResponse.includes?.media?.first { $0.media_key == key }
                } ?? []
                addConversationItem(.tweet(tweet, author: author, media: media, retweeter: nil, retweetId: nil))
            }
        }
    }

    // MARK: - X Auth

    func logoutX() async {
        await authViewModel.logout()
    }

    #if DEBUG
    func testRefreshToken() async {
        AppLogger.auth.info("🧪 Testing refresh token - forcing refresh by deleting access token...")

        // Now call getValidAccessToken which will trigger refresh
        guard let token = try? await authViewModel.authService.refreshAccessToken() else {
            AppLogger.auth.error("❌ Refresh failed - refresh token likely expired")
            addSystemMessage("❌ Refresh token test failed - you may need to re-login")
            return
        }

        AppLogger.auth.info("✅ Successfully refreshed access token")
        addSystemMessage("✅ Refresh token test passed - new token: \(token.prefix(20))...")
    }
    #endif
}

// MARK: AudioStreamerDelegate

extension VoiceAssistantViewModel: AudioStreamerDelegate {
    nonisolated func audioStreamerDidReceiveAudioData(_ data: Data) {
        Task { @MainActor in
            // Only send audio if we're connected
            guard voiceSessionState.isConnected else {
                stopSession()
                return
            }

            do {
                try voiceService?.sendAudioChunk(data)
            } catch {
                AppLogger.audio.error("Failed to send audio chunk: \(error.localizedDescription)")
                // Stop streaming to prevent error cascade
                stopSession()
            }
        }
    }

    nonisolated func audioStreamerDidDetectSpeechStart() {
        Task { @MainActor in
            // Speech framework detected actual speech
            AppLogger.audio.debug("🗣️ Speech framework detected user speaking")
        }
    }

    nonisolated func audioStreamerDidDetectSpeechEnd() {
        Task { @MainActor in
            // Speech framework detected silence - attempt commit (may fail if buffer is empty)
            AppLogger.audio.debug("🤫 Speech framework detected silence - committing buffer")
            do {
                try voiceService?.commitAudioBuffer()
            } catch {
                // Silently ignore invalid_request_error for empty buffer
                AppLogger.audio.debug("Buffer commit failed (likely empty): \(error.localizedDescription)")
            }
        }
    }

    nonisolated func audioStreamerDidUpdateAudioLevel(_ level: Float) {
        Task { @MainActor in
            self.currentAudioLevel = level
        }
    }
}
