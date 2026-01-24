//
//  AuthViewModel.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/8/25.
//

import Foundation
import UIKit
import OSLog

@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUserHandle: String?

    let authService: XAuthService

    init(appAttestService: AppAttestService) {
        let currentState = AuthState.loadFromKeychain()
        self.isAuthenticated = currentState.isAuthenticated
        self.currentUserHandle = currentState.currentUserHandle
        self.authService = XAuthService(authPresentationProvider: .init(), appAttestService: appAttestService)
    }

    func startObserving() async {
        await authService.checkStatus()

        for await state in authService.authStateStream {
            self.isAuthenticated = state.isAuthenticated
            self.currentUserHandle = state.currentUserHandle
        }
    }

    /// Throws AuthError if login fails - caller should handle and show appropriate UI
    func login() async throws {
        try await authService.login()
    }

    func logout() async {
        await authService.logout()
    }

    func deleteAccountRequested() async {

    }

    /// Get a valid access token, refreshing if necessary
    /// Returns nil if session expired - UI will automatically show login via state stream
    func getValidAccessToken() async -> String? {
        return await authService.getValidAccessToken()
    }

    #if DEBUG
    func testRefreshToken() async {
        AppLogger.auth.info("Testing refresh token - forcing refresh by deleting access token...")

        // Will trigger refresh
        guard let _ = try? await authService.refreshAccessToken() else {
            AppLogger.auth.error("Refresh failed - refresh token likely expired")
            return
        }

        AppLogger.auth.info("Successfully refreshed access token")
    }
    #endif
}
