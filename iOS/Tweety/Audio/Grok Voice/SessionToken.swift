//
//  SessionToken.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/11/25.
//

import Foundation

nonisolated
struct SessionToken: Codable {
    let value: String
    let expiresAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case value
        case expiresAt = "expires_at"
    }
}
