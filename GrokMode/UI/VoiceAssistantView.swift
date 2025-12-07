//
//  VoiceAssistantView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI

struct VoiceAssistantView: View {
    @State private var animator = WaveformAnimator()
    @State private var isListening = false
    @State var isAnimating = false
    @Namespace private var morphNamespace
    
    var body: some View {
        NavigationStack {
            VStack {
                List(1..<100) { i in
                    GrokPrimaryContentBlock(
                        userIcon: ImageResource(name: "Grok", bundle: .main),
                        displayName: "Elon Musk",
                        username: "elonmusk",
                        text: "Just had a great conversation with Grok about the future of AI and space exploration. The possibilities are endless when you combine these technologies!"
                    )
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
            .toolbar {
                  ToolbarItem(placement: .principal) {
                      HStack(spacing: 8) {
                          Image(.grok)
                              .resizable()
                              .frame(width: 40, height: 40)
                      }
                      .foregroundStyle(.primary)
                  }
              }
            .toolbar {
                if !isListening {
                    ToolbarItem(placement:.bottomBar) {
                        Button {
                            withAnimation {
                                self.isListening = true
                                self.isAnimating = true
                                animator.startAnimating()
                            }
                        } label: {
                            AnimatedWaveformView(animator: animator, barCount: 5, accentColor: .background, isAnimating: isAnimating)
                                .frame(height: 40)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.white)
//                        .matchedGeometryEffect(id: "signals", in: morphNamespace)
                    }
                } else {
                    ToolbarItem(placement:.bottomBar) {
                        Button {} label: {
                            AnimatedWaveformView(animator: animator, barCount: 37, accentColor: .background , isAnimating: isAnimating)
                                .frame(maxWidth: .infinity, maxHeight: 40)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.white)
                    }

                    if isListening {
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                        DefaultToolbarItem(kind: .search, placement: .bottomBar) // <- this
                        ToolbarSpacer(.fixed, placement: .bottomBar)

                        ToolbarItem(placement:.bottomBar) {
                            stopButton
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {

    }

    private var stopButton: some View {
        Button {
            withAnimation {
                isListening = false
                isAnimating = false
                animator.stopAnimating()
            }
        } label: {
            Image(systemName: "stop.fill")
                .foregroundStyle(.white)
                .font(.system(size: 20))
                .frame(width: 60, height: 75)
        }
        .glassEffect(.clear.interactive())
    }
}

#Preview {
    VoiceAssistantView()
}
