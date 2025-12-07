//
//  VoicePerformer.swift
//  GrokMode
//
//  Created by Claude on 12/7/25.
//

import Foundation
import AVFoundation

// MARK: - Errors

enum VoicePerformerError: LocalizedError {
    case emptyScript
    case generationFailed(String)
    case apiError(Error)
    case audioProcessingFailed
    case cancelled
    case noVoiceAvailable

    var errorDescription: String? {
        switch self {
        case .emptyScript:
            return "Script contains no segments to perform"
        case .generationFailed(let reason):
            return "Failed to generate voice performance: \(reason)"
        case .apiError(let error):
            return "API error: \(error.localizedDescription)"
        case .audioProcessingFailed:
            return "Failed to process audio data"
        case .cancelled:
            return "Performance generation was cancelled"
        case .noVoiceAvailable:
            return "No suitable voice found for character"
        }
    }
}

// MARK: - Voice Performer

/// Converts manga scripts into voice performances using Grok TTS API
class VoicePerformer {
    private let ttsEndpoint = URL(string: "https://api.x.ai/v1/audio/speech")!

    private var currentTask: Task<AudioPerformance, Error>?

    // Voice options from xAI API
    enum Voice: String, CaseIterable {
        case ara = "Ara"    // Female - Warm, friendly, balanced
        case rex = "Rex"    // Male - Confident, clear, professional
        case sal = "Sal"    // Neutral - Smooth, balanced, versatile
        case eve = "Eve"    // Female - Energetic, upbeat, enthusiastic
        case una = "Una"    // Female - Calm, measured, soothing
        case leo = "Leo"    // Male - Authoritative, strong, commanding
    }

    init() {
        // API key loaded from APIConfig
    }

    func perform(_ script: MangaScript) async throws -> AudioPerformance {
        print("🎭 Starting voice performance generation...")

        guard !script.segments.isEmpty else {
            throw VoicePerformerError.emptyScript
        }

        // Cancel any existing task
        cancelPerformance()

        // Create and store the performance task
        let task = Task<AudioPerformance, Error> {
            try await generatePerformance(for: script)
        }
        currentTask = task

        return try await task.value
    }

    func cancelPerformance() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func generatePerformance(for script: MangaScript) async throws -> AudioPerformance {
        var audioFiles: [URL] = []
        var segmentTimings: [AudioPerformance.SegmentTiming] = []
        var currentTime: TimeInterval = 0.0

        print("📊 Generating audio for \(script.segments.count) segments...")

        for (index, segment) in script.segments.enumerated() {
            try Task.checkCancellation()

            print("  [\(index + 1)/\(script.segments.count)] \(segment.type.rawValue): \"\(segment.content.prefix(50))...\"")

            // Add pause before segment
            if let pauseBefore = segment.timing?.pauseBefore, pauseBefore > 0 {
                let silenceFile = try createSilenceFile(duration: pauseBefore)
                audioFiles.append(silenceFile)
                currentTime += pauseBefore
            }

            // Generate audio for this segment
            let startTime = currentTime
            let segmentAudioURL: URL

            switch segment.type {
            case .dialogue, .thought:
                // Use TTS for dialogue and thoughts
                let voice = selectVoice(for: segment.character, emotion: segment.emotion)
                let text = formatSegmentForTTS(segment)
                segmentAudioURL = try await generateTTS(text: text, voice: voice)

            case .narration:
                // Use calm, neutral voice for narration
                let text = segment.content
                segmentAudioURL = try await generateTTS(text: text, voice: .ara)

            case .soundEffect:
                // Generate short tone for sound effects (or skip)
                // For now, we'll use a short pause
                segmentAudioURL = try createSilenceFile(duration: 0.3)

            case .action:
                // Use subtle narration for actions
                let text = segment.content
                segmentAudioURL = try await generateTTS(text: text, voice: .sal)
            }

            let duration = try getAudioDuration(from: segmentAudioURL)
            audioFiles.append(segmentAudioURL)
            currentTime += duration

            segmentTimings.append(AudioPerformance.SegmentTiming(
                segmentId: segment.id,
                startTime: startTime,
                endTime: currentTime
            ))

            print("    ✓ Generated \(duration)s of audio")
        }

        // Concatenate all audio files using AVFoundation
        let combinedAudioURL = try await concatenateAudioFiles(audioFiles)

        print("✅ Voice performance generated: \(currentTime)s")

        return AudioPerformance(
            script: script,
            audioFileURL: combinedAudioURL,
            duration: currentTime,
            segmentTimings: segmentTimings
        )
    }

    // MARK: - TTS Generation

