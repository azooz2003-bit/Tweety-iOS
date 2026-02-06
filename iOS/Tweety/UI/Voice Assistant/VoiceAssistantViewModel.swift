//
//  VoiceAssistantViewModel.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI
import AVFoundation
import Combine
import OSLog
import StoreKit

@Observable
class VoiceAssistantViewModel {
    private enum UserDefaultsKey {
        static let selectedVoiceService = "com.tweety.selectedVoiceService"
        static let selectedVoice = "com.tweety.selectedVoice"
    }

    // MARK: State
    var micPermission: MicPermissionState = .checking
    var voiceSessionState: VoiceSessionState = .disconnected
    var isSessionActivated: Bool = false
    var currentAudioLevel: Float = 0.0

    var selectedServiceType: VoiceServiceType {
        didSet {
            UserDefaults.standard.set(selectedServiceType.rawValue, forKey: UserDefaultsKey.selectedVoiceService)
        }
    }

    var selectedVoice: VoiceOption {
        didSet {
            UserDefaults.standard.set(selectedVoice.rawValue, forKey: UserDefaultsKey.selectedVoice)
        }
    }

    var accessBlockedReason: AccessBlockedReason?
    var showAIConsentAlert: Bool = false

    // MARK: Session
    /// For serializing sessions start and stops
    private var sessionStartStopTask: Task<Void, Never>?

    var conversationItems: [ConversationItem] = []

    private var pendingToolCallQueue: [PendingToolCall] = []
    var currentPendingToolCall: PendingToolCall? {
        pendingToolCallQueue.first
    }

    // MARK: - Private Properties
    private var connectionStartTime: Date?
    private var voiceService: VoiceService?
    private var audioStreamer: AudioStreamer?
    private let authViewModel: AuthViewModel
    private let appAttestService: AppAttestService
    private let creditsService: RemoteCreditsService
    let storeManager: StoreKitManager
    let usageTracker: UsageTracker
    let usageClock: VoiceUsageClock
    let consentManager: AIConsentManager

    // MARK: Authentication
    var isXAuthenticated: Bool {
        authViewModel.isAuthenticated
    }
    var xUserHandle: String? {
        authViewModel.currentUserHandle
    }

