//
//  RootView.swift
//  GrokMode
//
//  Created by Claude Code on 12/7/25.
//

import SwiftUI

/// Root view that handles authentication routing
/// - Shows LoginView if user is not authenticated
/// - Shows VoiceAssistantView with auto-connect if user is authenticated
struct RootView: View {
    @ObservedObject private var authService = XAuthService.shared

    var body: some View {
        Group {
            if authService.isAuthenticated {
                VoiceAssistantView(autoConnect: true)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                LoginView()
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
    }
}

#Preview {
    RootView()
}
