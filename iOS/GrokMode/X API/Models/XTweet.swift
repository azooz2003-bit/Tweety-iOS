//
//  XTweet.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/14/25.
//

struct XTweet: Codable, Identifiable, Sendable {
    let id: String
    let text: String
    let author_id: String?
    let created_at: String?
    let attachments: Attachments?
    let public_metrics: PublicMetrics?

    struct Attachments: Codable, Sendable {
        let media_keys: [String]?
    }

    struct PublicMetrics: Codable, Sendable {
        let retweet_count: Int?
        let reply_count: Int?
        let like_count: Int?
        let quote_count: Int?
        let impression_count: Int?  // Views
        let bookmark_count: Int?
    }
}
