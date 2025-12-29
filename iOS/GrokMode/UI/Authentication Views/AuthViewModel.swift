//
//  AuthViewModel.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/8/25.
//

import Foundation
import UIKit

@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUserHandle: String?

    let authService = XAuthService(authPresentationProvider: .init())

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

    /// Get a valid access token, refreshing if necessary
    /// Returns nil if session expired - UI will automatically show login via state stream
    func getValidAccessToken() async -> String? {
        return await authService.getValidAccessToken()
    }
}
