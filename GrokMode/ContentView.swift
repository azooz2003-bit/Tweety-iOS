//
//  ContentView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI
import Orb

struct WaveformShape: Shape {
    var phase: Double
    var amplitude: Double
    var frequency: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2

        path.move(to: CGPoint(x: 0, y: midHeight))

        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin((relativeX + phase) * .pi * 2 * frequency)
            let y = midHeight + sine * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        return path
    }
}

struct ContentView: View {
    @State private var isPressed = false
    @State private var scale: CGFloat = 1.0
    @State private var wavePhase: Double = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Waveform animations
                ZStack {
                    WaveformShape(phase: wavePhase, amplitude: 15, frequency: 2)
                        .stroke(isPressed ? Color.cyan : Color.white, lineWidth: 2)
                        .opacity(0.6)
                        .frame(height: 60)

                    WaveformShape(phase: -wavePhase * 1.5, amplitude: 20, frequency: 1.5)
                        .stroke(isPressed ? Color.cyan.opacity(0.7) : Color.white.opacity(0.7), lineWidth: 2)
                        .opacity(0.4)
                        .frame(height: 60)
                }
                .padding(.horizontal, 40)
            }

            OrbView(configuration: .init(
                backgroundColors: isPressed ? [
                    Color(red: 0.0, green: 0.7, blue: 1.0),  // Bright cyan
                    Color(red: 0.2, green: 0.5, blue: 1.0),  // Deep blue
                    .white,
                    Color(red: 0.0, green: 0.9, blue: 0.9)   // Electric cyan
                ] : [
                    .black,
                    Color(red: 0.15, green: 0.15, blue: 0.15),  // Dark gray
                    .white,
                    Color(red: 0.9, green: 0.9, blue: 0.9)      // Light gray
                ],
                glowColor: isPressed ? .cyan : .white,
                coreGlowIntensity: isPressed ? 3.0 : 2.0,
                showBackground: true,
                showWavyBlobs: true,
                showParticles: true,
                showGlowEffects: true,
                showShadow: true,
                speed: isPressed ? 120 : 80
            ))
            .frame(width: 250, height: 250)
            .scaleEffect(scale)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            scale = 1.2
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            scale = 1.0
                        }

                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPressed.toggle()
                        }
                    }
            )
            .overlay {
                Image(ImageResource(name: "Grok", bundle: .main))
                    .resizable()
//                    .font(.system(size: 90, weight: .light))
                    .foregroundStyle(.white)
                    .opacity(0.9)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                wavePhase = 1
            }
        }
    }
}

#Preview {
    ContentView()
}
