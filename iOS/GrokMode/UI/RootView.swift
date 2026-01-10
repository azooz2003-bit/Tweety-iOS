//
//  RootView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI

struct RootView: View {
    @Bindable var authViewModel: AuthViewModel
    let appAttestService: AppAttestService
    let storeManager: StoreKitManager
    let creditsService: RemoteCreditsService
    let usageTracker: UsageTracker
    let imageCache: ImageCache

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                VoiceAssistantView(
                    autoConnect: true,
                    authViewModel: authViewModel,
                    appAttestService: appAttestService,
                    storeManager: storeManager,
                    creditsService: creditsService,
                    usageTracker: usageTracker,
                    imageCache: imageCache
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                AuthenticationView(authViewModel: authViewModel)
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
    @Previewable @State var authViewModel = {
        let appAttestService = AppAttestService()
        return AuthViewModel(appAttestService: appAttestService)
    }()

    let appAttestService = AppAttestService()
    let creditsService = RemoteCreditsService(appAttestService: appAttestService)

    RootView(
        authViewModel: authViewModel,
        appAttestService: appAttestService,
        storeManager: StoreKitManager(creditsService: creditsService, authService: authViewModel.authService),
        creditsService: creditsService,
        usageTracker: UsageTracker(creditsService: creditsService),
        imageCache: ImageCache()
    )
    .task {
        await authViewModel.startObserving()
    }
}