    init(authViewModel: AuthViewModel, appAttestService: AppAttestService, creditsService: RemoteCreditsService, storeManager: StoreKitManager, usageTracker: UsageTracker, consentManager: AIConsentManager) {
        self.authViewModel = authViewModel
        self.appAttestService = appAttestService
        self.creditsService = creditsService
        self.storeManager = storeManager
        self.usageTracker = usageTracker
        self.usageClock = VoiceUsageClock(usageTracker: usageTracker, authService: authViewModel.authService)
        self.consentManager = consentManager

        let serviceStr = UserDefaults.standard.string(forKey: UserDefaultsKey.selectedVoiceService) ?? "" // nil coalesce below should handle ""
        selectedServiceType = VoiceServiceType(rawValue: serviceStr) ?? .openai

        let voiceStr = UserDefaults.standard.string(forKey: UserDefaultsKey.selectedVoice) ?? "" // nil coalesce below should handle ""
        selectedVoice = VoiceOption(rawValue: voiceStr) ?? .coral

        usageClock.onInsufficientCredits = { [weak self] in
            AnalyticsManager.log(.voiceSessionStoppedAbruptly(VoiceSessionStoppedAbruptlyEvent(reason: "Insufficient credits")))
            self?.stopSession()
            self?.accessBlockedReason = .insufficientCredits
        }
        usageClock.onTrackingError = { [weak self] error in
            AnalyticsManager.log(.voiceSessionStoppedAbruptly(VoiceSessionStoppedAbruptlyEvent(reason: "Usage tracking failed")))
            self?.stopSession()
            self?.voiceSessionState = .error("Usage tracking failed. Session stopped.")
        }

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

        let voiceService = selectedServiceType.createService(appAttestService: appAttestService, authService: authViewModel.authService, storeManager: storeManager, usageTracker: usageTracker, voice: selectedVoice)
        self.voiceService = voiceService

        // Initialize audio streamer with service-specific sample rate
        audioStreamer = try? await AudioStreamer.make(remoteSampleRate: Double(voiceService.requiredSampleRate))
        audioStreamer?.delegate = self

        // Set up callbacks (already on main actor)
        voiceService.onConnected = { [weak self] in
            Task { @MainActor in
                if let startTime = self?.connectionStartTime {
                    let launchTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
                    AnalyticsManager.log(.voiceSessionBegan(VoiceSessionBeganEvent(sessionLaunchTimeMs: launchTimeMs)))
                }
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
                AnalyticsManager.log(.voiceSessionStoppedAbruptly(VoiceSessionStoppedAbruptlyEvent(reason: error.localizedDescription)))

                // Stop audio streaming immediately to prevent cascade of errors
                self?.stopSession()
                self?.voiceSessionState = .error(error.localizedDescription)

                switch error {
                case .insufficientCredits:
                    self?.accessBlockedReason = .insufficientCredits
                case .usageTrackingFailed, .websocketError:
                    break
                }
            }
        }

        voiceService.onDisconnected = { [weak self] closeCode in
            Task { @MainActor in
                guard self?.voiceSessionState != .disconnected else { return }

                if closeCode == .normalClosure || closeCode == .goingAway {
                    AppLogger.voice.info("WebSocket disconnected normally (code: \(closeCode.rawValue))")
                } else {
                    AppLogger.voice.error("WebSocket disconnected with error code: \(closeCode.rawValue)")
                    AnalyticsManager.log(.voiceSessionStoppedAbruptly(VoiceSessionStoppedAbruptlyEvent(reason: "WebSocket disconnected: \(closeCode.rawValue)")))
                }

                self?.stopSession()

                if closeCode != .normalClosure && closeCode != .goingAway {
                    self?.voiceSessionState = .error("Disconnected: \(closeCode.rawValue)")
                }
            }
        }

        do {
            #if DEBUG
            AppLogger.network.debug("===== USER PROFILE REQUEST =====")
            #endif

            let orchestrator = XAPIOrchestrator(authService: self.authViewModel.authService, storeManager: storeManager, usageTracker: usageTracker)

            // Connect to voice service in parallel with user profile fetch
            async let connect: () = voiceService.connect()
            async let userProfileResult = orchestrator.executeEndpoint(.getAuthenticatedUser, parameters: [:])

            let (_, _) = (await userProfileResult, try await connect)

            let tools = ToolIntegration.getToolDefinitions()

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

    // MARK: - Session

    func startSession() {
        guard consentManager.hasGivenConsent else {
            showAIConsentAlert = true
            return
        }

        connectionStartTime = Date()
        isSessionActivated = true
        sessionStartStopTask?.cancel()
        accessBlockedReason = nil
        sessionStartStopTask = Task { @MainActor in
            await storeManager.restoreAllTransactions()

            // Check balance & sub before starting
            do {
                let userId = try await authViewModel.authService.requiredUserId

                async let checkBalance = creditsService.getBalance(userId: userId)
                async let checkHasFreeAccess = creditsService.checkFreeAccess(userId: userId)

                let (balance, hasFreeAccess) = await (try checkBalance, (try? checkHasFreeAccess) ?? false)

                AppLogger.usage.debug("hasFreeAccess: \(hasFreeAccess)")

                guard hasFreeAccess || !storeManager.activeSubscriptions.isEmpty else{
                    AnalyticsManager.log(.sessionRejected(SessionRejectedEvent(reason: "No active subscription")))
                    self.isSessionActivated = false
                    self.accessBlockedReason = .noSubscription
                    return
                }

                guard hasFreeAccess || balance.remaining > 0 else {
                    AnalyticsManager.log(.sessionRejected(SessionRejectedEvent(reason: "Insufficient balance")))
                    self.isSessionActivated = false
                    self.accessBlockedReason = .insufficientCredits
                    return
                }

                AppLogger.voice.info("Balance check passed: $\(balance.remaining) remaining")
            } catch {
                AppLogger.voice.error("Pre-session checks failed: \(error)")
                AnalyticsManager.log(.sessionRejected(SessionRejectedEvent(reason: error.localizedDescription)))
                self.voiceSessionState = .error("Could not verify balance. Check your connection.")
                self.isSessionActivated = false
                return
            }

            guard !Task.isCancelled else { return }

            await connect()

            guard !Task.isCancelled else { return }

            usageClock.startTimer(for: selectedServiceType)

            guard !Task.isCancelled else { return }

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
        guard self.isSessionActivated else { return }
        
        isSessionActivated = false
        currentAudioLevel = 0.0
        sessionStartStopTask?.cancel()
        sessionStartStopTask = Task { @MainActor in
            // Track any remaining partial minute for xAI sessions
            usageClock.trackPartialUsageIfNeeded(for: selectedServiceType)
            usageClock.stopTimer()

            self.disconnect()
            currentAudioLevel = 0.0  // Reset waveform to baseline
        }
    }


    // MARK: - Event Handling

    private func handleVoiceEvent(_ event: VoiceEvent) {
        switch event {
        case .sessionCreated:
            break

        case .sessionConfigured:
            break

        case .userSpeechStarted:
            AnalyticsManager.log(.voiceModelEvent(VoiceModelEvent(eventType: "user_speech_started")))
            try? voiceService?.truncateResponse()
            audioStreamer?.stopPlayback()
            voiceSessionState = .listening

        case .userSpeechStopped:
            AnalyticsManager.log(.voiceModelEvent(VoiceModelEvent(eventType: "user_speech_stopped")))
            voiceSessionState = .connected

        case .assistantSpeaking(let itemId):
            AnalyticsManager.log(.voiceModelEvent(VoiceModelEvent(eventType: "assistant_speaking")))
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

        guard let tool = Tool(rawValue: functionName) else {
            // Unknown tool - execute anyway
            executeTool(toolCall)
            return
        }

        switch tool {
        case .apiEndpoint(let endpoint):
            // Route API endpoint based on preview behavior
            switch endpoint.previewBehavior {
            case .none:
                // Safe tool - execute immediately
                executeTool(toolCall)

            case .requiresConfirmation:
                guard FeatureFlags.shared.shouldRequireConfirmation(for: endpoint) else {
                    executeTool(toolCall)
                    break
                }

                // Check if this will be the focused tool (first in queue)
                let isFirstInQueue = pendingToolCallQueue.isEmpty

                // Add to queue with placeholder
                let newPendingTool = PendingToolCall(
                    id: toolCall.id,
                    functionName: functionName,
                    arguments: toolCall.arguments,
                    previewTitle: "Allow \(functionName)?",
                    previewContent: "Loading preview...",
                    itemId: toolCall.itemId
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
                    let apiOrchestrator = XAPIOrchestrator(authService: authViewModel.authService, storeManager: storeManager, usageTracker: usageTracker)
                    let preview = await endpoint.generatePreview(from: toolCall.arguments, orchestrator: apiOrchestrator)

                    // Update with rich preview if still in queue
                    if let index = pendingToolCallQueue.firstIndex(where: { $0.id == toolCall.id }) {
                        pendingToolCallQueue[index] = PendingToolCall(
                            id: toolCall.id,
                            functionName: functionName,
                            arguments: toolCall.arguments,
                            previewTitle: preview?.title ?? "Allow \(functionName)?",
                            previewContent: preview?.content ?? "Review and confirm this action",
                            itemId: toolCall.itemId
                        )
                    }
                }
            }

        case .flowAction:
            // Flow actions always execute immediately (no confirmation needed)
            executeTool(toolCall)
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
            guard let tool = Tool(rawValue: toolCall.name) else { return }

            switch tool {
            case .flowAction(let action):
                struct ConfirmationParams: Codable {
                    let tool_call_id: String
                }

                let params = try? JSONDecoder().decode(
                    ConfirmationParams.self,
                    from: toolCall.arguments.data(using: .utf8) ?? Data()
                )
                let originalToolCallId = params?.tool_call_id ?? "unknown"
                let originalItemId = pendingToolCallQueue.first { $0.id == originalToolCallId }?.itemId

                switch action {
                case .confirmAction:
                    // Validate that the tool call still exists in pending queue
                    guard pendingToolCallQueue.contains(where: { $0.id == originalToolCallId }) else {
                        // Tool call not found - likely cancelled or already executed
                        try? voiceService?.sendToolOutput(VoiceToolOutput(
                            toolCallId: toolCall.id,
                            output: "ERROR: This action cannot be confirmed because it is no longer pending. You likely already cancelled this action. Tell the user: 'I cannot complete that action because it was already cancelled.' Do not attempt to confirm this action again.",
                            success: false,
                            previousItemId: originalItemId
                        ))
                        try? voiceService?.createResponse()
                        addConversationItem(.toolCall(name: toolCall.name, status: .executed(success: false)))
                        return
                    }

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
                }

            case .apiEndpoint(let endpoint):
                guard let data = toolCall.arguments.data(using: .utf8),
                      let parameters = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return
                }

                let outputString: String
                let isSuccess: Bool

                let orchestrator = XAPIOrchestrator(authService: authViewModel.authService, storeManager: storeManager, usageTracker: usageTracker)
                let result = await orchestrator.executeEndpoint(endpoint, parameters: parameters, id: toolCall.id)

                if result.success, let response = result.response {
                    outputString = response
                    isSuccess = true

                    // Parse and display tweets if applicable
                    parseTweetsFromResponse(response, toolName: endpoint.rawValue)
                } else {
                    outputString = result.error?.message ?? "Unknown error"
                    isSuccess = false

                    // Check if credits depleted - stop session if so
                    if result.error?.code == .insufficientCredits {
                        AppLogger.voice.error("X API tool depleted credits")
                        stopSession()
                        accessBlockedReason = .insufficientCredits
                        return
                    }
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
        let tweetTools: Set<XAPIEndpoint> = [
            .searchRecentTweets, .searchAllTweets, .getTweets, .getTweet,
            .getUserLikedTweets, .getUserTweets, .getUserMentions, .getHomeTimeline, .getRepostsOfMe
        ]

        guard let data = response.data(using: .utf8),
              let endpoint = XAPIEndpoint(rawValue: toolName),
              tweetTools.contains(endpoint),
              let tweetResponse = try? JSONDecoder().decode(XTweetResponse.self, from: data),
              let tweets = tweetResponse.data else {
            AppLogger.voice.error("Failed to parse tweets from response.")
            return
        }

        addConversationItem(.tweets(tweets.map { EnrichedTweet(from: $0, includes: tweetResponse.includes) }))
    }

    // MARK: - Purchase

    func handleAccessBlockedPurchase() async {
        guard let reason = accessBlockedReason else { return }

        switch reason {
        case .noSubscription:
            // Find subscription product
            if let subscriptionProduct = storeManager.products.first(where: {
                ProductConfiguration.ProductID(rawValue: $0.id)?.isSubscription == true
            }) {
                AnalyticsManager.log(.subscribeButtonPressedFromChatError(SubscribeButtonPressedFromChatErrorEvent()))
                do {
                    _ = try await storeManager.purchase(subscriptionProduct)
                    let currency = subscriptionProduct.priceFormatStyle.currencyCode
                    AnalyticsManager.log(.subscribeSucceededFromChatError(SubscribeSucceededFromChatErrorEvent(
                        productId: subscriptionProduct.id,
                        price: Double(truncating: subscriptionProduct.price as NSNumber),
                        currency: currency
                    )))
                    accessBlockedReason = nil
                } catch {
                    AnalyticsManager.log(.subscribeFailedFromChatError(SubscribeFailedFromChatErrorEvent(
                        productId: subscriptionProduct.id,
                        errorReason: error.localizedDescription
                    )))
                    AppLogger.voice.error("Subscription purchase failed: \(error)")
                }
            }

        case .insufficientCredits:
            // Find credits product
            if let creditsProduct = storeManager.products.first(where: {
                $0.id == ProductConfiguration.ProductID.credits10.rawValue
            }) {
                AnalyticsManager.log(.creditsPurchaseButtonPressedFromChatError(CreditsPurchaseButtonPressedFromChatErrorEvent()))
                do {
                    _ = try await storeManager.purchase(creditsProduct)
                    let currency = creditsProduct.priceFormatStyle.currencyCode
                    let creditsAmount = ProductConfiguration.creditsAmount(for: creditsProduct.id) ?? 0
                    AnalyticsManager.log(.creditsPurchaseSucceededFromChatError(CreditsPurchaseSucceededFromChatErrorEvent(
                        productId: creditsProduct.id,
                        price: Double(truncating: creditsProduct.price as NSNumber),
                        currency: currency,
                        creditsAmount: creditsAmount
                    )))
                    accessBlockedReason = nil
                } catch {
                    AnalyticsManager.log(.creditsPurchaseFailedFromChatError(CreditsPurchaseFailedFromChatErrorEvent(
                        productId: creditsProduct.id,
                        errorReason: error.localizedDescription
                    )))
                    AppLogger.voice.error("Credits purchase failed: \(error)")
                }
            }
        }
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
            AppLogger.audio.debug("Speech framework detected user speaking")
        }
    }

    nonisolated func audioStreamerDidDetectSpeechEnd() {
        Task { @MainActor in
            // Speech framework detected silence - attempt commit (may fail if buffer is empty)
            AppLogger.audio.debug("Speech framework detected silence - committing buffer")
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
