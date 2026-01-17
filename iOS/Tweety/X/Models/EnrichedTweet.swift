//
//  EnrichedTweet.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/25/25.
//

import Foundation

/// A tweet enriched with all related data (author, media, quoted tweets, retweets)
/// Resolves all ID references from the API response includes
struct EnrichedTweet: Sendable {
    /// The actual tweet to display (unwrapped from retweet if applicable)
    let tweet: XTweet

    /// Author of the tweet
    let author: XUser?

    /// Resolved media attachments
    let media: [XMedia]

    /// Information about the retweet (if this tweet is a retweet)
    let retweetInfo: RetweetInfo?

    /// Information about the quoted tweet (if this tweet quotes another)
    let quotedTweet: QuotedTweetInfo?

    /// Display text with trailing t.co links removed (computed once at init)
    /// Twitter adds t.co links for media and quoted tweets which are redundant when displayed
    let displayText: String

    init(from tweetData: XTweet, includes: XTweetResponse.Includes?) {
        var displayTweet = tweetData
        var retweetInfo: RetweetInfo? = nil

        // Handle retweets
        if tweetData.isRetweet,
           let retweetedId = tweetData.retweetedTweetId,
           let originalTweet = includes?.tweets?.first(where: { $0.id == retweetedId }) {
            displayTweet = originalTweet
            let retweeter = includes?.users?.first { $0.id == tweetData.author_id }
            retweetInfo = retweeter.map {
                RetweetInfo(retweeter: $0, retweetId: tweetData.id, originalTweet: originalTweet)
            }
        }

        // Resolve author and media for the display tweet
        let author = includes?.users?.first { $0.id == displayTweet.author_id }
        let media = displayTweet.attachments?.media_keys?.compactMap { key in
            includes?.media?.first { $0.media_key == key }
        } ?? []

        // Handle quoted tweets
        var quotedTweetInfo: QuotedTweetInfo? = nil
        if displayTweet.isQuoteTweet,
           let quotedId = displayTweet.quotedTweetId,
           let quotedTweetData = includes?.tweets?.first(where: { $0.id == quotedId }),
           let quotedAuthor = includes?.users?.first(where: { $0.id == quotedTweetData.author_id }) {
            let quotedMedia = quotedTweetData.attachments?.media_keys?.compactMap { key in
                includes?.media?.first { $0.media_key == key }
            } ?? []
            quotedTweetInfo = QuotedTweetInfo(
                author: quotedAuthor,
                text: quotedTweetData.text,
                media: quotedMedia
            )
        }

        self.tweet = displayTweet
        self.author = author
        self.media = media
        self.retweetInfo = retweetInfo
        self.quotedTweet = quotedTweetInfo

        // Remove trailing t.co link
        self.displayText = displayTweet.text.replacingOccurrences(
            of: #"\s*https://t\.co/\w+\s*$"#,
            with: "",
            options: .regularExpression
        )
    }
}

/// Information about a retweet
struct RetweetInfo: Sendable {
    let retweeter: XUser
    let retweetId: String
    let originalTweet: XTweet
}

/// Information about a quoted tweet
struct QuotedTweetInfo: Sendable {
    let author: XUser
    let text: String
    let media: [XMedia]
}
