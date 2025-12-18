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

    // MARK: Session Duration
    var sessionElapsedTime: TimeInterval = 0
    private var sessionStartTime: Date?
    private var sessionTimer: Timer?

    var formattedSessionDuration: String {
        let minutes = Int(sessionElapsedTime) / 60
        let seconds = Int(sessionElapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var conversationItems: [ConversationItem] = []

    private var pendingToolCallQueue: [PendingToolCall] = []
    var currentPendingToolCall: PendingToolCall? {
        pendingToolCallQueue.first
    }

    // MARK: - Private Properties
    private var xaiService: XAIVoiceService?
    private var audioStreamer: AudioStreamer?
    private var sessionState = SessionState()
    private let authViewModel: AuthViewModel

    private let serverSampleRate: ConversationEvent.AudioFormatType.SampleRate = .thirtyTwoKHz

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

    // MARK: - Connection Management

    func connect() {
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
                self?.stopSession()

                self?.voiceSessionState = .error(error.localizedDescription)
                self?.addSystemMessage("Error: \(error.localizedDescription)")
            }
        }

        xaiService.onDisconnected = { [weak self] error in
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
        isSessionActivated = false
        voiceSessionState = .disconnected
        xaiService?.disconnect()
        audioStreamer?.stopStreaming()

        addSystemMessage("Disconnected")
    }

    // MARK: - Audio Streaming

    func startSession() {
        // Already connected, start listening
        isSessionActivated = true
        connect()

        // Start session duration timer
        sessionStartTime = Date()
        sessionElapsedTime = 0
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.sessionStartTime else { return }
            self.sessionElapsedTime = Date().timeIntervalSince(startTime)
        }

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

    func stopSession() {
        // Stop session duration timer
        sessionTimer?.invalidate()
        sessionTimer = nil
        sessionStartTime = nil

        self.disconnect()
        currentAudioLevel = 0.0  // Reset waveform to baseline
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

        case .conversationItemAdded:
            break

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

        case .inputAudioBufferSpeechStopped:
            // User stopped speaking (server-side VAD - faster than local)
            voiceSessionState = .connected

        case .inputAudioBufferCommitted:
            // Audio sent for processing
            break

        case .responseOutputAudioDelta:
            guard !voiceSessionState.isListening else {
                AppLogger.audio.debug("User speaking, skipping Grok audio")
                return
            }

            if let delta = message.delta, let audioData = Data(base64Encoded: delta) {
                do {
                    try audioStreamer?.playAudio(audioData)
                } catch {
                    AppLogger.audio.error("Failed to play audio: \(error.localizedDescription)")
                }
                voiceSessionState = .grokSpeaking(itemId: nil)
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

    private func handleToolCall(_ toolCall: ConversationEvent.ToolCall) {
        let functionName = toolCall.function.name

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
                arguments: toolCall.function.arguments,
                previewTitle: "Allow \(functionName)?",
                previewContent: "Loading preview..."
            )
            pendingToolCallQueue.append(newPendingTool)

            addConversationItem(.toolCall(name: functionName, status: .pending))

            // Only notify Grok if this is the focused (first) tool
            if isFirstInQueue {
                try? xaiService?.sendToolOutput(
                    toolCallId: toolCall.id,
                    output: "This action requires user confirmation. Tool call ID: \(toolCall.id). Waiting for the user to confirm or cancel. Ask the user: 'Should I do this? Say yes to confirm or no to cancel.'. Send a confirm_action tool call if the user indicates that they'd like to confirm this action.",
                    success: false
                )
                try? xaiService?.createResponse()
            }

            // Fetch rich preview asynchronously to update UI
            Task { @MainActor in
                let xToolOrchestrator = XToolOrchestrator(authService: authViewModel.authService)
                let preview = await tool.generatePreview(from: toolCall.function.arguments, orchestrator: xToolOrchestrator)

                // Update with rich preview if still in queue
                if let index = pendingToolCallQueue.firstIndex(where: { $0.id == toolCall.id }) {
                    pendingToolCallQueue[index] = PendingToolCall(
                        id: toolCall.id,
                        functionName: functionName,
                        arguments: toolCall.function.arguments,
                        previewTitle: preview?.title ?? "Allow \(functionName)?",
                        previewContent: preview?.content ?? toolCall.function.arguments
                    )
                }
            }
        }
    }

    func approveToolCall() {
        guard let toolCall = pendingToolCallQueue.first else { return }

        // Execute the approved tool
        let voiceToolCall = ConversationEvent.ToolCall(
            id: toolCall.id,
            type: "function",
            function: ConversationEvent.FunctionCall(
                name: toolCall.functionName,
                arguments: toolCall.arguments
            )
        )
        executeTool(voiceToolCall)

        // Move to next tool in queue
        moveToNextPendingTool()
    }

    func rejectToolCall() {
        guard let toolCall = pendingToolCallQueue.first else { return }

        try? xaiService?.sendToolOutput(
            toolCallId: toolCall.id,
            output: "User denied this action.",
            success: false
        )

        addConversationItem(.toolCall(name: toolCall.functionName, status: .rejected))

        // Move to next tool in queue
        moveToNextPendingTool()
    }

    private func moveToNextPendingTool() {
        // Remove the current focused tool
        pendingToolCallQueue.removeFirst()

        // Notify Grok about the next focused tool if there is one
        if let nextTool = pendingToolCallQueue.first {
            try? xaiService?.sendToolOutput(
                toolCallId: nextTool.id,
                output: "This action requires user confirmation. Tool call ID: \(nextTool.id). Waiting for the user to confirm or cancel. Ask the user: 'Should I do this? Say yes to confirm or no to cancel.'",
                success: false
            )
            try? xaiService?.createResponse()
        }
    }

    private func executeTool(_ toolCall: ConversationEvent.ToolCall) {
        Task {
            // Handle voice confirmation tools specially
            if let tool = XTool(rawValue: toolCall.function.name), tool == .confirmAction || tool == .cancelAction {

                struct ConfirmationParams: Codable {
                    let tool_call_id: String
                }

                let params = try? JSONDecoder().decode(
                    ConfirmationParams.self,
                    from: toolCall.function.arguments.data(using: .utf8) ?? Data()
                )
                let originalToolCallId = params?.tool_call_id ?? "unknown"
                let originalItemId = sessionState.toolCalls.first { $0.id == originalToolCallId }?.call.itemId

                switch tool {
                case .confirmAction:
                    try? xaiService?.sendToolOutput(
                        toolCallId: toolCall.id,
                        output: "CONFIRMATION ACKNOWLEDGED: User has confirmed the action for tool call ID \(originalToolCallId). The action is now being executed. IMPORTANT: You will receive the actual execution result in a separate message momentarily. You can say anything, however don't misguide the user assuming the request is done - because it isn't.",
                        success: true,
                        previousItemId: originalItemId
                    )
                    addConversationItem(.toolCall(name: toolCall.function.name, status: .executed(success: true)))
                    approveToolCall()
                case .cancelAction:
                    rejectToolCall()
                    try? xaiService?.sendToolOutput(
                        toolCallId: toolCall.id,
                        output: "User cancelled the action. Original tool call ID: \(originalToolCallId). The action was not executed.",
                        success: true,
                        previousItemId: originalItemId
                    )
                    addConversationItem(.toolCall(name: toolCall.function.name, status: .executed(success: true)))
                default: fatalError("Will never happen.")
                }

                return
            }
            // Handle remaining X tools normally
            else if let tool = XTool(rawValue: toolCall.function.name),
                      let data = toolCall.function.arguments.data(using: .utf8),
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

                // Send result back to XAI
                try? xaiService?.sendToolOutput(
                    toolCallId: toolCall.id,
                    output: outputString,
                    success: isSuccess
                )

                addConversationItem(.toolCall(name: toolCall.function.name, status: .executed(success: isSuccess)))
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
            }
        }

        let tweetTools: Set<XTool> = [
            .searchRecentTweets, .searchAllTweets, .getTweets, .getTweet,
            .getUserLikedTweets, .getUserTweets, .getUserMentions, .getHomeTimeline
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
            let author = tweetResponse.includes?.users?.first { $0.id == tweet.author_id }
            let mediaUrls = tweet.attachments?.media_keys?.compactMap { key in
                tweetResponse.includes?.media?.first { $0.media_key == key }?.displayUrl
            } ?? []
            addConversationItem(.tweet(tweet, author: author, mediaUrls: mediaUrls))
        }
    }

    // MARK: - X Auth

    func logoutX() async {
        await authViewModel.logout()
    }
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
                try xaiService?.sendAudioChunk(data)
            } catch {
                AppLogger.audio.error("Failed to send audio chunk: \(error.localizedDescription)")
                // Stop streaming to prevent error cascade
                stopSession()
            }
        }
    }

    nonisolated func audioStreamerDidDetectSpeechStart() {
        Task { @MainActor in
            // Speech framework detected actual speech (not just noise)
            // Immediately interrupt Grok's playback for faster response
            AppLogger.audio.debug("🗣️ Speech framework detected user speaking - interrupting Grok")
        }
    }

    nonisolated func audioStreamerDidDetectSpeechEnd() {
        Task { @MainActor in
            // Speech framework detected silence
            // Server-side VAD will handle the buffer commit when ready
            AppLogger.audio.debug("🤫 Speech framework detected silence")
        }
    }

    nonisolated func audioStreamerDidUpdateAudioLevel(_ level: Float) {
        Task { @MainActor in
            self.currentAudioLevel = level
        }
    }
}
