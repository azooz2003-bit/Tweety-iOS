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
    @Namespace private var morphNamespace

    let autoConnect: Bool

    init(autoConnect: Bool = false, authViewModel: AuthViewModel) {
        self.autoConnect = autoConnect
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

                          if viewModel.isConnected {
                              Circle()
                                  .fill(Color.green)
                                  .frame(width: 8, height: 8)
                          } else if viewModel.isConnecting {
                              ProgressView()
                                  .scaleEffect(0.7)
                          }
                      }
                      .foregroundStyle(.primary)
                  }
              }
            .toolbar {
                ToolbarItem(placement:.bottomBar) {
                    if !viewModel.isListening {
                        waveformButton(barCount: 5) {
                            // Reconnect if needed, then start listening
                            withAnimation {
                                if !viewModel.isConnected {
                                    viewModel.reconnect()
                                } else {
                                    try? viewModel.startListening() // TODO: handle error
                                }
                            }
                        }
                    } else {
                        waveformButton(barCount: 37)
                            .disabled(!viewModel.isConnected)
                            .opacity(viewModel.isConnected ? 1.0 : 0.5)
                            .frame(maxHeight: .infinity)
                    }

                }

                if viewModel.isListening {

                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)

                    ToolbarItem(placement:.bottomBar) {
                        stopButton
                    }
                }
            }
            .onAppear {
                viewModel.checkPermissions()

                // Auto-connect if enabled and permissions granted
                if autoConnect && viewModel.micPermissionGranted && !viewModel.isConnected && !viewModel.isConnecting {
                    // Small delay to ensure UI is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.connect()
                    }
                }
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
            get: { viewModel.pendingToolCall },
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
        Button {
            withAnimation {
                viewModel.stopListening()
            }
        } label: {
            Image(systemName: "stop.fill")
                .foregroundStyle(.white)
                .font(.system(size: 20))
//                .frame(width: 60, height: 75)
        }
    }
}

#Preview {
    @Previewable @State var authViewModel = AuthViewModel()
    VoiceAssistantView(authViewModel: authViewModel)
}

