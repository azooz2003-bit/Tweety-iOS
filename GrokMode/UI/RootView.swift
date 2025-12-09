//
//  RootView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI

struct RootView: View {
    @Bindable var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                VoiceAssistantView(autoConnect: true, authViewModel: authViewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                LoginView(authViewModel: authViewModel)
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .task {
            await authViewModel.startObserving()
        }
    }
}

#Preview {
    @Previewable @State var authViewModel = AuthViewModel()

    RootView(authViewModel: authViewModel)
        .task {
            await authViewModel.startObserving()
        }
}
