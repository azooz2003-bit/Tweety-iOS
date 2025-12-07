//
//  VoiceTestView.swift
//  GrokMode
//
//  Created by Elon Musk's AI Assistant on 12/7/25.
//

import SwiftUI
import AVFoundation
import Combine


struct VoiceTestView: View {
    @StateObject private var viewModel = VoiceTestViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    Text("🎙️ XAI Voice Test")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // Permission Section
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
                    
                    // Connection Section
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
                    
                    // Message Log
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
                    
                    Spacer()
                }
                .padding()
                .onAppear {
                    viewModel.checkPermissions()
                }
            }
            .navigationViewStyle(.stack)
        }
    }
}

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

class VoiceTestViewModel: NSObject, ObservableObject {
    // Permissions
    @Published var micPermissionGranted = false
    @Published var micPermissionStatus = "Checking..."

    // Connection
    @Published var connectionState: ConnectionState = .disconnected
    @Published var isConnecting = false
    @Published var sessionConfigured = false
    @Published var lastActivity: Date?
    @Published var isAudioStreaming = false


    // Audio streaming
    @Published var isGeraldSpeaking = false
    @Published var messageLog: [DebugMessage] = []


    // Audio playback properties removed (audioQueue, currentAudioPlayer)


    // XAI Service
    private var xaiService: XAIVoiceService?

    override init() {
        super.init()
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

        logMessage(.system, .system, "Starting XAI connection", "")

        // Initialize XAI service
        xaiService = XAIVoiceService(apiKey: "xai-6ab6MBdEeM26TVCX17g11UGQDT34sA0b5CBff0f9leY23WXzUeQWugxZB0ukgolPllZkXKVsD6VPd8lQ")

        // Initialize audio streamer
        // setupAudioSessionForPlayback is called below, but we can call it here or rely on the engine setup
        
        // Setup audio session for playback/recording
        setupAudioSessionForPlayback()
        
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
                try await xaiService!.connect()

                // Configure session with Gerald McGrokMode personality
                try xaiService!.configureSantaSession()

                await MainActor.run {
                    logMessage(.system, .system, "Session configured for Gerald McGrokMode", "")
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
        stopAudioStreaming()

        // Stop engine and player
        playerNode?.stop()
        audioEngine?.stop()
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

    private func setupAudioSessionForPlayback() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setPreferredSampleRate(24000)
            try audioSession.setActive(true)
            print("✅ Audio session configured for speaking")
            
            // Setup Engine
            setupAudioEngine()
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        guard let engine = audioEngine, let player = playerNode else { return }
        
        engine.attach(player)
        
        // Standard format for internal processing (Float32), matching the sample rate
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)
        
        if let format = audioFormat {
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
        
        // Don't start engine here yet, wait for connection or streaming start
        print("✅ Audio engine initialized")
    }

    // MARK: - Audio Input (VAD & Streaming)
    
    // VAD Properties
    private var speechDetected = false
    private var silenceCounter = 0
    private let silenceThreshold: Float = -25.0 // dB
    private let silenceDuration = 30 // frames
    
    private let xaiFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: 24000,
                                         channels: 1,
                                         interleaved: false)!
    
    func startAudioStreaming() {
        guard connectionState == .connected else {
            logMessage(.error, .system, "Cannot start audio streaming", "Not connected to XAI")
            return
        }
        
        guard let engine = audioEngine else { return }
        
        // Stop engine to install tap safely
        if engine.isRunning {
            engine.stop()
        }
        
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        print("🎙️ Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)ch")
        
        // Safety check to prevent crash
        if inputFormat.sampleRate == 0 || inputFormat.channelCount == 0 {
            logMessage(.error, .system, "Invalid input format", "Rate: \(inputFormat.sampleRate)")
            return
        }
        
        // Remove existing tap if any to be safe
        print("🎙️ Removing existing tap...")
        inputNode.removeTap(onBus: 0)
        
        print("🎙️ Installing tap with format: \(inputFormat)...")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
            // print("🎙️ Tap callback received buffer: \(buffer.frameLength)") // Very spammy, uncomment if desperate
            self?.processAudioBuffer(buffer)
        }
        print("✅ Tap installed.")
        
