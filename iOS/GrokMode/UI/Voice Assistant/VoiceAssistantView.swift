//
//  VoiceAssistantView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI
import UIKit

struct VoiceAssistantView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: VoiceAssistantViewModel
    @State private var animator = WaveformAnimator()
    @State var isAnimating = false
    @State private var showSettings = false
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .light) // @State so that it's not frequently recreated

    let shouldAutoconnect: Bool

    let barWidth: CGFloat = 3
    let barSpacing: CGFloat = 4

    init(autoConnect: Bool = false, authViewModel: AuthViewModel) {
        self.shouldAutoconnect = autoConnect
        self._viewModel = State(initialValue: VoiceAssistantViewModel(authViewModel: authViewModel))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            VStack {
                conversationList
            }
            .toolbar {
                  ToolbarItem(placement: .principal) {
                      VStack {
                          Text("Voice Service")
                              .font(.subheadline)
                              .foregroundStyle(Color(.label).opacity(0.6))
                              .padding(.top, 5)

                          voiceServicePicker
                      }
                  }
              }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    debugPicker
                }

                ToolbarItem(placement:.bottomBar) {
                    if !viewModel.isSessionActivated {
                        waveformButton(barCount: 5) {
                            hapticGenerator.impactOccurred()
                            withAnimation {
                                viewModel.startSession()
                            }
                        }
                    } else {
                        waveformButton(barCount: 37, fillWidth: true)
                    }

                }

                if viewModel.isSessionActivated {

                    ToolbarSpacer(.fixed, placement: .bottomBar)
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                    ToolbarSpacer(.fixed, placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        SessionTimerView(sessionStartTime: viewModel.sessionStartTime)
                    }

                    ToolbarItem(placement:.bottomBar) {
                        stopButton
                    }
                }
            }
            .onAppear {
                viewModel.checkPermissions()
                hapticGenerator.prepare() // Prepare haptic generator for reduced latency
            }
            .onChange(of: viewModel.currentAudioLevel) { oldValue, newValue in
                animator.updateAudioLevel(CGFloat(newValue))

                withAnimation {
                    isAnimating = newValue > 0.1 // Consider animating if level is above threshold
                }
            }
            .onChange(of: viewModel.voiceSessionState) { oldState, newState in
                let wasConnected = oldState.isConnected
                let isNowConnected = newState.isConnected

                if wasConnected != isNowConnected {
                    hapticGenerator.impactOccurred()
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    viewModel.trackPartialUsageIfNeeded()
                }
            }
        }
        .sheet(item: Binding(
            get: { viewModel.currentPendingToolCall },
            set: { if $0 == nil { viewModel.rejectToolCall() } }
        )) { toolCall in
            ToolConfirmationSheet(
                toolCall: toolCall,
                serviceName: viewModel.selectedServiceType.assistantName,
                onApprove: { viewModel.approveToolCall() },
                onCancel: { viewModel.rejectToolCall() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onLogout: {
                await viewModel.logoutX()
            })
        }
    }

    @ViewBuilder
    private func waveformButton(barCount: Int, fillWidth: Bool = false, action: @escaping () -> Void = {}) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let barCountThatFits = calculateBarCount(for: width)

            Button {
                action()
            } label: {
                AnimatedWaveformView(animator: animator, barCount: barCountThatFits, barSpacing: barSpacing, barWidth: barWidth, accentColor: .background, isAnimating: isAnimating)
            }
            .id(barCountThatFits) // Force button to recreate when bar count changes
            .buttonStyle(.glassProminent)
            .tint(Color(.label))
            .frame(width: width)
        }
        .frame(maxWidth: fillWidth ? .infinity : nil)
        .if(!fillWidth) {
            $0.aspectRatio(contentMode: .fit)
        }
    }

    private func calculateBarCount(for width: CGFloat) -> Int {
        let totalSpacing = barWidth + barSpacing
        let count = Int(width / totalSpacing) - 1
        return max(5, count)
    }

    @ViewBuilder
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

    @ViewBuilder
    private var stopButton: some View {
        Button("Stop", systemImage: "stop.fill") {
            hapticGenerator.impactOccurred()
            withAnimation {
                viewModel.stopSession()
            }
        }
        .font(.system(size: 20))
    }

    @ViewBuilder
    private var debugPicker: some View {
        Menu {
            Menu("Voice Service") {
                Picker("Service", selection: $viewModel.selectedServiceType) {
                    ForEach(VoiceServiceType.allCases) { serviceType in
                        Label(serviceType.displayName, systemImage: serviceType == .xai ? "circle.slash" : "brain.head.profile")
                            .tag(serviceType)
                    }
                }
                .pickerStyle(.inline)
                .disabled(viewModel.isSessionActivated)
            }

            Section {
                Button {
                    Task {
                        await viewModel.logoutX()
                    }
                } label: {
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            #if DEBUG
            Section("Debug") {
                Button {
                    Task {
                        await viewModel.testRefreshToken()
                    }
                } label: {
                    Label("Test Refresh Token", systemImage: "arrow.clockwise")
                }

                NavigationLink {
                    UsageDashboardView()
                } label: {
                    Label("Usage & Costs", systemImage: "chart.bar.fill")
                }
            }
            #endif
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    @ViewBuilder
    private var voiceServicePicker: some View {
        Menu {
            Picker("", selection: $viewModel.selectedServiceType) {
                Text(VoiceServiceType.openai.displayName).tag(VoiceServiceType.openai)
                Text(VoiceServiceType.xai.displayName).tag(VoiceServiceType.xai)
            }
            .disabled(viewModel.isSessionActivated)
        } label: {
            HStack(spacing: 4) {
                Image(ImageResource(name: viewModel.selectedServiceType.iconName, bundle: .main))
                    .resizable()
                    .frame(width: 25, height: 25)
                Text(viewModel.selectedServiceType.displayName)
                    .padding(.trailing, 4)

                Group {
                    if viewModel.voiceSessionState.isConnected {
                        Circle()
                            .fill(Color.green)
                    } else if viewModel.voiceSessionState.isConnecting {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                }
                .frame(width: 8, height: 8)

            }
            .frame(minWidth: 165) // To get around iOS image cropping glitch
            .bold()
        }
    }
}

#Preview {
    @Previewable @State var authViewModel = AuthViewModel()
    VoiceAssistantView(authViewModel: authViewModel)
}

