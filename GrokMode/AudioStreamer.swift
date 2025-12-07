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
}

class AudioStreamer: NSObject {
    weak var delegate: AudioStreamerDelegate?

    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioFormat: AVAudioFormat!

    private var isStreaming = false
    private var speechDetected = false
    private var silenceCounter = 0
    private let silenceThreshold: Float = -25.0 // dB
    private let silenceDuration = 30 // frames (~1.5 seconds at 20ms per frame)

    // XAI audio format: 24kHz, 16-bit PCM, mono
    private let xaiSampleRate: Double = 24000
    private let xaiFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: 24000,
                                         channels: 1,
                                         interleaved: false)!

    override init() {
        super.init()
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode

        // Use the XAI format for consistency
        audioFormat = xaiFormat

        
        //
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setPrefersEchoCancelledInput(true)
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers])
            try audioSession.setActive(true)
            try audioSession.setPreferredSampleRate(xaiSampleRate)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }

    func startStreaming() {
        guard !isStreaming else { return }

        print("🎙️ Starting audio streaming to XAI...")

        let inputFormat = inputNode.inputFormat(forBus: 0)
        print("🎙️ Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")

        // Install a tap on the input node to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
            self?.processAudioBuffer(buffer)
        }

        do {
            try audioEngine.start()
            isStreaming = true
            print("✅ Audio streaming started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }

    func stopStreaming() {
        guard isStreaming else { return }

        print("🛑 Stopping audio streaming...")

        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        isStreaming = false
        speechDetected = false
        silenceCounter = 0

        print("✅ Audio streaming stopped")
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Convert to XAI format (24kHz, 16-bit PCM, mono)
        guard let convertedBuffer = convertToXAIFormat(buffer) else {
            print("❌ Failed to convert audio buffer")
            return
        }

        // Simple VAD (Voice Activity Detection)
        let rms = calculateRMS(convertedBuffer)

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
            let channelData = convertedBuffer.int16ChannelData![0]

            let audioData = Data(bytes: channelData, count: frameCount * 2) // 16-bit = 2 bytes per sample
            delegate?.audioStreamerDidReceiveAudioData(audioData)
        }
    }

    private func convertToXAIFormat(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        // Convert to XAI format: 24kHz, mono, 16-bit PCM
        let converter = AVAudioConverter(from: buffer.format, to: xaiFormat)!

        let frameCount = AVAudioFrameCount(buffer.frameLength)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: xaiFormat, frameCapacity: frameCount) else {
            return nil
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error {
            print("❌ Audio conversion failed: \(error?.localizedDescription ?? "Unknown error")")
            return nil
        }

        outputBuffer.frameLength = AVAudioFrameCount(frameCount)
        return outputBuffer
    }

    private func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.int16ChannelData?[0] else { return -100 }

        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0

        for i in 0..<frameCount {
            let sample = Float(channelData[i]) / 32768.0 // Normalize to -1...1
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameCount))
        let db = 20 * log10(max(rms, .leastNonzeroMagnitude))

        return db
    }
}
