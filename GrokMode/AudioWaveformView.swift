//
//  AudioWaveformView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI
import AVFoundation
import Combine

class AudioMonitor: ObservableObject {
    @Published var soundSamples: [CGFloat] = Array(repeating: 0.5, count: 5)

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var audioSession: AVAudioSession = .sharedInstance()

    init() {
        setupAudioSession()
        startMonitoring()
    }

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try audioSession.setActive(true)

            let url = URL(fileURLWithPath: "/dev/null")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatAppleLossless),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
        }
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateMeters()
        }
    }

    private func updateMeters() {
        audioRecorder?.updateMeters()

        guard let recorder = audioRecorder else { return }

        let power = recorder.averagePower(forChannel: 0)
        let normalizedPower = self.normalizeSoundLevel(level: power)

        DispatchQueue.main.async {
            self.soundSamples.removeFirst()
            self.soundSamples.append(normalizedPower)
        }
    }

    private func normalizeSoundLevel(level: Float) -> CGFloat {
        let minDb: Float = -80
        let maxDb: Float = 0

        let clampedLevel = max(minDb, min(level, maxDb))
        let normalized = (clampedLevel - minDb) / (maxDb - minDb)

        return CGFloat(normalized)
    }

    func stopMonitoring() {
        timer?.invalidate()
        audioRecorder?.stop()
        try? audioSession.setActive(false)
    }

    deinit {
        stopMonitoring()
    }
}

struct AudioWaveformView: View {
    @StateObject private var audioMonitor = AudioMonitor()
    @State private var isRecording = false

    let barCount: Int = 5
    let barSpacing: CGFloat = 4
    let barWidth: CGFloat = 3

    var body: some View {
        Button(action: {
            isRecording.toggle()
        }) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 80)

                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 80, height: 80)

                HStack(spacing: barSpacing) {
                    ForEach(0..<barCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: barWidth / 2)
                            .fill(isRecording ? Color.cyan : Color.white)
                            .frame(width: barWidth)
                            .frame(height: barHeight(for: index))
                            .animation(.easeInOut(duration: 0.1), value: audioMonitor.soundSamples[index])
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func barHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 40

        guard index < audioMonitor.soundSamples.count else { return minHeight }

        let sample = audioMonitor.soundSamples[index]
        let height = minHeight + (maxHeight - minHeight) * sample

        return isRecording ? height : minHeight
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AudioWaveformView()
    }
}
