//
//  XAuthService.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import Foundation
@preconcurrency import AuthenticationServices
import CommonCrypto
import Combine
internal import os

final class AuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

enum AuthError: Error, Sendable {
    // Configuration/Programming errors
    case missingClientID
    case invalidURL

    // User-actionable errors
    case loginCancelled
    case loginFailed(String)
    case networkError(String)
}

nonisolated
struct AuthState: Sendable {
    public let isAuthenticated: Bool
    public let userId: String?
    public let currentUserHandle: String?

    public init(isAuthenticated: Bool, userId: String? = nil, currentUserHandle: String? = nil) {
        self.isAuthenticated = isAuthenticated
        self.userId = userId
        self.currentUserHandle = currentUserHandle
    }

    static func loadFromKeychain() -> AuthState {
        let keychain = KeychainHelper.shared
        let token = keychain.unsafeGetString(for: KeychainKeys.tokenKey)

        if let token = token, !token.isEmpty {
            let userId = keychain.unsafeGetString(for: KeychainKeys.userIdKey)
            let handle = keychain.unsafeGetString(for: KeychainKeys.handleKey)
            return AuthState(isAuthenticated: true, userId: userId, currentUserHandle: handle)
        } else {
            return AuthState(isAuthenticated: false, userId: nil, currentUserHandle: nil)
        }
    }
}

