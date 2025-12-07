//
//  AnimatedWaveformView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI

@Observable
class WaveformAnimator {
    var amplitudes: [CGFloat] = Array(repeating: 0.3, count: 30)

    private var timer: Timer?
    private var isAnimating = false

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.updateAmplitudes()
        }
    }

    func stopAnimating() {
        isAnimating = false
        timer?.invalidate()
        timer = nil

        // Smoothly return to baseline
        withAnimation(.easeOut(duration: 0.3)) {
            amplitudes = Array(repeating: 0.3, count: amplitudes.count)
        }
    }

    /// Updates the waveform based on audio input level
    /// Call this method whenever you receive audio data to animate the waveform
    /// - Parameter audioLevel: The audio level (0.0 to 1.0) to drive the waveform animation
    func updateAudioLevel(_ audioLevel: CGFloat) {
        let clampedLevel = max(0.0, min(1.0, audioLevel))

        // Generate dynamic amplitudes based on audio level
        let newAmplitudes = amplitudes.enumerated().map { index, currentValue in
            // Create varied heights across bars for visual interest
            let variance = CGFloat.random(in: 0.8...1.2)
            let targetValue = clampedLevel * variance

            // Smooth transition
            return currentValue * 0.7 + targetValue * 0.3
        }

        withAnimation(.easeInOut(duration: 0.05)) {
            amplitudes = newAmplitudes
        }
    }

    private func updateAmplitudes() {
        DispatchQueue.main.async {
            // Generate speech-like pattern with varying intensities
            let newAmplitudes = self.amplitudes.enumerated().map { index, currentValue in
                // Create wave-like motion with some randomness
                let baseWave = sin(Date().timeIntervalSince1970 * 3 + Double(index) * 0.8)
                let randomness = CGFloat.random(in: 0.2...0.9)

                // Mix wave pattern with randomness for natural speech feel
                let targetValue = (CGFloat(baseWave) + 1) / 2 * 0.4 + randomness * 0.6

                // Smooth transition from current to target
                return currentValue * 0.6 + targetValue * 0.4
            }

            withAnimation(.easeInOut(duration: 0.08)) {
                self.amplitudes = newAmplitudes
            }
        }
    }

    deinit {
        stopAnimating()
    }
}

struct AnimatedWaveformView: View {
    let animator: WaveformAnimator
    let barCount: Int?
    let barSpacing: CGFloat
    let barWidth: CGFloat
    let accentColor: Color
    let isAnimating: Bool
    let fillWidth: Bool

    init(
        animator: WaveformAnimator,
        barCount: Int? = nil,
        barSpacing: CGFloat = 4,
        barWidth: CGFloat = 3,
        accentColor: Color = .cyan,
        isAnimating: Bool = false,
        fillWidth: Bool = false
    ) {
        self.animator = animator
        self.barCount = barCount
        self.barSpacing = barSpacing
        self.barWidth = barWidth
        self.accentColor = accentColor
        self.isAnimating = isAnimating
        self.fillWidth = fillWidth
    }

    var body: some View {
        if fillWidth {
            GeometryReader { geometry in
                let calculatedBarCount = calculateBarCount(for: geometry.size.width)
                HStack(spacing: barSpacing) {
                    ForEach(0..<calculatedBarCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: barWidth / 2)
                            .fill(isAnimating ? accentColor : Color.black)
                            .frame(width: barWidth)
                            .frame(height: barHeight(for: index, totalBars: calculatedBarCount))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            let count = barCount ?? 5
            HStack(spacing: barSpacing) {
                ForEach(0..<count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(isAnimating ? accentColor : Color.black)
                        .frame(width: barWidth)
                        .frame(height: barHeight(for: index, totalBars: count))
                }
            }
        }
    }

    private func calculateBarCount(for width: CGFloat) -> Int {
        let totalSpacing = barWidth + barSpacing
        let count = Int(width / totalSpacing)
        return max(5, count)
    }

    private func barHeight(for index: Int, totalBars: Int) -> CGFloat {
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 40

        // Map the bar index to the amplitude array
        // If we have more bars than amplitudes, cycle through the amplitudes
        let amplitudeIndex = index % animator.amplitudes.count
        let amplitude = animator.amplitudes[amplitudeIndex]

        let height = minHeight + (maxHeight - minHeight) * amplitude

        return isAnimating ? height : minHeight
    }
}

#Preview {
    @Previewable @State var animator = WaveformAnimator()
    @Previewable @State var isAnimating = false

    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            AnimatedWaveformView(
                animator: animator,
                barCount: 40,
                isAnimating: isAnimating
            )

            Button("Toggle") {
                isAnimating.toggle()
                if isAnimating {
                    animator.startAnimating()
                } else {
                    animator.stopAnimating()
                }
            }
        }
    }
}
