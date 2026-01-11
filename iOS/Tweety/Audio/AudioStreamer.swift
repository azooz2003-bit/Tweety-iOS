//
//  AudioStreamer.swift
//  Tweety
//
//  Created by Matt Steele on 12/7/25.
//

import AVFoundation
import Foundation
import OSLog
import Speech

protocol AudioStreamerDelegate: AnyObject {
    func audioStreamerDidReceiveAudioData(_ data: Data)
    func audioStreamerDidDetectSpeechStart()
    func audioStreamerDidDetectSpeechEnd()
    func audioStreamerDidUpdateAudioLevel(_ level: Float)
}

class AudioStreamer: NSObject {
    enum AudioError: Error {
        case convertToxAiFormatFailed, convertToiOSPlaybackFormatFailed
    }
    
    weak var delegate: AudioStreamerDelegate?

    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode
    private var playerNode: AVAudioPlayerNode
    private var serverAudioFormat: AVAudioFormat
    private var mixerNode: AVAudioMixerNode

    // Hardware format - determined at runtime after voice processing is enabled
    private let hardwareFormat: AVAudioFormat

    // Serial queue for all audio operations to keep them off main thread
    private let audioQueue = DispatchQueue(label: "com.tweety.audiostreamer", qos: .userInitiated)

    private var hasTapInstalled = false

    private let speechVAD: SpeechVAD

    /// Tracks if user is currently speaking (linked to Speech VAD)
    var speechDetected: Bool {
        speechVAD.isSpeaking
    }

    /// Computed property that reflects actual streaming state
    /// Returns true when input tap is installed AND audio engine is running
    var isStreaming: Bool {
        hasTapInstalled && audioEngine.isRunning
    }

    // XAI audio format: 24kHz, 16-bit PCM, mono (fixed for Grok API)
    var serverSampleRate: Double {
        serverAudioFormat.sampleRate
    }


    // MARK: Setup Audio Session

