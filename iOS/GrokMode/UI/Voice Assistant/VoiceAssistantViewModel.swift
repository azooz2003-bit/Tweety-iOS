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
    // State
    var micPermission: MicPermissionState = .checking
    var voiceSessionState: VoiceSessionState = .disconnected
    var isSessionActivated: Bool = false
    var currentAudioLevel: Float = 0.0

    // Conversation
    var conversationItems: [ConversationItem] = []

    // Tool Confirmation Queue
    private var pendingToolCallQueue: [PendingToolCall] = []

    // Currently focused pending tool call (first in queue)
    var currentPendingToolCall: PendingToolCall? {
        pendingToolCallQueue.first
    }

    // MARK: - Private Properties

    private var xaiService: XAIVoiceService?
    private var audioStreamer: AudioStreamer?
    private var sessionState = SessionState()
    private let authViewModel: AuthViewModel

    // Truncation tracking
    private var currentItemId: String?
    private var currentAudioStartTime: Date?

    // Configuration
    private let serverSampleRate: ConversationEvent.AudioFormatType.SampleRate = .fourtyEightKHz

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
        xaiService?.disconnect()
        audioStreamer?.stopStreaming()
        voiceSessionState = .disconnected

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

    func startSession() {
        // Already connected, start listening
        isSessionActivated = true
        connect()

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

            // Track item ID for truncation
            if let item = message.item {
                currentItemId = item.id
                currentAudioStartTime = nil
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

            currentItemId = nil
            currentAudioStartTime = nil

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
                    output: "This action requires user confirmation. Tool call ID: \(toolCall.id). Waiting for the user to confirm or cancel. Ask the user: 'Should I do this? Say yes to confirm or no to cancel.'",
                    success: false
                )
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
        }
    }

    // Execute the approved tool and return results
    private func executeApprovedTool() async -> (output: String, success: Bool) {
        guard let pendingTool = pendingToolCallQueue.first else {
            return ("No pending tool to execute", false)
        }

        // Parse arguments
        guard let data = pendingTool.arguments.data(using: .utf8),
              let parameters = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tool = XTool(rawValue: pendingTool.functionName) else {
            return ("Failed to parse tool parameters", false)
        }

        // Execute the tool
        let orchestrator = XToolOrchestrator(authService: authViewModel.authService)
        let result = await orchestrator.executeTool(tool, parameters: parameters, id: pendingTool.id)

        let outputString: String
        let isSuccess: Bool

        if result.success, let response = result.response {
            outputString = response
            isSuccess = true

            // Parse and display tweets if applicable
            await MainActor.run {
                parseTweetsFromResponse(response, toolName: tool.rawValue)
                addConversationItem(.toolCall(name: pendingTool.functionName, status: .executed(success: true)))
            }
        } else {
            outputString = result.error?.message ?? "Unknown error"
            isSuccess = false

            await MainActor.run {
                addConversationItem(.toolCall(name: pendingTool.functionName, status: .executed(success: false)))
            }
        }

        return (outputString, isSuccess)
    }

    private func executeTool(_ toolCall: ConversationEvent.ToolCall) {
        Task {
            // Handle voice confirmation tools specially
            if let tool = XTool(rawValue: toolCall.function.name) {
                switch tool {
                case .confirmAction:
                    // Parse the tool_call_id parameter
                    let originalToolCallId: String
                    if let data = toolCall.function.arguments.data(using: .utf8),
                       let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let toolCallId = params["tool_call_id"] as? String {
                        originalToolCallId = toolCallId
                    } else {
                        originalToolCallId = "unknown"
                    }

                    // Send immediate confirmation response
                    try? xaiService?.sendToolOutput(
                        toolCallId: toolCall.id,
                        output: "CONFIRMATION ACKNOWLEDGED: User has confirmed the action for tool call ID \(originalToolCallId). The action is now being executed. IMPORTANT: You will receive the actual execution result in a separate message momentarily - do NOT speak about the result until you receive it.",
                        success: true
                    )

                    addConversationItem(.toolCall(name: toolCall.function.name, status: .executed(success: true)))

                    // Execute tool asynchronously and send result when ready
                    Task {
                        let (outputString, isSuccess) = await executeApprovedTool()

                        // Send the actual tool result in a separate message
                        try? xaiService?.sendToolOutput(
                            toolCallId: originalToolCallId,
                            output: outputString,
                            success: isSuccess
                        )

                        try? xaiService?.createResponse()

                        // After sending the result, move to next pending tool
                        await MainActor.run {
                            moveToNextPendingTool()
                        }
                    }

                    return

                case .cancelAction:
                    // Parse the tool_call_id parameter
                    let originalToolCallId: String
                    if let data = toolCall.function.arguments.data(using: .utf8),
                       let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let toolCallId = params["tool_call_id"] as? String {
                        originalToolCallId = toolCallId
                    } else {
                        originalToolCallId = "unknown"
                    }

                    rejectToolCall()

                    // Send success response to Grok with original tool call ID
                    try? xaiService?.sendToolOutput(
                        toolCallId: toolCall.id,
                        output: "User cancelled the action. Original tool call ID: \(originalToolCallId). The action was not executed.",
                        success: true
                    )

                    addConversationItem(.toolCall(name: toolCall.function.name, status: .executed(success: true)))
                    try? xaiService?.createResponse()
                    return

                default:
                    break
                }
            }

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
        guard let data = response.data(using: .utf8) else { return }

        let tweetTools: Set<XTool> = [
            .searchRecentTweets, .searchAllTweets, .getTweets, .getTweet,
            .getUserLikedTweets, .getUserTweets, .getUserMentions, .getHomeTimeline
        ]

        do {
            if let xTool = XTool(rawValue: toolName), tweetTools.contains(xTool) {
                struct TweetResponse: Codable {
                    let data: [XTweet]?
                    let includes: Includes?

                    struct Includes: Codable {
                        let users: [XUser]?
                        let media: [XMedia]?
                    }
                }

                let tweetResponse = try JSONDecoder().decode(TweetResponse.self, from: data)

                if let tweets = tweetResponse.data {
                    for tweet in tweets {
                        let author = tweetResponse.includes?.users?.first { $0.id == tweet.author_id }

                        // Extract media URLs
                        var mediaUrls: [String] = []
                        if let mediaKeys = tweet.attachments?.media_keys,
                           let allMedia = tweetResponse.includes?.media {
                            for mediaKey in mediaKeys {
                                if let media = allMedia.first(where: { $0.media_key == mediaKey }),
                                   let displayUrl = media.displayUrl {
                                    mediaUrls.append(displayUrl)
                                }
                            }
                        }

                        addConversationItem(.tweet(tweet, author: author, mediaUrls: mediaUrls))
                    }
                }
            }
        } catch {
            AppLogger.network.error("Failed to parse tweets: \(error.localizedDescription)")
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

            voiceSessionState = .listening
            audioStreamer?.stopPlayback()

            currentItemId = nil
            currentAudioStartTime = nil
        }
    }

    nonisolated func audioStreamerDidDetectSpeechEnd() {
        Task { @MainActor in
            // Speech framework detected silence
            // Server-side VAD will handle the buffer commit when ready
            AppLogger.audio.debug("🤫 Speech framework detected silence")
            voiceSessionState = .connected
            try? self.xaiService?.commitAudioBuffer()
        }
    }

    nonisolated func audioStreamerDidUpdateAudioLevel(_ level: Float) {
        Task { @MainActor in
            self.currentAudioLevel = level
        }
    }
}