public actor XAuthService {
    private struct TwitterUserResponse: Codable {
        let data: TwitterUser
    }

    private struct TwitterUser: Codable {
        let id: String
        let username: String
    }

    private(set) var authState = AuthState(isAuthenticated: false, userId: nil, currentUserHandle: nil) {
        didSet {
            stateContinuation.yield(authState)
        }
    }

    var isAuthenticated: Bool { authState.isAuthenticated }
    var userId: String? { authState.userId }
    var currentUserHandle: String? { authState.currentUserHandle }

    /// Get the current user ID, throwing if not authenticated
    var requiredUserId: String {
        get throws {
            guard let userId = authState.userId else {
                throw AuthError.loginFailed("User not authenticated")
            }
            return userId
        }
    }

    private let callbackScheme = "grokmode"
    @MainActor private var authSession: ASWebAuthenticationSession?
    private let presentationProvider: AuthPresentationProvider

    // PKCE Components
    private var codeVerifier: String?

    private var clientId: String {
        return Bundle.main.infoDictionary?["X_CLIENT_ID"] as? String ?? ""
    }

    private let keychain = KeychainHelper.shared
    private let appAttestService: AppAttestService

    /// URL to exchange auth code for refresh & access token
    private let tokenURL: URL = Config.baseXProxyURL.appending(path: "oauth2/token")
    /// URL to get new access token using existing refesh token
    private let refreshURL: URL = Config.baseXProxyURL.appending(path: "oauth2/refresh")

    private let stateContinuation: AsyncStream<AuthState>.Continuation
    let authStateStream: AsyncStream<AuthState>

    var onTokenRefreshed: (() -> Void)?

    init(authPresentationProvider: AuthPresentationProvider, appAttestService: AppAttestService) {
        let (stream, continuation) = AsyncStream<AuthState>.makeStream()
        self.authStateStream = stream
        self.stateContinuation = continuation
        self.presentationProvider = authPresentationProvider
        self.appAttestService = appAttestService
        self.authState = AuthState.loadFromKeychain()
    }

    func checkStatus() async {
        if let token = await keychain.getString(for: KeychainKeys.tokenKey), !token.isEmpty {
            authState = AuthState(
                isAuthenticated: true,
                userId: await keychain.getString(for: KeychainKeys.userIdKey),
                currentUserHandle: await keychain.getString(for: KeychainKeys.handleKey)
            )
        } else {
            authState = AuthState(isAuthenticated: false, userId: nil, currentUserHandle: nil)
        }
    }

    func login() async throws {
        // Programming error - should never happen in production
        guard !clientId.isEmpty else {
            assertionFailure("X_CLIENT_ID not configured in Info.plist")
            throw AuthError.missingClientID
        }

        // 1. Generate PKCE Verifier & Challenge
        let verifier = generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        // 2. Build Auth URL
        var components = URLComponents(string: "https://twitter.com/i/oauth2/authorize")!
        let state = UUID().uuidString

        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: "grokmode://"),
            URLQueryItem(name: "scope", value: "tweet.read tweet.write tweet.moderate.write users.email users.read follows.read follows.write space.read mute.read mute.write like.read like.write list.read list.write block.read block.write bookmark.read bookmark.write media.write dm.read dm.write offline.access"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        // Programming error - URL construction should never fail with static components
        guard let authURL = components.url else {
            assertionFailure("Failed to construct auth URL - check URL components")
            throw AuthError.invalidURL
        }

        // 3. Create and Start Session - this will throw on user error
        try await performAuthSession(with: authURL)
    }

    private func performAuthSession(with authURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task { @MainActor in
                let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: self.callbackScheme) { [weak self] callbackURL, error in
                    guard let self = self else { return }

                    if let error = error {
                        let authError: AuthError = (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue
                            ? .loginCancelled
                            : .loginFailed(error.localizedDescription)
                        continuation.resume(throwing: authError)
                        return
                    }

                    guard let callbackURL = callbackURL else {
                        continuation.resume(throwing: AuthError.loginFailed("No callback URL"))
                        return
                    }

                    // Handle callback and complete login
                    Task {
                        do {
                            try await self.handleCallback(url: callbackURL)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }

                self.authSession = session
                session.presentationContextProvider = self.presentationProvider
                session.prefersEphemeralWebBrowserSession = true
                session.start()
            }
        }
    }

    private func handleCallback(url: URL) async throws {
        // Extract code
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value else {
            throw AuthError.loginFailed("Missing authorization code")
        }

        // Exchange Code for Token
        try await exchangeCodeForToken(code: code)
    }

    private func exchangeCodeForToken(code: String) async throws {
        // Logic error - we should always have a code verifier at this point
        guard let verifier = self.codeVerifier else {
            assertionFailure("Code verifier missing - this indicates a logic error in the auth flow")
            throw AuthError.loginFailed("Internal error: missing code verifier")
        }

        let url = self.tokenURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let bodyParams: [String: String] = [
            "code": code,
            "redirect_uri": "grokmode://",
            "code_verifier": verifier
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams)

        var isRetry = false
        let maxRetries = 1
        var currentAttempt = 0
        var data: Data?

        while currentAttempt <= maxRetries {
            do {
                try await request.addAppAttestHeaders(appAttestService: appAttestService, isRetry: isRetry)

                let (responseData, response) = try await URLSession.shared.data(for: request)

                guard let urlResponse = response as? HTTPURLResponse else {
                    throw AuthError.loginFailed("Invalid response type")
                }

                AppLogger.auth.debug("Token exchange response status: \(urlResponse.statusCode)")
                AppLogger.logSensitive(AppLogger.auth, level: .debug, "Response body:\n\(AppLogger.prettyJSON(responseData))")

                if urlResponse.statusCode == 403 && currentAttempt < maxRetries {
                    AppLogger.auth.warning("Attestation rejected (403), clearing and retrying...")
                    await URLRequest.handleAttestationExpired(appAttestService: appAttestService)
                    isRetry = true
                    currentAttempt += 1
                    continue
                }

                guard urlResponse.statusCode == 200 else {
                    let errorMessage = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                    throw AuthError.loginFailed("Token exchange failed (Status \(urlResponse.statusCode)): \(errorMessage)")
                }

                data = responseData
                break
            } catch {
                if currentAttempt < maxRetries {
                    currentAttempt += 1
                    continue
                }
                throw error
            }
        }

        guard let data else {
            throw AuthError.loginFailed("(shouldn't happen) No token data received.")
        }

        do {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                throw AuthError.loginFailed("Invalid token response")
            }

            let refreshToken = json["refresh_token"] as? String
            let expiresIn = json["expires_in"] as? Int ?? 7200

            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))

            try await keychain.save(accessToken, for: KeychainKeys.tokenKey)
            try await keychain.save(expiryDate, for: KeychainKeys.tokenExpiryKey)
            if let rt = refreshToken {
                try await keychain.save(rt, for: KeychainKeys.refreshTokenKey)
            }

            // This sets authState with isAuthenticated=true + userId atomically
            try await fetchCurrentUser()
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    private func fetchCurrentUser() async throws {
        // CRITICAL - must succeed to get X user_id for credits system
        guard let token = await keychain.getString(for: KeychainKeys.tokenKey) else {
            throw AuthError.loginFailed("No access token available")
        }

        let url = URL(string: "https://api.twitter.com/2/users/me")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthError.loginFailed("Failed to fetch user info")
        }

        let userResponse = try JSONDecoder().decode(TwitterUserResponse.self, from: data)
        let user = userResponse.data

        // Store both user_id (permanent) and username (display) in Keychain
        try await keychain.save(user.id, for: KeychainKeys.userIdKey)
        try await keychain.save(user.username, for: KeychainKeys.handleKey)

        authState = AuthState(
            isAuthenticated: true,
            userId: user.id,
            currentUserHandle: user.username
        )
    }

    public func logout() async {
        await keychain.delete(KeychainKeys.tokenKey)
        await keychain.delete(KeychainKeys.refreshTokenKey)
        await keychain.delete(KeychainKeys.handleKey)
        await keychain.delete(KeychainKeys.userIdKey)
        await keychain.delete(KeychainKeys.tokenExpiryKey)
        authState = AuthState(isAuthenticated: false, userId: nil, currentUserHandle: nil)
    }

    public func getAccessToken() async -> String? {
        return await keychain.getString(for: KeychainKeys.tokenKey)
    }

    /// Get a valid access token, refreshing if necessary
    /// Returns nil if session expired - UI will automatically show login via state stream
    public func getValidAccessToken() async -> String? {
        // Check if token exists
        guard let token = await keychain.getString(for: KeychainKeys.tokenKey), !token.isEmpty else {
            return nil  // Already logged out, state stream will notify UI
        }

        // Check if token is expired or about to expire (within 5 minutes)
        if await isTokenExpired() {
            // Auto-refresh token
            do {
                let refreshed = try await refreshAccessToken()
                return refreshed
            } catch {
                // Auto-handle: logout and let state stream notify UI
                await self.logout()
                return nil
            }
        }

        return token
    }

    /// Check if the current token is expired or about to expire
    private func isTokenExpired() async -> Bool {
        guard let expiryDate = await keychain.getDate(for: KeychainKeys.tokenExpiryKey) else {
            // No expiry date stored, assume expired for safety
            return true
        }

        // Consider expired if within 5 minutes of expiry
        let bufferTime: TimeInterval = 300 // 5 minutes
        return Date().addingTimeInterval(bufferTime) >= expiryDate
    }

    /// Refresh the access token using the refresh token
    /// Auto-handles token refresh internally
    /// Throws network errors - session expiry is auto-handled via logout
    func refreshAccessToken() async throws -> String {
        guard let refreshToken = await keychain.getString(for: KeychainKeys.refreshTokenKey) else {
            // No refresh token - session expired, will be handled by caller
            throw AuthError.networkError("No refresh token available")
        }

        guard let userId = authState.userId else {
            throw AuthError.networkError("No user ID available")
        }

        let url = self.refreshURL
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")

        let bodyParams: [String: String] = [
            "refresh_token": refreshToken
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: bodyParams)
        try await request.addAppAttestHeaders(appAttestService: appAttestService)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                // Refresh token expired/invalid - throw to trigger logout in caller
                let errorMessage = String(data: data, encoding: .utf8) ?? "Refresh failed"
                throw AuthError.networkError("Token refresh failed: \(errorMessage)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                throw AuthError.networkError("Invalid refresh response")
            }

            let newRefreshToken = json["refresh_token"] as? String
            let expiresIn = json["expires_in"] as? Int ?? 7200
            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))

            // Update stored tokens in Keychain
            try? await keychain.save(accessToken, for: KeychainKeys.tokenKey)
            try? await keychain.save(expiryDate, for: KeychainKeys.tokenExpiryKey)
            if let rt = newRefreshToken {
                try? await keychain.save(rt, for: KeychainKeys.refreshTokenKey)
            }

            // Notify that token was refreshed (for logging/debugging)
            onTokenRefreshed?()

            return accessToken
        } catch {
            // Network error during refresh
            throw AuthError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - PKCE Helpers

extension XAuthService {

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
