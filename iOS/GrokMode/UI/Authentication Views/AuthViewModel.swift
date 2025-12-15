//
//  AuthViewModel.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/8/25.
//

import Foundation
import UIKit

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUserHandle: String?

    let authService = XAuthService(authPresentationProvider: .init())

    /// Start observing auth state changes
    /// Call this from a view's .task {} modifier to tie lifecycle to view
    func startObserving() async {
        // Check initial status to emit current state
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

    /// Get a valid access token, refreshing if necessary
    /// Returns nil if session expired - UI will automatically show login via state stream
    func getValidAccessToken() async -> String? {
        return await authService.getValidAccessToken()
    }
}
