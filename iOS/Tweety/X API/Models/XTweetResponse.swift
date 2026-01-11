//
//  XTweetResponse.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/25/25.
//

import Foundation

/// Standard X API v2 response structure for tweet endpoints
struct XTweetResponse: Codable, Sendable {
    let data: [XTweet]?
    let includes: Includes?
    let meta: Meta?

    /// Related data included in the response (users, media, referenced tweets)
    struct Includes: Codable, Sendable {
        let users: [XUser]?
        let media: [XMedia]?
        let tweets: [XTweet]?
    }

    /// Response metadata including pagination tokens
    struct Meta: Codable, Sendable {
        let next_token: String?
        let previous_token: String?
        let result_count: Int?

        /// Check if more results are available
        var hasMore: Bool {
            next_token != nil
        }
    }
}

/// Single tweet response (for create, delete operations)
struct XSingleTweetResponse: Codable, Sendable {
    let data: XTweet
    let includes: XTweetResponse.Includes?
}