        do {
            print("🚀 Starting engine...")
            try engine.start()
            isAudioStreaming = true
            logMessage(.system, .system, "Audio streaming started", "Listening for voice input")
            print("✅ Engine started successfully.")
        } catch {
            logMessage(.error, .system, "Failed to start engine for input", error.localizedDescription)
            print("❌ Engine start failed: \(error)")
        }
    }

    func stopAudioStreaming() {
        guard let engine = audioEngine else { return }
        engine.inputNode.removeTap(onBus: 0)
        
        isAudioStreaming = false
        speechDetected = false
        silenceCounter = 0
        logMessage(.system, .system, "Audio streaming stopped", "")
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert to XAI format (24kHz, 16-bit PCM, mono)
        guard let convertedBuffer = convertToXAIFormat(buffer) else {
            print("⚠️ Conversion failed for buffer frameLength: \(buffer.frameLength)")
            return
        }

        // Simple VAD
        let rms = calculateRMS(convertedBuffer)
        
        // Debug rare print
        if arc4random_uniform(100) == 0 {
            print("📊 RMS: \(rms) dB")
        }

        if rms > silenceThreshold && !speechDetected {
            // Speech started
            speechDetected = true
            silenceCounter = 0
            DispatchQueue.main.async {
                self.logMessage(.audio, .system, "🎤 Speech detected", "Streaming to XAI")
                print("🎤 Speech started (RMS: \(rms))")
            }
        } else if rms <= silenceThreshold && speechDetected {
            // Potential silence
            silenceCounter += 1
            if silenceCounter >= silenceDuration {
                // Speech ended
                speechDetected = false
                silenceCounter = 0
                
                DispatchQueue.main.async {
                    self.logMessage(.audio, .system, "🤫 Speech ended", "Committing audio")
                    try? self.xaiService?.commitAudioBuffer()
                    print("🤫 Speech ended. Committed.")
                }
            }
        } else if speechDetected {
            // Reset silence counter during speech
            silenceCounter = 0
        }

        // Send audio data if speech is detected
        if speechDetected {
            guard let channelData = convertedBuffer.int16ChannelData?[0] else { return }
            let frameCount = Int(convertedBuffer.frameLength)
            let audioData = Data(bytes: channelData, count: frameCount * 2)
            
            do {
                try xaiService?.sendAudioChunk(audioData)
                // Log occasionally
                if arc4random_uniform(50) == 0 {
                   DispatchQueue.main.async {
                       self.logMessage(.audio, .sent, "Audio chunk sent", "\(audioData.count) bytes")
                   }
                }
            } catch {
                print("Failed to send audio chunk: \(error)")
            }
        }
    }

    private func convertToXAIFormat(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // Create converter if needed (creating every time is inefficient but robust for changing formats)
        // Ideally cache this if formats match
        guard let converter = AVAudioConverter(from: buffer.format, to: xaiFormat) else {
            print("❌ Could not create audio converter from \(buffer.format) to \(xaiFormat)")
            return nil
        }
        
        let frameCount = AVAudioFrameCount(buffer.frameLength)
        let ratio = xaiFormat.sampleRate / buffer.format.sampleRate
        let targetFrameCount = AVAudioFrameCount(Double(frameCount) * ratio) + 100 // buffer
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: xaiFormat, frameCapacity: targetFrameCount) else {
            print("❌ Could not create output buffer")
            return nil
        }
        
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        if status == .error || error != nil {
            print("❌ Conversion error: \(error?.localizedDescription ?? "unknown")")
            return nil
        }
        
        return outputBuffer
    }
    
    private func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.int16ChannelData?[0] else { return -100 }
        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameCount {
            let sample = Float(channelData[i]) / 32768.0
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameCount))
        return 20 * log10(max(rms, .leastNonzeroMagnitude))
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

            case "response.done":
                title = "Response Complete"
                details = "Gerald finished speaking"

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
                if let delta = message.delta {
                    self.playGeraldAudio(delta: delta) // Actually play Gerald's voice!
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

    // MARK: - Audio Playback (AVAudioEngine)

    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?



    private func playGeraldAudio(delta: String) {
        guard let pcmData = Data(base64Encoded: delta) else {
            print("❌ Failed to decode Gerald audio data")
            return
        }

        // We need to convert the Int16 data into a Float32 buffer for the engine
        guard let buffer = convertToAudioBuffer(pcmData) else {
            print("❌ Failed to create audio buffer")
            return
        }

        guard let player = playerNode, let engine = audioEngine else { return }

        // Ensure engine is running
        if !engine.isRunning {
             try? engine.start()
        }

        player.scheduleBuffer(buffer, at: nil, options: []) {
            // Chunk finished playing
            DispatchQueue.main.async {
               // Optional: Update UI if needed (careful with high freq updates)
            }
        }
        
        if !player.isPlaying {
            player.play()
            DispatchQueue.main.async {
                self.isGeraldSpeaking = true
            }
        }
    }
    
    private func convertToAudioBuffer(_ data: Data) -> AVAudioPCMBuffer? {
        guard let format = audioFormat else { return nil }
        
        // Data is Int16 (2 bytes per sample)
        let frameCount = AVAudioFrameCount(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        
        buffer.frameLength = frameCount
        
        guard let channelData = buffer.floatChannelData else { return nil }
        let channel0 = channelData[0]
        
        // Copy Int16 data to temporary array
        let int16Count = data.count / 2
        var int16Samples = [Int16](repeating: 0, count: int16Count)
        _ = int16Samples.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        
        // Convert to Float [-1.0, 1.0]
        // Note: XAI might be sending raw PCM, normal divisor is 32768.0
        for i in 0..<int16Count {
             channel0[i] = Float(int16Samples[i]) / 32768.0
        }
        
        return buffer
    }



    private func logMessage(_ type: MessageType, _ direction: MessageDirection, _ title: String, _ details: String) {
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

enum ConnectionState {
    case disconnected, connecting, connected, error
}

// MARK: - Extensions

extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}

