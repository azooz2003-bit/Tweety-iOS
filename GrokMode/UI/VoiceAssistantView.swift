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
                if !viewModel.isListening {
                    ToolbarItem(placement:.bottomBar) {
                        Button {
                            // Reconnect if needed, then start listening
                            withAnimation {
                                if !viewModel.isConnected {
                                    viewModel.reconnect()
                                } else {
                                    viewModel.startListening()
                                }
                            }
                        } label: {
                            AnimatedWaveformView(animator: animator, barCount: 5, accentColor: .background, isAnimating: isAnimating)
                                .frame(height: 40)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.white)
                        .disabled(!viewModel.isConnected && !viewModel.isConnecting)
                        .opacity(viewModel.isConnected ? 1.0 : 0.5)
                        .matchedGeometryEffect(id: "waveform", in: morphNamespace)
                    }
                } else {
                    ToolbarItem(placement:.bottomBar) {
                        Button {} label: {
                            AnimatedWaveformView(animator: animator, barCount: 37, accentColor: .background , isAnimating: isAnimating)
                                .frame(maxWidth: .infinity, maxHeight: 40)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.white)
                        .matchedGeometryEffect(id: "waveform", in: morphNamespace)
                    }

                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)

                    ToolbarItem(placement:.bottomBar) {
                        stopButton
                    }
                }

                // Add reconnect button when disconnected
                if !viewModel.isConnected && !viewModel.isConnecting {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            viewModel.reconnect()
                        } label: {
                            Label("Reconnect", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
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

// MARK: - Tool Confirmation Sheet

struct ToolConfirmationSheet: View {
    let toolCall: PendingToolCall
    let onApprove: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue.gradient)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview Action")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Grok needs your confirmation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.top, 4)

            Divider()
                .background(.white.opacity(0.2))

            // Tool Details
            VStack(alignment: .leading, spacing: 8) {
                Text(toolCall.previewTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(toolCall.previewContent)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )

            Spacer()

            // Action Buttons
            HStack(spacing: 16) {
                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .background(.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )

                Button {
                    onApprove()
                    dismiss()
                } label: {
                    Text("Approve")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
            }
        }
        .padding(24)
        // Removed custom background and presentation modifications
    }
}

#Preview {
    VoiceAssistantView()
}

#Preview("Sheet") {
    ToolConfirmationSheet(toolCall: .init(id: "ddwd", functionName: "ffq", arguments: "fqfq", previewTitle: "fqf", previewContent: "fqffff"), onApprove: {}, onCancel: {})
}

