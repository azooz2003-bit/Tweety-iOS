//
//  AudioPlayer.swift
//  GrokMode
//
//  Created by Claude on 12/7/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Errors

enum AudioPlayerError: LocalizedError {
    case noAudioLoaded
    case invalidAudioData
    case audioSessionSetupFailed
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudioLoaded:
            return "No audio performance has been loaded"
        case .invalidAudioData:
            return "Invalid audio data format"
        case .audioSessionSetupFailed:
            return "Failed to configure audio session"
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
        }
    }
}

// MARK: - Audio Player

/// Plays audio performances using AVFoundation
class AudioPlayer: NSObject {
    // MARK: - Properties

    private(set) var playbackState: PlaybackState = .idle {
        didSet {
            playbackStateSubject.send(playbackState)
        }
    }

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        playbackStateSubject.eraseToAnyPublisher()
    }

    private let playbackStateSubject = PassthroughSubject<PlaybackState, Never>()

    private var audioPlayer: AVAudioPlayer?
    private var currentPerformance: AudioPerformance?
    private var audioFileURL: URL?
    private var displayLink: CADisplayLink?

    // MARK: - Initialization

    override init() {
        super.init()
        setupAudioSession()
    }

    deinit {
        stop()
        cleanupTemporaryFiles()
    }

    // MARK: - Public Methods

    func load(_ performance: AudioPerformance) async throws {
        print("🔊 Loading audio performance...")

        playbackState = .loading

        do {
            // Directly use the WAV file from the performance
            audioFileURL = performance.audioFileURL

            // Create AVAudioPlayer - AVFoundation handles everything!
            audioPlayer = try AVAudioPlayer(contentsOf: performance.audioFileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            currentPerformance = performance
            playbackState = .ready

            print("✅ Audio loaded successfully: \(performance.duration)s")

        } catch {
            playbackState = .failed(error)
            throw error
        }
    }

    func play() throws {
        guard let player = audioPlayer else {
            throw AudioPlayerError.noAudioLoaded
        }

        guard player.play() else {
            throw AudioPlayerError.playbackFailed("AVAudioPlayer failed to start")
        }

        playbackState = .playing(currentTime: player.currentTime)
        startDisplayLink()

        print("▶️ Playback started")
    }

    func pause() {
        guard let player = audioPlayer else { return }

        player.pause()
        playbackState = .paused(currentTime: player.currentTime)
        stopDisplayLink()

        print("⏸️ Playback paused at \(player.currentTime)s")
    }

    func stop() {
        guard let player = audioPlayer else { return }

        player.stop()
        player.currentTime = 0
        playbackState = .idle
        stopDisplayLink()

        print("⏹️ Playback stopped")
    }

    func seek(to time: TimeInterval) throws {
        guard let player = audioPlayer else {
            throw AudioPlayerError.noAudioLoaded
        }

        guard time >= 0 && time <= player.duration else {
            throw AudioPlayerError.playbackFailed("Seek time out of bounds")
        }

        player.currentTime = time

        // Update playback state
        if player.isPlaying {
            playbackState = .playing(currentTime: time)
        } else {
            playbackState = .paused(currentTime: time)
        }

        print("⏩ Seeked to \(time)s")
    }

    func currentTime() -> TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }

    // MARK: - Private Methods

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("✅ Audio session configured for playback")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
            playbackState = .failed(AudioPlayerError.audioSessionSetupFailed)
        }
    }

    private func cleanupTemporaryFiles() {
        guard let url = audioFileURL else { return }

        try? FileManager.default.removeItem(at: url)
        audioFileURL = nil
    }

    // MARK: - Display Link for Continuous Updates

    private func startDisplayLink() {
        stopDisplayLink()

        displayLink = CADisplayLink(target: self, selector: #selector(updatePlaybackState))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updatePlaybackState() {
        guard let player = audioPlayer, player.isPlaying else { return }

        playbackState = .playing(currentTime: player.currentTime)
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopDisplayLink()

        if flag {
            playbackState = .completed
            print("✅ Playback completed successfully")
        } else {
            playbackState = .failed(AudioPlayerError.playbackFailed("Playback interrupted"))
            print("❌ Playback failed or was interrupted")
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stopDisplayLink()

        let error = error ?? AudioPlayerError.invalidAudioData
        playbackState = .failed(error)

        print("❌ Audio decode error: \(error.localizedDescription)")
    }
}

// MARK: - Segment-Aware Player Extension

extension AudioPlayer {
    /// Get the current segment being played
    func currentSegment() -> ScriptSegment? {
        guard let performance = currentPerformance else { return nil }

        let time = currentTime()

        // Find the segment at current time
        let segmentTiming = performance.segmentTimings.first { timing in
            time >= timing.startTime && time < timing.endTime
        }

        guard let timing = segmentTiming else { return nil }

        return performance.script.segments.first { $0.id == timing.segmentId }
    }

    /// Seek to a specific segment
    func seek(to segment: ScriptSegment) throws {
        guard let performance = currentPerformance else {
            throw AudioPlayerError.noAudioLoaded
        }

        guard let timing = performance.segmentTimings.first(where: { $0.segmentId == segment.id }) else {
            throw AudioPlayerError.playbackFailed("Segment not found in performance")
        }

        try seek(to: timing.startTime)
    }
}
