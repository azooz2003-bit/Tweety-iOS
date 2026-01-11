//
//  KeychainKeys.swift
//  Tweety
//

import Foundation

nonisolated
enum KeychainKeys {
    // Authentication
    static let tokenKey = "x_user_access_token"
    static let refreshTokenKey = "x_user_refresh_token"
    static let handleKey = "x_user_handle"
    static let userIdKey = "x_user_id"
    static let tokenExpiryKey = "x_token_expiry_date"

    // App Attest
    static let appAttestKeyId = "app_attest_key_id"
}
