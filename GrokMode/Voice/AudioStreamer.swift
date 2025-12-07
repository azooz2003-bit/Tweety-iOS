//
//  AudioStreamer.swift
//  GrokMode
//
//  Created by Elon Musk's AI Assistant on 12/7/25.
//

import AVFoundation
import Foundation

protocol AudioStreamerDelegate: AnyObject {
    func audioStreamerDidReceiveAudioData(_ data: Data)
    func audioStreamerDidDetectSpeechStart()
    func audioStreamerDidDetectSpeechEnd()
    func audioStreamerDidUpdateAudioLevel(_ level: Float)
}

class AudioStreamer: NSObject {
    weak var delegate: AudioStreamerDelegate?

    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var playerNode: AVAudioPlayerNode!
    private var audioFormat: AVAudioFormat!
    private var mixerNode: AVAudioMixerNode!

    private var isStreaming = false
    private var speechDetected = false
    private var silenceCounter = 0
    private let silenceThreshold: Float = -25.0 // dB
    private let silenceDuration = 30 // frames (~1.5 seconds at 20ms per frame)

    // XAI audio format: 24kHz, 16-bit PCM, mono
    private let xaiSampleRate: Double = 24000

    // Lazy initialization to ensure formats are created after audio session is configured
    private lazy var xaiFormat: AVAudioFormat = {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: xaiSampleRate,
                                         channels: 1,
                                         interleaved: false) else {
            fatalError("Failed to create XAI audio format with sample rate: \(xaiSampleRate)")
        }
        return format
    }()

    // Internal processing format (usually standard Float32)
    private lazy var processingFormat: AVAudioFormat = {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: xaiSampleRate, channels: 1) else {
            fatalError("Failed to create processing audio format with sample rate: \(xaiSampleRate)")
        }
        return format
    }()

    override init() {
        super.init()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        // STEP 1: Set up audio session FIRST (before anything else)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use .videoChat or .spokenAudio. .videoChat often behaves better for speakerphone AEC than .voiceChat
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])

            // Set preferred sample rate and validate it
            try audioSession.setPreferredSampleRate(xaiSampleRate)
            let actualSampleRate = audioSession.sampleRate
            print("✅ Audio session configured")
            print("   Preferred sample rate: \(xaiSampleRate)Hz")
            print("   Actual sample rate: \(actualSampleRate)Hz")

            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
            print("   This may cause audio format issues")
        }

        // STEP 2: Create and configure audio engine
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        playerNode = AVAudioPlayerNode()
        mixerNode = audioEngine.mainMixerNode

        // STEP 3: Attach and Connect Nodes
        // We use the playerNode for playing back the AI's voice
        audioEngine.attach(playerNode)

        // Connect player -> Mixer -> Output
        // Use processingFormat (Float32) to ensure matching format for scheduling
        // Access processingFormat here to trigger lazy initialization
        let connectedFormat = processingFormat
        print("   Connecting player with format: \(connectedFormat.sampleRate)Hz, \(connectedFormat.channelCount) channels")
        audioEngine.connect(playerNode, to: mixerNode, format: connectedFormat)

        // Use the XAI format for consistency reference (trigger lazy initialization)
        audioFormat = xaiFormat
        print("   XAI format: \(audioFormat.sampleRate)Hz, \(audioFormat.channelCount) channels")

        // STEP 4: Enable Voice Processing (AEC) on Input Node - AFTER session is configured
        do {
            try inputNode.setVoiceProcessingEnabled(true)
            print("✅ Voice Processing (AEC) enabled on input node")
        } catch {
            print("❌ Failed to enable Voice Processing: \(error)")
        }
    }

    func startStreaming() {
        guard !isStreaming else { return }

        print("🎙️ Starting audio streaming to XAI...")

        let inputFormat = inputNode.inputFormat(forBus: 0)
        print("🎙️ Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")

        // Install a tap on the input node to capture audio
        // Note: VoiceProcessingIO might force a specific format (usually 48kHz or 24kHz), we must handle it.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer)
        }

        do {
            if !audioEngine.isRunning {
                try audioEngine.start()
            }
            playerNode.play() // Start the player node so it's ready to handle scheduled buffers
            isStreaming = true
            print("✅ Audio streaming started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }

    func stopStreaming() {
        guard isStreaming else { return }

        print("🛑 Stopping audio streaming...")

        // Don't fully stop the engine if we want to keep playing clean tails, but typically we stop.
        // For full session end:
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        playerNode.stop()
        
        isStreaming = false
        speechDetected = false
        silenceCounter = 0

        print("✅ Audio streaming stopped")
    }
    
    // Playback Function
    func stopPlayback() {
        if playerNode.isPlaying {
            playerNode.stop()
        }
        print("🛑 Playback interrupted by user")
    }

    func playAudio(_ data: Data) {
        // Convert the incoming Data (PCM16) to a playable buffer
        guard let buffer = convertDataToBuffer(data) else {
            print("❌ Failed to create buffer for playback")
            return
        }
        
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        
        if !playerNode.isPlaying {
            playerNode.play()
        }
        
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
    
    private func convertDataToBuffer(_ data: Data) -> AVAudioPCMBuffer? {
        // Data is Int16 (2 bytes per sample) 24kHz Mono
        let frameCount = UInt32(data.count / 2)
        
        // Use processingFormat (Float32) for playback
        guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else { return nil }
        
        buffer.frameLength = frameCount
        
        guard let floatChannelData = buffer.floatChannelData?[0] else { return nil }
        
        // Convert Int16 to Float32
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            if let int16Bytes = bytes.bindMemory(to: Int16.self).baseAddress {
                for i in 0..<Int(frameCount) {
                    // Normalize Int16 to Float [-1.0, 1.0]
                    floatChannelData[i] = Float(int16Bytes[i]) / 32768.0
                }
            }
        }
        
        return buffer
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert to XAI format (24kHz, 16-bit PCM, mono)
        guard let convertedBuffer = convertToXAIFormat(buffer) else {
            // print("❌ Failed to convert audio buffer") // Can be spammy
            return
        }

        // Simple VAD (Voice Activity Detection)
        let rms = calculateRMS(convertedBuffer)

        // Normalize RMS from dB (-100 to 0) to 0.0 to 1.0 for waveform
        // Typical speech is around -30 to -10 dB
        let normalizedLevel = max(0, min(1, (rms + 50) / 50)) // Map -50dB to 0dB -> 0.0 to 1.0
        delegate?.audioStreamerDidUpdateAudioLevel(normalizedLevel)

        if rms > silenceThreshold && !speechDetected {
            // Speech started
            speechDetected = true
            silenceCounter = 0
            delegate?.audioStreamerDidDetectSpeechStart()
            print("🎤 Speech detected (RMS: \(String(format: "%.1f", rms)) dB)")
        } else if rms <= silenceThreshold && speechDetected {
            // Potential silence
            silenceCounter += 1
            if silenceCounter >= silenceDuration {
                // Speech ended
                speechDetected = false
                silenceCounter = 0
                delegate?.audioStreamerDidDetectSpeechEnd()
                print("🤫 Speech ended (silence detected)")
            }
        } else if speechDetected {
            // Reset silence counter during speech
            silenceCounter = 0
        }

        // Send audio data if speech is detected
        if speechDetected {
            // Convert buffer to Data
            let frameCount = Int(convertedBuffer.frameLength)
            if let channelData = convertedBuffer.int16ChannelData?[0] {
                let audioData = Data(bytes: channelData, count: frameCount * 2) // 16-bit = 2 bytes per sample
                delegate?.audioStreamerDidReceiveAudioData(audioData)
            }
        }
    }

    private func convertToXAIFormat(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // Optimization: If format already matches, return as is
        if buffer.format == xaiFormat { return buffer }
        
        // Convert to XAI format: 24kHz, mono, 16-bit PCM
        let converter = AVAudioConverter(from: buffer.format, to: xaiFormat)
        
        let ratio = xaiFormat.sampleRate / buffer.format.sampleRate
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: xaiFormat, frameCapacity: frameCount) else {
            return nil
        }

        var error: NSError?
        let status = converter?.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error {
            // print("❌ Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")")
            return nil
        }

        outputBuffer.frameLength = frameCount
        return outputBuffer
    }

    private func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.int16ChannelData?[0] else { return -100 }

        let frameCount = Int(buffer.frameLength)
        if frameCount == 0 { return -100 }
        
        var sum: Float = 0

        // vDSP could be faster, but simple loop is fine for small buffers
        for i in 0..<frameCount {
            let sample = Float(channelData[i]) / 32768.0 // Normalize to -1...1
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameCount))
        let db = 20 * log10(max(rms, .leastNonzeroMagnitude))

        return db
    }
}
