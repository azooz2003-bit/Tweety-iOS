//
//  AudioStreamer.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import AVFoundation
import Foundation
import OSLog

protocol AudioStreamerDelegate: AnyObject {
    func audioStreamerDidReceiveAudioData(_ data: Data)
    func audioStreamerDidDetectSpeechStart()
    func audioStreamerDidDetectSpeechEnd()
    func audioStreamerDidUpdateAudioLevel(_ level: Float)
}

class AudioStreamer: NSObject {
    weak var delegate: AudioStreamerDelegate?

    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var playerNode: AVAudioPlayerNode
    private var audioFormat: AVAudioFormat
    private var mixerNode: AVAudioMixerNode

    private var isStreaming = false
    private var speechDetected = false
    private var silenceCounter = 0
    private let silenceThreshold: Float = -25.0 // dB
    private let silenceDuration = 30 // frames (~1.5 seconds at 20ms per frame)

    // XAI audio format: 24kHz, 16-bit PCM, mono (fixed for Grok API)
    private static let xaiSampleRate: Double = 24000

    private static let xaiFormat: AVAudioFormat = {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: xaiSampleRate,
                                         channels: 1,
                                         interleaved: false) else {
            fatalError("Failed to create XAI audio format")
        }
        return format
    }()

    // Hardware format - determined at runtime after voice processing is enabled
    private let hardwareFormat: AVAudioFormat

    // MARK: Setup Audio Session

    static public func make() throws -> AudioStreamer {
        // STEP 1: Configure audio session for voice processing
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetoothHFP, .allowAirPlay])

        // DON'T set preferred sample rate - let voice processing choose the optimal rate
        try audioSession.setActive(true)
        os_log("✅ Audio session configured for voice processing")

        // STEP 2: Create and configure audio engine
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let playerNode = AVAudioPlayerNode()
        let mixerNode = audioEngine.mainMixerNode

        // STEP 3: Enable Voice Processing BEFORE querying format
        try inputNode.setVoiceProcessingEnabled(true)
        os_log("✅ Voice Processing (AEC) enabled")

        // STEP 4: Query the actual hardware format chosen by voice processing
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        os_log("📊 Hardware format (chosen by Voice Processing):")
        os_log("   Sample rate: \(hardwareFormat.sampleRate)Hz")
        os_log("   Channels: \(hardwareFormat.channelCount)")
        os_log("   Format: \(hardwareFormat.commonFormat.rawValue)")
        os_log("📤 Will convert to XAI format: \(xaiSampleRate)Hz for Grok")

        // STEP 5: Attach and Connect Nodes
        audioEngine.attach(playerNode)

        // Connect player to mixer using hardware format for smooth playback
        audioEngine.connect(playerNode, to: mixerNode, format: hardwareFormat)
        os_log("✅ Audio nodes connected")

        return AudioStreamer(
            audioEngine: audioEngine,
            inputNode: inputNode,
            playerNode: playerNode,
            mixerNode: mixerNode,
            audioFormat: xaiFormat,
            hardwareFormat: hardwareFormat
        )
    }

    init(
        audioEngine: AVAudioEngine,
        inputNode: AVAudioInputNode,
        playerNode: AVAudioPlayerNode,
        mixerNode: AVAudioMixerNode,
        audioFormat: AVAudioFormat,
        hardwareFormat: AVAudioFormat
    ) {
        self.audioEngine = audioEngine
        self.inputNode = inputNode
        self.playerNode = playerNode
        self.mixerNode = mixerNode
        self.audioFormat = audioFormat
        self.hardwareFormat = hardwareFormat

        super.init()
    }

    // MARK: Audio Actions

    func startStreaming() throws {
        guard !isStreaming else { return }

        os_log("🎙️ Starting audio streaming to XAI...")

        let inputFormat = inputNode.inputFormat(forBus: 0)
        os_log("🎙️ Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")

        // Install a tap on the input node to capture audio
        // Note: VoiceProcessingIO might force a specific format (usually 48kHz or 24kHz), we must handle it.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
            do {
                try self?.processAudioBuffer(buffer)
            } catch {
                os_log("Processing incoming audio buffer from microphone failed.")
            }
        }

        if !audioEngine.isRunning {
            try audioEngine.start()
        }
        playerNode.play() // Start the player node so it's ready to handle scheduled buffers
        isStreaming = true
    }

    func stopStreaming() {
        guard isStreaming else { return }

        // Don't fully stop the engine if we want to keep playing clean tails, but typically we stop.
        // For full session end:
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        playerNode.stop()
        
        isStreaming = false
        speechDetected = false
        silenceCounter = 0

        os_log("✅ Audio streaming stopped")
    }
    
    // Playback Function
    func stopPlayback() {
        if playerNode.isPlaying {
            playerNode.stop()
        }
        os_log("🛑 Playback interrupted by user")
    }

    func playAudio(_ data: Data) throws {
        // Convert the incoming Data (PCM16) to a playable buffer
        let buffer = try convertDataToBuffer(data)

        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        
        if !playerNode.isPlaying {
            playerNode.play()
        }
        
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
    
    private func convertDataToBuffer(_ data: Data) throws -> AVAudioPCMBuffer {
        // Incoming data is 24kHz Int16 from Grok
        let frameCount = UInt32(data.count / 2)

        // Step 1: Create a 24kHz Float32 buffer
        guard let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: Self.xaiSampleRate, channels: 1),
              let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw AudioError.convertToiOSPlaybackFormatFailed
        }

        sourceBuffer.frameLength = frameCount

        guard let floatChannelData = sourceBuffer.floatChannelData?[0] else {
            throw AudioError.convertToiOSPlaybackFormatFailed
        }

        // Convert Int16 to Float32
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            if let int16Bytes = bytes.bindMemory(to: Int16.self).baseAddress {
                for i in 0..<Int(frameCount) {
                    floatChannelData[i] = Float(int16Bytes[i]) / 32768.0
                }
            }
        }

        // Step 2: Resample from 24kHz to hardware format (if needed)
        if sourceFormat.sampleRate == hardwareFormat.sampleRate {
            return sourceBuffer
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: hardwareFormat) else {
            throw AudioError.convertToiOSPlaybackFormatFailed
        }

        let ratio = hardwareFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(frameCount) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: hardwareFormat, frameCapacity: outputFrameCount) else {
            throw AudioError.convertToiOSPlaybackFormatFailed
        }

        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let error = error {
            throw AudioError.convertToiOSPlaybackFormatFailed
        }

        outputBuffer.frameLength = outputFrameCount
        return outputBuffer
    }

    // MARK: Helpers

    /// Processes input audio
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) throws {
        // Convert to XAI format (24kHz, 16-bit PCM, mono)
        let convertedBuffer = try convertToXAIFormat(buffer)

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
            os_log("🎤 Speech detected (RMS: \(String(format: "%.1f", rms)) dB)")
        } else if rms <= silenceThreshold && speechDetected {
            // Potential silence
            silenceCounter += 1
            if silenceCounter >= silenceDuration {
                // Speech ended
                speechDetected = false
                silenceCounter = 0
                delegate?.audioStreamerDidDetectSpeechEnd()
                os_log("🤫 Speech ended (silence detected)")
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

    enum AudioError: Error {
        case convertToxAiFormatFailed, convertToiOSPlaybackFormatFailed
    }

    private func convertToXAIFormat(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        // Optimization: If format already matches, return as is
        if buffer.format == Self.xaiFormat { return buffer }

        // Convert to XAI format: 24kHz, mono, 16-bit PCM
        let converter = AVAudioConverter(from: buffer.format, to: Self.xaiFormat)

        // Adjust frame length of input buffer to follow xAI's sample rate
        let ratio = Self.xaiFormat.sampleRate / buffer.format.sampleRate
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: Self.xaiFormat, frameCapacity: frameCount) else {
            throw AudioError.convertToxAiFormatFailed
        }

        var error: NSError?
        let status = converter?.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error || error != nil {
            throw AudioError.convertToxAiFormatFailed
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
