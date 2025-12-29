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
    private var phaseOffsets: [CGFloat] = []
    private var time: TimeInterval = 0

    init() {
        phaseOffsets = (0..<30).map { _ in CGFloat.random(in: 0...2 * .pi) }
    }

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

        withAnimation(.easeOut(duration: 0.3)) {
            amplitudes = Array(repeating: 0.3, count: amplitudes.count)
        }
    }

    func updateAudioLevel(_ audioLevel: CGFloat) {
        let clampedLevel = max(0.0, min(1.0, audioLevel))
        time += 0.05

        let newAmplitudes = amplitudes.enumerated().map { index, currentValue in
            let wavePosition = CGFloat(index) * 0.5
            let phase = phaseOffsets[index]
            let wave = sin(time * 4 + wavePosition + phase)

            let baseVariance = CGFloat.random(in: 0.6...1.4)
            let waveInfluence = wave * 0.3
            let targetValue = clampedLevel * baseVariance * (1.0 + waveInfluence)

            let clampedTarget = max(0.1, min(1.0, targetValue))

            return currentValue * 0.6 + clampedTarget * 0.4
        }

        withAnimation(.easeInOut(duration: 0.05)) {
            amplitudes = newAmplitudes
        }
    }

    private func updateAmplitudes() {
        DispatchQueue.main.async {
            let newAmplitudes = self.amplitudes.enumerated().map { index, currentValue in
                let baseWave = sin(Date().timeIntervalSince1970 * 3 + Double(index) * 0.8)
                let randomness = CGFloat.random(in: 0.2...0.9)

                let targetValue = (CGFloat(baseWave) + 1) / 2 * 0.4 + randomness * 0.6

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
                            .fill(accentColor)
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
                        .fill(accentColor)
                        .frame(width: barWidth, height: barHeight(for: index, totalBars: count))
                }
            }
        }
    }

    private func calculateBarCount(for width: CGFloat) -> Int {
        let totalSpacing = barWidth + barSpacing
        let count = Int(width / totalSpacing) - 1
        return max(5, count)
    }

    private func barHeight(for index: Int, totalBars: Int) -> CGFloat {
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 40

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
        Color.white.ignoresSafeArea()

        VStack(spacing: 20) {
            Button {

            } label: {
                AnimatedWaveformView(
                    animator: animator,
                    barCount: 20,
                    accentColor: .white,
                    isAnimating: isAnimating,
                    fillWidth: false
                )
            }
            .background(.blue)


            Button("Toggle") {
                isAnimating.toggle()
                if isAnimating {
                    animator.startAnimating()
                } else {
                    animator.stopAnimating()
                }
            }

            Spacer()
        }
        .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