    @concurrent
    static public func make(xaiSampleRate: Double = 24000) async throws -> AudioStreamer {
        let xaiFormat: AVAudioFormat = {
            guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                             sampleRate: xaiSampleRate,
                                             channels: 1,
                                             interleaved: false) else {
                fatalError("Failed to create XAI audio format")
            }
            return format
        }()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetoothHFP, .allowAirPlay])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        AppLogger.audio.info("Audio session configured for voice processing")

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let playerNode = AVAudioPlayerNode()
        let mixerNode = audioEngine.mainMixerNode

        try inputNode.setVoiceProcessingEnabled(true)
        AppLogger.audio.info("Voice Processing (AEC) enabled")

        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        #if DEBUG
        AppLogger.audio.debug("Hardware format (chosen by Voice Processing):")
        AppLogger.audio.debug("   Sample rate: \(hardwareFormat.sampleRate)Hz")
        AppLogger.audio.debug("   Channels: \(hardwareFormat.channelCount)")
        AppLogger.audio.debug("   Format: \(hardwareFormat.commonFormat.rawValue)")
        AppLogger.audio.debug("Will convert to XAI format: \(xaiSampleRate)Hz for Grok")
        #endif

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: mixerNode, format: hardwareFormat)
        AppLogger.audio.info("Audio nodes connected with format: \(hardwareFormat.sampleRate)Hz")

        return await AudioStreamer(
            audioEngine: audioEngine,
            inputNode: inputNode,
            playerNode: playerNode,
            mixerNode: mixerNode,
                        serverAudioFormat: xaiFormat,
            hardwareFormat: hardwareFormat
        )
    }

    init(
        audioEngine: AVAudioEngine,
        inputNode: AVAudioInputNode,
        playerNode: AVAudioPlayerNode,
        mixerNode: AVAudioMixerNode,
                    serverAudioFormat: AVAudioFormat,
        hardwareFormat: AVAudioFormat
    ) {
        self.audioEngine = audioEngine
        self.inputNode = inputNode
        self.playerNode = playerNode
        self.mixerNode = mixerNode
        self.serverAudioFormat = serverAudioFormat
        self.hardwareFormat = hardwareFormat

        // Initialize Speech-based VAD
        self.speechVAD = SpeechVAD()

        super.init()

        // Set delegate after super.init
        self.speechVAD.delegate = self
    }

    // MARK: Audio Actions

    func startStreaming() throws {
        try audioQueue.sync {
            try startStreamingImpl()
        }
    }

    func startStreamingAsync(completion: @escaping (Error?) -> Void) {
        audioQueue.async { [weak self] in
            do {
                try self?.startStreamingImpl()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    private func startStreamingImpl() throws {
        guard !isStreaming else { return }

        AppLogger.audio.info("Starting audio streaming")

        let inputFormat = inputNode.inputFormat(forBus: 0)
        #if DEBUG
        AppLogger.audio.debug("Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")
        #endif

        speechVAD.startDetection()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
            do {
                try self?.processInputAudioBuffer(buffer)
            } catch {
                AppLogger.audio.error("Processing incoming audio buffer from microphone failed")
            }
        }

        if !audioEngine.isRunning {
            try audioEngine.start()
        }
        playerNode.play()
        hasTapInstalled = true
    }

    func stopStreaming() {
        audioQueue.async {
            self.speechVAD.stopDetection()

            guard self.isStreaming else { return }

            self.audioEngine.stop()
            self.inputNode.removeTap(onBus: 0)
            self.playerNode.stop()
            self.playerNode.reset()

            self.hasTapInstalled = false
        }

        AppLogger.audio.info("Audio streaming stopped")
    }
    
    // Playback Function
    func stopPlayback() {
        audioQueue.async {
            if self.playerNode.isPlaying {
                self.playerNode.stop()
                self.playerNode.reset()
            }
            AppLogger.audio.info("Playback interrupted by user")
        }
    }

    func playAudio(_ data: Data) throws {
        let buffer = try convertDataToBuffer(data)

        audioQueue.async {
            if !self.audioEngine.isRunning {
                try? self.audioEngine.start()
            }

            if !self.playerNode.isPlaying {
                self.playerNode.play()
            }

            self.playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }
    
    private func convertDataToBuffer(_ data: Data) throws -> AVAudioPCMBuffer {
        let frameCount = UInt32(data.count / 2)

        guard let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: self.serverSampleRate, channels: 1),
              let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw AudioError.convertToiOSPlaybackFormatFailed
        }

        sourceBuffer.frameLength = frameCount

        guard let floatChannelData = sourceBuffer.floatChannelData?[0] else {
            throw AudioError.convertToiOSPlaybackFormatFailed
        }

        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            if let int16Bytes = bytes.bindMemory(to: Int16.self).baseAddress {
                for i in 0..<Int(frameCount) {
                    floatChannelData[i] = Float(int16Bytes[i]) / 32768.0
                }
            }
        }

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

        if error != nil {
            throw AudioError.convertToiOSPlaybackFormatFailed
        }

        outputBuffer.frameLength = outputFrameCount
        return outputBuffer
    }

    // MARK: Helpers

    private func processInputAudioBuffer(_ buffer: AVAudioPCMBuffer) throws {
        speechVAD.appendAudioBuffer(buffer)

        let convertedBuffer = try convertToServerFormat(buffer)

        let rms = calculateRMS(convertedBuffer)
        let normalizedLevel = max(0, min(1, (rms + 50) / 50))
        delegate?.audioStreamerDidUpdateAudioLevel(normalizedLevel)

        if speechDetected {
            let frameCount = Int(convertedBuffer.frameLength)
            if let channelData = convertedBuffer.int16ChannelData?[0] {
                let audioData = Data(bytes: channelData, count: frameCount * 2)
                delegate?.audioStreamerDidReceiveAudioData(audioData)
            }
        }
    }

    private func convertToServerFormat(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        if buffer.format == self.serverAudioFormat { return buffer }

        let converter = AVAudioConverter(from: buffer.format, to: self.serverAudioFormat)

        let ratio = self.serverAudioFormat.sampleRate / buffer.format.sampleRate
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: self.serverAudioFormat, frameCapacity: frameCount) else {
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

// MARK: - SpeechVADDelegate

extension AudioStreamer: SpeechVADDelegate {
    func speechVADDidDetectSpeech() {
        delegate?.audioStreamerDidDetectSpeechStart()
    }

    func speechVADDidDetectSilence() {
        delegate?.audioStreamerDidDetectSpeechEnd()
    }
}
