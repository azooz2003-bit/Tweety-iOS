//
//  XTweet.swift
//  Tweety
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
    let referenced_tweets: [ReferencedTweet]?

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

    struct ReferencedTweet: Codable, Sendable {
        let type: String  // "retweeted", "quoted", "replied_to"
        let id: String
    }

    // Helper to check if this is a retweet
    var isRetweet: Bool {
        referenced_tweets?.contains { $0.type == "retweeted" } ?? false
    }

    // Get the ID of the retweeted tweet
    var retweetedTweetId: String? {
        referenced_tweets?.first { $0.type == "retweeted" }?.id
    }

    // Helper to check if this is a quote tweet
    var isQuoteTweet: Bool {
        referenced_tweets?.contains { $0.type == "quoted" } ?? false
    }

    // Get the ID of the quoted tweet
    var quotedTweetId: String? {
        referenced_tweets?.first { $0.type == "quoted" }?.id
    }
}
