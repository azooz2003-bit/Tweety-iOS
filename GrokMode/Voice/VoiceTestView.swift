//
//  VoiceTestView.swift
//  GrokMode
//
//  Created by Elon Musk's AI Assistant on 12/7/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Main View

struct VoiceTestView: View {
    @State private var viewModel = VoiceTestViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    Text("🎙️ XAI Voice Test")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // Components
                    PermissionStatusView(viewModel: viewModel)
                    ConnectionStatusView(viewModel: viewModel)
                    MessageLogView(viewModel: viewModel)
                    
                    Spacer()
                }
                .padding()
                .onAppear {
                    viewModel.checkPermissions()
                }
            }
            .navigationViewStyle(.stack)
        }
        .overlay(ToolConfirmationOverlay(viewModel: viewModel))
    }
}

// MARK: - Subviews

struct PermissionStatusView: View {
    @Bindable var viewModel: VoiceTestViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Microphone Permission")
                .font(.headline)
            
            HStack {
                Image(systemName: viewModel.micPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(viewModel.micPermissionGranted ? .green : .red)
                Text(viewModel.micPermissionStatus)
                Spacer()
                if !viewModel.micPermissionGranted {
                    Button("Request Access") {
                        viewModel.requestMicrophonePermission()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ConnectionStatusView: View {
    @Bindable var viewModel: VoiceTestViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connection Status")
                .font(.headline)
            
            HStack {
                Circle()
                    .fill(viewModel.connectionStateColor)
                    .frame(width: 12, height: 12)
                Text(viewModel.connectionStateText)
                Spacer()
                Text(viewModel.lastActivityText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("Session:")
                Image(systemName: viewModel.sessionConfigured ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(viewModel.sessionConfigured ? .green : .gray)
                Text(viewModel.sessionConfigured ? "Configured" : "Not Configured")
            }
            
            HStack {
                Text("Audio:")
                Image(systemName: viewModel.isAudioStreaming ? "waveform.circle.fill" : "waveform.circle")
                    .foregroundColor(viewModel.isAudioStreaming ? .blue : .gray)
                Text(viewModel.isAudioStreaming ? "Streaming" : "Not Streaming")
            }

            HStack {
                Text("Gerald:")
                Image(systemName: viewModel.isGeraldSpeaking ? "speaker.wave.3.fill" : "speaker.slash.fill")
                    .foregroundColor(viewModel.isGeraldSpeaking ? .green : .gray)
                Text(viewModel.isGeraldSpeaking ? "Speaking" : "Silent")
            }
            
            VStack(spacing: 10) {
                Button(action: viewModel.connect) {
                    Text(viewModel.isConnecting ? "Connecting..." : "Connect")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canConnect || viewModel.isConnecting)
                
                Button(action: viewModel.disconnect) {
                    Text("Disconnect")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.connectionState == .disconnected)
                
                Button(action: viewModel.clearLog) {
                    Text("Clear Log")
                }
                .buttonStyle(.bordered)
                
                Button(action: viewModel.sendTestAudio) {
                    Text("Send Test Audio")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.connectionState != .connected)
                
                Button(action: {
                    if viewModel.isAudioStreaming {
                        viewModel.stopAudioStreaming()
                    } else {
                        viewModel.startAudioStreaming()
                    }
                }) {
                    Text(viewModel.isAudioStreaming ? "Stop Streaming" : "Start Streaming")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.connectionState != .connected)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct MessageLogView: View {
    @Bindable var viewModel: VoiceTestViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Message Log")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.messageLog.count) messages")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.messageLog) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 300)
                .background(Color.black.opacity(0.05))
                .cornerRadius(8)
                .onChange(of: viewModel.messageLog.count) { _ in
                    if let lastMessage = viewModel.messageLog.last {
                        scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
    }
}

struct ToolConfirmationOverlay: View {
    @Bindable var viewModel: VoiceTestViewModel
    
    var body: some View {
        Group {
            if let toolCall = viewModel.pendingToolCall {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Text("Preview Action")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(toolCall.previewTitle)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            Text(toolCall.previewContent)
                                .font(.body)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        HStack(spacing: 20) {
                            Button("Cancel") {
                                viewModel.rejectToolCall()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                            
                            Button("Approve") {
                                viewModel.approveToolCall()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding(.horizontal, 40)
                }
            }
        }
    }
}

// MARK: - Supporting Views and Models

struct MessageRow: View {
    let message: DebugMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message.timestampString)
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(width: 60, alignment: .leading)

            Text(message.directionArrow)
                .font(.caption)
                .foregroundColor(message.directionColor)

            Text(message.typeIcon)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(message.typeColor)

                if !message.details.isEmpty {
                    Text(message.details)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct DebugMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: MessageType
    let direction: MessageDirection
    let title: String
    let details: String

    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var directionArrow: String {
        switch direction {
        case .sent: return "→"
        case .received: return "←"
        case .system: return "⚙️"
        }
    }

    var directionColor: Color {
        switch direction {
        case .sent: return .blue
        case .received: return .green
        case .system: return .orange
        }
    }

    var typeIcon: String {
        switch type {
        case .websocket: return "🔗"
        case .audio: return "🎵"
        case .system: return "⚙️"
        case .error: return "❌"
        }
    }

    var typeColor: Color {
        switch type {
        case .websocket: return .blue
        case .audio: return .purple
        case .system: return .orange
        case .error: return .red
        }
    }
}

enum MessageType {
    case websocket, audio, system, error
}

enum MessageDirection {
    case sent, received, system
}

enum ConnectionState {
    case disconnected, connecting, connected, error
}

struct PendingToolCall {
    let id: String
    let functionName: String
    let arguments: String
    let previewTitle: String
    let previewContent: String
}

// MARK: - ViewModel

@Observable
class VoiceTestViewModel: NSObject, AudioStreamerDelegate {
    // Permissions
    var micPermissionGranted = false
    var micPermissionStatus = "Checking..."

    // Connection
    var connectionState: ConnectionState = .disconnected
    var isConnecting = false
    var sessionConfigured = false
    var lastActivity: Date?
    var isAudioStreaming = false


    // Audio streaming
    var isGeraldSpeaking = false
    var messageLog: [DebugMessage] = []
    
    // Scenario Configuration
    var scenarioTopic: String = "Grok bug"
    
    // Tool Confirmation
    var pendingToolCall: PendingToolCall?


    // XAI Service
    internal var xaiService: XAIVoiceService?
    
    // Linear Service
    private let linearService = LinearAPIService(apiToken: Config.linearApiKey)
    
    // Audio Streamer
    private var audioStreamer: AudioStreamer!

    override init() {
        super.init()
        // Initialize AudioStreamer
        audioStreamer = AudioStreamer()
        audioStreamer.delegate = self
        
        checkPermissions()
    }

    var canConnect: Bool {
        return micPermissionGranted && connectionState == .disconnected && !isConnecting
    }

    var connectionStateColor: Color {
        switch connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .error: return .red
        }
    }

    var connectionStateText: String {
        switch connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Connection Error"
        }
    }

    var lastActivityText: String {
        guard let lastActivity = lastActivity else { return "No activity" }
        let seconds = Int(Date().timeIntervalSince(lastActivity))
        if seconds < 60 {
            return "\(seconds)s ago"
        } else {
            return "1m+ ago"
        }
    }

    func checkPermissions() {
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission

        switch permissionStatus {
        case .granted:
            micPermissionGranted = true
            micPermissionStatus = "Granted"
            logMessage(.system, .system, "Microphone permission granted", "")
        case .denied:
            micPermissionGranted = false
            micPermissionStatus = "Denied"
            logMessage(.system, .system, "Microphone permission denied", "")
        case .undetermined:
            micPermissionGranted = false
            micPermissionStatus = "Not requested"
            logMessage(.system, .system, "Microphone permission not requested", "")
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
                let status = granted ? "granted" : "denied"
                self?.logMessage(.system, .system, "Microphone permission \(status)", "")
            }
        }
    }

    func connect() {
        guard canConnect else { return }

        isConnecting = true
        connectionState = .connecting
        sessionConfigured = false

        logMessage(.system, .system, "Starting CEO Demo connection", "")

        // Initialize XAI service
        xaiService = XAIVoiceService(apiKey: Config.xAiApiKey)
        
        // Tool Orchestrator
        let toolOrchestrator = XToolOrchestrator()

        // Set up callbacks
        xaiService?.onConnected = { [weak self] in
            DispatchQueue.main.async {
                self?.connectionState = .connected
                self?.isConnecting = false
                self?.lastActivity = Date()
                self?.logMessage(.system, .system, "XAI connection established", "")
            }
        }

        xaiService?.onMessageReceived = { [weak self] message in
            DispatchQueue.main.async {
                self?.handleXAIMessage(message)
            }
        }

        xaiService?.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.connectionState = .error
                self?.isConnecting = false
                self?.logMessage(.error, .system, "XAI Error", error.localizedDescription)
            }
        }

        // Start connection
        Task {
            do {
                await MainActor.run {
                    self.logMessage(.system, .system, "Searching X for '\(self.scenarioTopic)'...", "")
                }
                
                let searchResult = await toolOrchestrator.executeTool(.searchRecentTweets, parameters: ["query": self.scenarioTopic, "max_results": 10])
                print("X TOOL: Pre-fetching tweets for topic: '\(self.scenarioTopic)'")
                
                var contextString = ""
                // XToolCallResult is a struct, handle success/failure manually
                if searchResult.success {
                     contextString = searchResult.response ?? "No tweets found."
                     print("X TOOL: Pre-fetch success. Result length: \(contextString.count) chars")
                     print("X TOOL: Pre-fetch content (truncated): \(contextString.prefix(200))...")
                     
                     await MainActor.run {
                         self.logMessage(.system, .system, "Found relevant tweets", "")
                     }
                } else {
                    let errorMsg = searchResult.error?.message ?? "Unknown error"
                    print("X TOOL: Pre-fetch failed. Error: \(errorMsg)")
                    contextString = "Error fetching tweets: \(errorMsg)"
                    
                    await MainActor.run {
                        self.logMessage(.error, .system, "Tweet pre-fetch failed", errorMsg)
                    }
                }

                // 2. Connect
                try await xaiService!.connect()

                // 3. Configure Session with Tools and Context
                let tools = XToolIntegration.getToolDefinitions()
                try xaiService!.configureSession(tools: tools)
                
                // Send the context as a user message
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
                           text: "SYSTEM CONTEXT: You have just searched for '\(self.scenarioTopic)' and found these recent tweets: \(contextString). Use this context for the morning brief.",
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
                   start_time: nil,
                   timestamp: nil,
                   part: nil,
                   response: nil,
                   conversation: nil
               )
               try xaiService!.sendMessage(contextMessage)
               
                // 4. Send Demo Greeting

                await MainActor.run {
                    logMessage(.system, .system, "Session ready for CEO Demo", "")
                }

            } catch {
                await MainActor.run {
                    self.connectionState = .error
                    self.isConnecting = false
                    self.logMessage(.error, .system, "Connection failed", error.localizedDescription)
                }
            }
        }
    }

    func disconnect() {
        xaiService?.disconnect()
        audioStreamer.stopStreaming()
        isGeraldSpeaking = false

        connectionState = .disconnected
        isConnecting = false
        sessionConfigured = false
        isAudioStreaming = false
        logMessage(.system, .system, "Disconnected from XAI", "")
    }

    func clearLog() {
        messageLog.removeAll()
    }

    func sendTestAudio() {
        logMessage(.system, .system, "Sending test audio to XAI", "")

        // Create a simple test audio buffer (1 second of silence at 24kHz, 16-bit PCM)
        let sampleRate = 24000
        let duration = 1.0 // 1 second
        let samples = Int(Float(sampleRate) * Float(duration))
        let audioData = Data(repeating: 0, count: samples * 2) // 16-bit samples = 2 bytes each

        do {
            try xaiService?.sendAudioChunk(audioData)
            try xaiService?.commitAudioBuffer()
            logMessage(.audio, .sent, "Test audio sent", "\(audioData.count) bytes")
        } catch {
            logMessage(.error, .system, "Failed to send test audio", error.localizedDescription)
        }
    }

    func startAudioStreaming() {
        guard connectionState == .connected else {
            logMessage(.error, .system, "Cannot start audio streaming", "Not connected to XAI")
            return
        }
        audioStreamer.startStreaming()
        isAudioStreaming = true
        logMessage(.system, .system, "Audio streaming started", "")
    }

    func stopAudioStreaming() {
        audioStreamer.stopStreaming()
        isAudioStreaming = false
        logMessage(.system, .system, "Audio streaming stopped", "")
    }


    private func handleXAIMessage(_ message: VoiceMessage) {
        // Print to console for debugging
        print("🔊 XAI WebSocket Message: \(message.type)")
        if let text = message.text {
            print("🔊 Text: \(text)")
        }
        if let audio = message.audio {
            print("🔊 Audio: \(audio.prefix(50))... (\(audio.count) chars)")
        }

        // ALL UI updates must be on main thread
        DispatchQueue.main.async {
            self.lastActivity = Date()

            // Log to UI
            let title: String
            var details = ""

            switch message.type {
            case "conversation.created":
                title = "Conversation Created"
                details = "XAI session initialized"
                self.sessionConfigured = true

            case "session.updated":
                title = "Session Updated"
                details = "Voice session configured"
                self.sessionConfigured = true

            case "response.created":
                title = "Response Started"
                details = "Gerald is speaking"

            case "response.function_call_arguments.done":
                 title = "Function Args Done"
                 details = "Arguments parsed"
                 // Trigger tool call here as per user request
                 if let callId = message.call_id, let name = message.name, let args = message.arguments {
                     let toolCall = VoiceMessage.ToolCall(
                         id: callId,
                         type: "function",
                         function: VoiceMessage.FunctionCall(name: name, arguments: args)
                     )
                     self.handleToolCall(toolCall)
                     details = "Tool Executing: \(name)"
                 }
                
            case "response.output_item.added":
               title = "Output Item Added"
               details = "Processing new item"
               // Also keep this in case XAI sends it this way too
               if let item = message.item, let toolCalls = item.tool_calls {
                   for toolCall in toolCalls {
                       self.handleToolCall(toolCall)
                   }
                   details = "Tool calls handled: \(toolCalls.count)"
               }

            case "response.done":
                title = "Response Complete"
                details = "Turn finished"
                
                // Check for tool calls in the completed response
                if let output = message.response?.output {
                    for item in output {
                        if let toolCalls = item.tool_calls {
                            for toolCall in toolCalls {
                                self.handleToolCall(toolCall)
                            }
                        }
                    }
                }

            case "input_audio_buffer.speech_started":
                title = "Speech Detected"
                details = "User started speaking"

            case "input_audio_buffer.speech_stopped":
                title = "Speech Ended"
                details = "User stopped speaking"

            case "input_audio_buffer.committed":
                title = "Audio Committed"
                details = "Audio sent for processing"

            case "response.output_audio.delta":
                if let delta = message.delta, let audioData = Data(base64Encoded: delta) {
                    self.audioStreamer.playAudio(audioData) 
                    self.isGeraldSpeaking = true
                }
                title = "Audio Chunk"
                details = "Gerald speaking (\(message.delta?.count ?? 0) chars)"

            case "error":
                title = "XAI Error"
                details = message.text ?? "Unknown error"
                self.logMessage(.error, .received, title, details)
                return

            default:
                title = message.type
                if let text = message.text {
                    details = text
                } else if let audio = message.audio {
                    details = "Audio data (\(audio.count) chars)"
                }
            }

            self.logMessage(.websocket, .received, title, details)
        }
    }

    // MARK: - AudioStreamerDelegate

    func audioStreamerDidReceiveAudioData(_ data: Data) {
        // Send to XAI
        do {
            try xaiService?.sendAudioChunk(data)
            // Log occasionally
            if arc4random_uniform(50) == 0 {
               DispatchQueue.main.async {
                   self.logMessage(.audio, .sent, "Audio chunk sent", "\(data.count) bytes")
               }
            }
        } catch {
            print("Failed to send audio chunk: \(error)")
        }
    }
    
    func audioStreamerDidDetectSpeechStart() {
        DispatchQueue.main.async {
            self.logMessage(.audio, .system, "🎤 Speech detected", "Streaming to XAI")
        }
    }
    
    func audioStreamerDidDetectSpeechEnd() {
        DispatchQueue.main.async {
            self.logMessage(.audio, .system, "🤫 Speech ended", "Committing audio")
            try? self.xaiService?.commitAudioBuffer()
        }
    }

    internal func logMessage(_ type: MessageType, _ direction: MessageDirection, _ title: String, _ details: String) {
        let message = DebugMessage(
            timestamp: Date(),
            type: type,
            direction: direction,
            title: title,
            details: details
        )
        DispatchQueue.main.async {
            self.messageLog.append(message)

            // Keep only last 100 messages
            if self.messageLog.count > 100 {
                self.messageLog.removeFirst()
            }
        }
        // Debug print to console
        print("\(message.directionArrow) \(title): \(details)")
    }
}

// MARK: - ViewModel Extensions for Tools

extension VoiceTestViewModel {
    func handleToolCall(_ toolCall: VoiceMessage.ToolCall) {
        logMessage(.system, .received, "Tool Call", "\(toolCall.function.name)")
        
        let functionName = toolCall.function.name
        let arguments = toolCall.function.arguments
        
        if functionName == "create_tweet" {
            // Parse arguments for preview
            let previewTitle = "Post Tweet?"
            let previewContent = arguments
            
            self.pendingToolCall = PendingToolCall(
                id: toolCall.id,
                functionName: functionName,
                arguments: arguments,
                previewTitle: previewTitle,
                previewContent: previewContent
            )
        } else if let tool = XTool(rawValue: functionName) {
             if tool == .createLinearTicket {
                 self.pendingToolCall = PendingToolCall(
                    id: toolCall.id,
                    functionName: functionName,
                    arguments: arguments,
                    previewTitle: "Create Linear Ticket?",
                    previewContent: arguments
                )
             } else if tool == .searchRecentTweets || tool == .getUserByUsername {
                 // specific auto-run tools
                 executeTool(toolCall)
             } else {
                 // Default execute generic tools
                 executeTool(toolCall)
             }
        } else {
             // Fallback
             executeTool(toolCall)
        }
    }
    
    func approveToolCall() {
        guard let toolCall = pendingToolCall else { return }
        pendingToolCall = nil
        
        // Execute
        let voiceToolCall = VoiceMessage.ToolCall(id: toolCall.id, type: "function", function: VoiceMessage.FunctionCall(name: toolCall.functionName, arguments: toolCall.arguments))
        executeTool(voiceToolCall)
    }
    
    func rejectToolCall() {
        guard let toolCall = pendingToolCall else { return }
        
        // Send rejection output
        sendToolOutput(toolCallId: toolCall.id, output: "User denied this action.")
        pendingToolCall = nil
    }
    
    private func executeTool(_ toolCall: VoiceMessage.ToolCall) {
        Task {
            logMessage(.system, .system, "Executing Tool", toolCall.function.name)
            
            var output = ""
            
            if let tool = XTool(rawValue: toolCall.function.name) {
                if tool == .createLinearTicket {
                    // Linear Ticket Special Handling
                    print("TOOL CALL: Starting execution for call ID: \(toolCall.id)")
                    print("TOOL CALL: Raw arguments: \(toolCall.function.arguments)")
                    
                    // Hardcoded Team ID for "Personal" team as per plan
                    let teamId = "6d017e3c-0368-41b2-b439-95dd5477c54a"
                    print("TOOL CALL: Using Team ID: \(teamId)")
                    
                    // Parse arguments
                    if let data = toolCall.function.arguments.data(using: .utf8),
                       let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                       
                       print("TOOL CALL: Parsed JSON parameters: \(params)")
                       
                       if let title = params["title"] as? String,
                          let description = params["description"] as? String {
                        
                        print("TOOL CALL: Validated required fields. Title: '\(title)', Description length: \(description.count)")
                        
                        do {
                            print("TOOL CALL: Calling LinearAPIService.createIssue...")
                            let issue = try await self.linearService.createIssue(title: title, description: description, teamId: teamId)
                            print("TOOL CALL: Issue created successfully! ID: \(issue.id), Number: \(issue.number), URL: \(issue.url)")
                            
                            output = "{ \"status\": \"success\", \"ticket_id\": \"\(issue.number)\", \"url\": \"\(issue.url)\" }"
                            
                            await MainActor.run {
                                self.logMessage(.system, .sent, "Linear Ticket Created", "\(issue.number)")
                            }
                        } catch {
                            print("TOOL CALL: API Error: \(error)")
                            output = "{ \"status\": \"error\", \"message\": \"\(error.localizedDescription)\" }"
                            await MainActor.run {
                                self.logMessage(.error, .system, "Linear Ticket Failed", error.localizedDescription)
                            }
                        }
                       } else {
                           print("TOOL CALL: Missing required fields 'title' or 'description' in params: \(params.keys)")
                           output = "{ \"status\": \"error\", \"message\": \"Invalid arguments: Missing title or description\" }"
                       }
                    } else {
                         print("TOOL CALL: Failed to parse arguments JSON")
                         output = "{ \"status\": \"error\", \"message\": \"Invalid arguments JSON\" }"
                    }
                } else {
                    // Generic X Tool Handling
                    print("TOOL CALL: Processing generic tool call: \(tool.rawValue)")
                    print("TOOL CALL: Raw arguments: \(toolCall.function.arguments)")
                    
                    // Parse args
                    if let data = toolCall.function.arguments.data(using: .utf8),
                       let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        
                        print("TOOL CALL: Execute \(tool.rawValue) with params: \(params)")
                        
                        let orchestrator = XToolOrchestrator()
                        let result = await orchestrator.executeTool(tool, parameters: params)
                        
                        if result.success {
                            output = result.response ?? "{}"
                            print("TOOL CALL: Success! Output length: \(output.count)")
                            print("TOOL CALL: Output (truncated): \(output.prefix(200))...")
                        } else {
                            let errorMsg = result.error?.message ?? "Unknown Error"
                            output = "{ \"error\": \"\(errorMsg)\" }"
                            print("TOOL CALL: Failed! Error: \(errorMsg)")
                        }
                    } else {
                        print("TOOL CALL: Failed to parse params for \(tool.rawValue)")
                        output = "{ \"error\": \"Invalid arguments\" }"
                    }
                }
            } else {
                print("TOOL CALL: Unknown tool requested: \(toolCall.function.name)")
                output = "{ \"error\": \"Unknown tool\" }"
            }
            
            sendToolOutput(toolCallId: toolCall.id, output: output)
        }
    }
    
    private func sendToolOutput(toolCallId: String, output: String) {
        let message = VoiceMessage(
            type: "conversation.item.create",
            audio: nil,
            text: nil,
            delta: nil,
            session: nil,
            item: VoiceMessage.ConversationItem(
                id: nil,
                object: nil,
                type: "function_call_output",
                status: nil,
                role: "system", // or tool?
                content: nil, // output is top-level now
                tool_calls: nil,
                call_id: toolCallId,
                output: output
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
            start_time: nil,
            timestamp: nil,
            part: nil,
            response: nil,
            conversation: nil
        )
        
        do {
            try xaiService?.sendMessage(message)
            try xaiService?.createResponse()
            logMessage(.system, .sent, "Tool Output Sent", "\(output.count) chars")
        } catch {
            logMessage(.error, .system, "Failed to send tool output", error.localizedDescription)
        }
    }
}

extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