    private func generateTTS(text: String, voice: Voice, retryCount: Int = 0) async throws -> URL {
        var request = URLRequest(url: ttsEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(APIConfig.xAiApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let requestBody: [String: Any] = [
            "input": text,
            "voice": voice.rawValue,
            "response_format": "wav"  // WAV format - let AVFoundation handle it natively
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw VoicePerformerError.generationFailed("Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"

                // Retry on rate limit or server errors
                if (httpResponse.statusCode == 429 || httpResponse.statusCode >= 500) && retryCount < 3 {
                    let delay = TimeInterval(pow(2.0, Double(retryCount))) // Exponential backoff
                    print("    ⚠️ TTS failed (HTTP \(httpResponse.statusCode)), retrying in \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await generateTTS(text: text, voice: voice, retryCount: retryCount + 1)
                }

                throw VoicePerformerError.generationFailed("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }

            guard !data.isEmpty else {
                throw VoicePerformerError.audioProcessingFailed
            }

            // Save WAV file directly - no processing needed!
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("tts_\(UUID().uuidString).wav")
            try data.write(to: tempURL)

            print("    📁 Saved TTS audio: \(tempURL.lastPathComponent)")
            return tempURL

        } catch is CancellationError {
            throw VoicePerformerError.cancelled
        } catch {
            throw VoicePerformerError.apiError(error)
        }
    }

    // MARK: - Voice Selection

    private func selectVoice(for character: Character?, emotion: ScriptSegment.Emotion?) -> Voice {
        guard let character = character else {
            return .ara  // Default voice for narrator
        }

        let personality = character.personality

        // Voice selection based on character personality and emotion
        switch (personality.energy, personality.tone, personality.confidence) {
        case (.veryEnergetic, _, _), (_, .comedic, _):
            return .eve  // Energetic and enthusiastic

        case (.veryCalm, _, _), (_, _, .timid):
            return .una  // Calm and measured

        case (_, .serious, .domineering), (_, .serious, .veryConfident):
            return .leo  // Authoritative and commanding

        case (_, .serious, _), (.calm, _, _):
            return .rex  // Professional and clear

        case (.energetic, .playful, _):
            return .eve  // Energetic and enthusiastic

        default:
            // Default based on general energy level
            if personality.energy == .energetic || personality.energy == .veryEnergetic {
                return .eve
            } else if personality.energy == .calm || personality.energy == .veryCalm {
                return .una
            } else {
                return .ara  // Balanced default
            }
        }
    }

    private func formatSegmentForTTS(_ segment: ScriptSegment) -> String {
        // For TTS API, we just send the raw text
        // The emotion and character traits are handled through voice selection
        return segment.content
    }

    // MARK: - Helper Functions

    private func createSilenceFile(duration: TimeInterval) throws -> URL {
        // Create a silent audio file using AVFoundation
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("silence_\(UUID().uuidString).wav")

        let sampleRate = 24000.0
        let channelCount: AVAudioChannelCount = 1
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        )!

        let frameCount = AVAudioFrameCount(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw VoicePerformerError.audioProcessingFailed
        }
        buffer.frameLength = frameCount

        // Buffer is already zeroed (silence)

        let audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: format.settings,
            commonFormat: .pcmFormatInt16,
            interleaved: false
        )
        try audioFile.write(from: buffer)

        return tempURL
    }

    private func getAudioDuration(from url: URL) throws -> TimeInterval {
        let audioFile = try AVAudioFile(forReading: url)
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate
        return duration
    }

    private func concatenateAudioFiles(_ urls: [URL]) async throws -> URL {
        guard !urls.isEmpty else {
            throw VoicePerformerError.audioProcessingFailed
        }

        // If only one file, just return it
        if urls.count == 1 {
            return urls[0]
        }

        // Create composition
        let composition = AVMutableComposition()
        guard let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VoicePerformerError.audioProcessingFailed
        }

        var currentTime = CMTime.zero

        for url in urls {
            let asset = AVURLAsset(url: url)

            // Use modern async API
            guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
                continue
            }

            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            try audioTrack.insertTimeRange(timeRange, of: assetTrack, at: currentTime)
            currentTime = CMTimeAdd(currentTime, duration)
        }

        // Export the composition to a file
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("combined_\(UUID().uuidString).wav")

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw VoicePerformerError.audioProcessingFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .wav

        // Use continuation for the export callback
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                if exportSession.status == .completed {
                    continuation.resume()
                } else if let error = exportSession.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: VoicePerformerError.audioProcessingFailed)
                }
            }
        }

        print("    ✓ Concatenated \(urls.count) audio files")
        return outputURL
    }
}
