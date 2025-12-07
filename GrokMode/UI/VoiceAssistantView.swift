//
//  VoiceAssistantView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI

struct VoiceAssistantView: View {
    @State private var viewModel = VoiceAssistantViewModel()
    @State private var animator = WaveformAnimator()
    @State var isAnimating = false
    @Namespace private var morphNamespace

    let autoConnect: Bool

    init(autoConnect: Bool = false) {
        self.autoConnect = autoConnect
    }

    var body: some View {
        NavigationStack {
            VStack {
                if !viewModel.micPermissionGranted {
                    permissionView
                } else if !viewModel.isConnected && !viewModel.isConnecting && !autoConnect {
                    // Show connection view only if NOT auto-connecting
                    connectionView
                } else {
                    // Show conversation list when:
                    // - Connected
                    // - Connecting
                    // - Auto-connecting (even before connection starts)
                    conversationList
                }
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
                if viewModel.isConnected {
                    if !viewModel.isListening {
                        ToolbarItem(placement:.bottomBar) {
                            Button {
                                withAnimation {
                                    viewModel.startListening()
                                    isAnimating = true
                                    animator.startAnimating()
                                }
                            } label: {
                                AnimatedWaveformView(animator: animator, barCount: 5, accentColor: .background, isAnimating: isAnimating)
                                    .frame(height: 40)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(.white)
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

                        if viewModel.isListening {
                            ToolbarSpacer(.fixed, placement: .bottomBar)
                            DefaultToolbarItem(kind: .search, placement: .bottomBar)
                            ToolbarSpacer(.fixed, placement: .bottomBar)

                            ToolbarItem(placement:.bottomBar) {
                                stopButton
                            }
                        }
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
        }
        .overlay(toolConfirmationOverlay)
    }

    // MARK: - Subviews

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Microphone Access Required")
                .font(.title2)
                .fontWeight(.bold)

            Text("Gerald needs microphone access to have voice conversations with you.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)

            Button("Grant Access") {
                viewModel.requestMicrophonePermission()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }

    private var connectionView: some View {
        VStack(spacing: 20) {
            Image(.grok)
                .resizable()
                .frame(width: 80, height: 80)

            Text("Ready to Talk to Gerald")
                .font(.title2)
                .fontWeight(.bold)

            if let error = viewModel.connectionError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Connect") {
                viewModel.connect()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(viewModel.isConnecting || !viewModel.canConnect)

            if !viewModel.isXAuthenticated {
                Button("Login with X") {
                    viewModel.loginWithX()
                }
                .buttonStyle(.bordered)
                .tint(.black)
            }
        }
        .padding()
    }

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
            .onChange(of: viewModel.conversationItems.count) { _ in
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

    private var toolConfirmationOverlay: some View {
        Group {
            if let toolCall = viewModel.pendingToolCall {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Text("Preview Action")
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(toolCall.previewTitle)
                                .font(.subheadline)
                                .fontWeight(.bold)

                            Text(toolCall.previewContent)
                                .font(.body)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }

                        HStack(spacing: 20) {
                            Button("Cancel") {
                                viewModel.rejectToolCall()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)

                            Button("Approve") {
                                viewModel.approveToolCall()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                    .padding(.horizontal, 40)
                }
            }
        }
    }
}

#Preview {
    VoiceAssistantView()
}
