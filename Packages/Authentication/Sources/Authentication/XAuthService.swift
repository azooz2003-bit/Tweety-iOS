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

// MARK: - Auth Presentation Provider
final class AuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Auth Error
public enum AuthError: Error, Sendable {
    // Configuration/Programming errors
    case missingClientID
    case invalidURL

    // User-actionable errors
    case loginCancelled
    case loginFailed(String)
    case networkError(String)
}

// MARK: - Auth State
public struct AuthState: Sendable {
    public let isAuthenticated: Bool
    public let currentUserHandle: String?

    public init(isAuthenticated: Bool, currentUserHandle: String?) {
        self.isAuthenticated = isAuthenticated
        self.currentUserHandle = currentUserHandle
    }
}

// MARK: - XAuthService
public actor XAuthService {

    private(set) var authState = AuthState(isAuthenticated: false, currentUserHandle: nil) {
        didSet {
            stateContinuation.yield(authState)
        }
    }

    // Convenience accessors
    var isAuthenticated: Bool { authState.isAuthenticated }
    var currentUserHandle: String? { authState.currentUserHandle }

    private let callbackScheme = "grokmode"
    @MainActor private var authSession: ASWebAuthenticationSession?
    private let presentationProvider: AuthPresentationProvider

    // PKCE Components
    private var codeVerifier: String?

    // Config
    private var clientId: String {
        return Bundle.main.infoDictionary?["X_CLIENT_ID"] as? String ?? ""
    }

    // Storage
    private let tokenKey = "x_user_access_token"
    private let refreshTokenKey = "x_user_refresh_token"
    private let handleKey = "x_user_handle"
    private let tokenExpiryKey = "x_token_expiry_date"

    // AsyncStream for state changes
    private let stateContinuation: AsyncStream<AuthState>.Continuation
    public let authStateStream: AsyncStream<AuthState>

    // Optional event handlers
    public var onTokenRefreshed: (() -> Void)?

    @MainActor
    public init() {
        // Create AsyncStream using makeStream() for Swift 6 concurrency safety
        let (stream, continuation) = AsyncStream<AuthState>.makeStream()
        self.authStateStream = stream
        self.stateContinuation = continuation
        self.presentationProvider = AuthPresentationProvider()
    }

    public func checkStatus() {
        if let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty {
            authState = AuthState(
                isAuthenticated: true,
                currentUserHandle: UserDefaults.standard.string(forKey: handleKey)
            )
        } else {
            authState = AuthState(isAuthenticated: false, currentUserHandle: nil)
        }
    }

    public func login() async throws {
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
            URLQueryItem(name: "scope", value: "tweet.read tweet.write users.read dm.read dm.write offline.access"),
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

        let url = URL(string: "https://api.twitter.com/2/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "grant_type": "authorization_code",
            "client_id": clientId,
            "redirect_uri": "grokmode://",
            "code_verifier": verifier
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AuthError.loginFailed("Token exchange failed: \(errorMessage)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                throw AuthError.loginFailed("Invalid token response")
            }

            let refreshToken = json["refresh_token"] as? String
            let expiresIn = json["expires_in"] as? Int ?? 7200

            // Calculate expiry date
            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))

            // Save Token
            UserDefaults.standard.set(accessToken, forKey: self.tokenKey)
            UserDefaults.standard.set(expiryDate, forKey: self.tokenExpiryKey)
            if let rt = refreshToken {
                UserDefaults.standard.set(rt, forKey: self.refreshTokenKey)
            }
            authState = AuthState(isAuthenticated: true, currentUserHandle: authState.currentUserHandle)

            // Fetch user info (non-critical, don't throw if it fails)
            await fetchCurrentUser()
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    private func fetchCurrentUser() async {
        // Non-critical - silently fail if we can't get user info
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else { return }

        let url = URL(string: "https://api.twitter.com/2/users/me")!
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let username = dataObj["username"] as? String else {
                return  // Silently fail - we're still authenticated
            }

            let handle = "@\(username)"
            UserDefaults.standard.set(handle, forKey: self.handleKey)
            authState = AuthState(isAuthenticated: authState.isAuthenticated, currentUserHandle: handle)
        } catch {
            // Silently fail - user info is non-critical
        }
    }

    public func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: handleKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
        authState = AuthState(isAuthenticated: false, currentUserHandle: nil)
    }

    public func getAccessToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey)
    }

    /// Get a valid access token, refreshing if necessary
    /// Returns nil if session expired - UI will automatically show login via state stream
    public func getValidAccessToken() async -> String? {
        // Check if token exists
        guard let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty else {
            return nil  // Already logged out, state stream will notify UI
        }

        // Check if token is expired or about to expire (within 5 minutes)
        if isTokenExpired() {
            // Auto-refresh token
            do {
                let refreshed = try await refreshAccessToken()
                return refreshed
            } catch {
                // Auto-handle: logout and let state stream notify UI
                self.logout()
                return nil
            }
        }

        return token
    }

    /// Check if the current token is expired or about to expire
    private func isTokenExpired() -> Bool {
        guard let expiryDate = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date else {
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
    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) else {
            // No refresh token - session expired, will be handled by caller
            throw AuthError.networkError("No refresh token available")
        }

        let url = URL(string: "https://api.twitter.com/2/oauth2/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
            "client_id": clientId
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

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

            // Update stored tokens
            UserDefaults.standard.set(accessToken, forKey: self.tokenKey)
            UserDefaults.standard.set(expiryDate, forKey: self.tokenExpiryKey)
            if let rt = newRefreshToken {
                UserDefaults.standard.set(rt, forKey: self.refreshTokenKey)
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
