//
//  AuthViewModel.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/8/25.
//

import Foundation
import Authentication

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUserHandle: String?

    private let authService: XAuthService
    private var observationTask: Task<Void, Never>?

    init(authService: XAuthService) {
        self.authService = authService
        startObserving()
    }

    deinit {
        observationTask?.cancel()
    }

    private func startObserving() {
        observationTask = Task { [weak self] in
            guard let self = self else { return }

            // Check initial status to emit current state
            await authService.checkStatus()

            for await state in await authService.authStateStream {
                guard !Task.isCancelled else { break }
                self.isAuthenticated = state.isAuthenticated
                self.currentUserHandle = state.currentUserHandle
            }
        }
    }

    /// Throws AuthError if login fails - caller should handle and show appropriate UI
    func login() async throws {
        try await authService.login()
    }

    func logout() async {
        await authService.logout()
    }

    func getValidAccessToken() async -> String? {
        return await authService.getValidAccessToken()
    }
}
