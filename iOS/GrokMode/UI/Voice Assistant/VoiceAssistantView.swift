//
//  VoiceAssistantView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI

struct VoiceAssistantView: View {
    @State private var viewModel: VoiceAssistantViewModel
    @State private var animator = WaveformAnimator()
    @State var isAnimating = false

    let shouldAutoconnect: Bool

    init(autoConnect: Bool = false, authViewModel: AuthViewModel) {
        self.shouldAutoconnect = autoConnect
        self._viewModel = State(initialValue: VoiceAssistantViewModel(authViewModel: authViewModel))
    }

    var body: some View {
        NavigationStack {
            VStack {
                conversationList
            }
            .toolbar {
                  ToolbarItem(placement: .principal) {
                      HStack(spacing: 8) {
                          Image(.grok)
                              .resizable()
                              .frame(width: 40, height: 40)

                          if viewModel.voiceSessionState.isConnected {
                              Circle()
                                  .fill(Color.green)
                                  .frame(width: 8, height: 8)
                          } else if viewModel.voiceSessionState.isConnecting {
                              ProgressView()
                                  .scaleEffect(0.7)
                          }
                      }
                      .foregroundStyle(.primary)
                  }
              }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            Task {
                                await viewModel.logoutX()
                            }
                        } label: {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Label("", systemImage: "ellipsis")
                    }
                }

                ToolbarItem(placement:.bottomBar) {
                    if !viewModel.isSessionActivated {
                        waveformButton(barCount: 5) {
                            withAnimation {
                                viewModel.startSession()
                            }
                        }
                    } else {
                        waveformButton(barCount: 37)
                    }

                }

                if viewModel.isSessionActivated {

                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        Text(viewModel.formattedSessionDuration)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    ToolbarItem(placement:.bottomBar) {
                        stopButton
                    }
                }
            }
            .onAppear {
                viewModel.checkPermissions()
            }
            .onChange(of: viewModel.currentAudioLevel) { oldValue, newValue in
                // Update waveform based on real audio level
                animator.updateAudioLevel(CGFloat(newValue))

                // Update animation state based on audio activity
                withAnimation {
                    isAnimating = newValue > 0.1 // Consider animating if level is above threshold
                }
            }
        }
        .sheet(item: Binding(
            get: { viewModel.currentPendingToolCall },
            set: { if $0 == nil { viewModel.rejectToolCall() } }
        )) { toolCall in
            ToolConfirmationSheet(
                toolCall: toolCall,
                onApprove: { viewModel.approveToolCall() },
                onCancel: { viewModel.rejectToolCall() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func waveformButton(barCount: Int, action: @escaping () -> Void = {}) -> some View {
        Button {
            action()
        } label: {
            AnimatedWaveformView(animator: animator, barCount: barCount, accentColor: .background, isAnimating: isAnimating)
        }
        .buttonStyle(.glassProminent)
        .tint(.white)
    }

    // MARK: - Subviews

    private var conversationList: some View {
        ScrollViewReader { scrollProxy in
            List {
                ForEach(viewModel.conversationItems) { item in
                    ConversationItemView(item: item)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .id(item.id)
                }
            }
            .listStyle(.plain)
            .onChange(of: viewModel.conversationItems.count) { _, _ in
                if let lastItem = viewModel.conversationItems.last {
                    withAnimation {
                        scrollProxy.scrollTo(lastItem.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var stopButton: some View {
        Button("Stop", systemImage: "stop.fill") {
            withAnimation {
                viewModel.stopSession()
            }
        }
        .foregroundStyle(.white)
        .font(.system(size: 20))
    }
}

#Preview {
    @Previewable @State var authViewModel = AuthViewModel()
    VoiceAssistantView(authViewModel: authViewModel)
}

