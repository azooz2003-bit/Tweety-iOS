//
//  GrokModeApp.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI
internal import os

@main
struct GrokModeApp: App {
    let creditsService: RemoteCreditsService
    let appAttestService: AppAttestService

    @State var authViewModel: AuthViewModel
    @State var storeManager: StoreKitManager
    @State var usageTracker: UsageTracker
    @State var imageCache = ImageCache()

    init() {
        self.appAttestService = AppAttestService()
        self.creditsService = RemoteCreditsService(appAttestService: appAttestService)
        let authVM = AuthViewModel(appAttestService: appAttestService)
        self._authViewModel = State(initialValue: authVM)
        self._storeManager = State(initialValue: StoreKitManager(creditsService: creditsService, authService: authVM.authService))
        self._usageTracker = State(initialValue: UsageTracker(creditsService: creditsService))
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authViewModel: authViewModel,
                appAttestService: appAttestService,
                storeManager: storeManager,
                creditsService: creditsService,
                usageTracker: usageTracker,
                imageCache: imageCache
            )
            .task {
                await initializeStore()
            }
        }
    }

    private func initializeStore() async {
        do {
            AppLogger.store.info("Initializing StoreKit...")

            storeManager.startObservingTransactions()

            try await storeManager.loadProducts()

            await storeManager.restoreAllTransactions()

            AppLogger.store.info("StoreKit initialized successfully")
        } catch {
            AppLogger.store.error("Failed to initialize StoreKit: \(error)")
        }
    }
}
