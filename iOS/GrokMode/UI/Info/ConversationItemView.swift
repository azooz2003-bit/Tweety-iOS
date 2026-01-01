//
//  ConversationItemView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import SwiftUI
internal import os

struct ConversationItemView: View {
    let item: ConversationItem
    let imageCache: ImageCache

    var body: some View {
        Group {
            switch item.type {
            case .userSpeech(let transcript):
                UserSpeechBubble(transcript: transcript, timestamp: item.timestamp)

            case .assistantSpeech(let text):
                AssistantSpeechBubble(text: text, timestamp: item.timestamp)

            case .tweet(let enrichedTweet):
                TweetConversationCard(enrichedTweet: enrichedTweet, imageCache: imageCache)

            case .tweets(let tweets):
                TweetsBatchPreview(tweets: tweets, imageCache: imageCache)

            case .toolCall(let name, let status):
                ToolCallIndicator(toolName: name, status: status, timestamp: item.timestamp)

            case .systemMessage(let message):
                SystemMessageBubble(message: message, timestamp: item.timestamp)
            }
        }
    }
}

// MARK: - Subviews

struct UserSpeechBubble: View {
    let transcript: String
    let timestamp: Date

    var body: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(transcript)
                    .padding(12)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(16)

                Text(formatTime(timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AssistantSpeechBubble: View {
    let text: String
    let timestamp: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(.grok)
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("Gerald")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Text(text)
                    .padding(12)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(16)

                Text(formatTime(timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            Spacer()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TweetConversationCard: View {
    let enrichedTweet: EnrichedTweet
    let imageCache: ImageCache

    var body: some View {
        PrimaryContentBlock(
            profileImageUrl: enrichedTweet.author?.profile_image_url,
            displayName: enrichedTweet.author?.name ?? "Unknown",
            username: enrichedTweet.author?.username ?? "unknown",
            text: enrichedTweet.displayText,
            media: enrichedTweet.media.isEmpty ? nil : enrichedTweet.media,
            metrics: tweetMetrics,
            tweetUrl: tweetUrl,
            retweeterName: enrichedTweet.retweetInfo?.retweeter.name,
            quotedTweet: quotedTweetData,
            imageCache: imageCache
        )
        .listRowSeparator(.hidden)
        .padding(.vertical, 4)
    }

    private var quotedTweetData: PrimaryContentBlock.QuotedTweetData? {
        guard let quotedTweet = enrichedTweet.quotedTweet else { return nil }
        return PrimaryContentBlock.QuotedTweetData(
            authorName: quotedTweet.author.name,
            authorUsername: quotedTweet.author.username,
            text: quotedTweet.text,
            media: quotedTweet.media.isEmpty ? nil : quotedTweet.media
        )
    }

    private var tweetMetrics: TweetMetrics? {
        #if DEBUG
        AppLogger.ui.debug("===== UI: RENDERING TWEET =====")
        AppLogger.ui.debug("Tweet ID: \(enrichedTweet.tweet.id)")
        AppLogger.ui.debug("Tweet Text: \(String(enrichedTweet.displayText.prefix(50)))...")
        AppLogger.ui.debug("Author: \(enrichedTweet.author?.username ?? "nil")")
        AppLogger.ui.debug("Profile Image URL: \(enrichedTweet.author?.profile_image_url ?? "NIL")")
        AppLogger.ui.debug("Media URLs: \(enrichedTweet.media.count)")
        AppLogger.ui.debug("Public Metrics Object: \(enrichedTweet.tweet.public_metrics != nil ? "EXISTS" : "NIL")")
        #endif

        guard let publicMetrics = enrichedTweet.tweet.public_metrics else {
            #if DEBUG
            AppLogger.ui.debug("✗ NO METRICS - Will not display engagement stats")
            #endif
            return nil
        }

        let metrics = TweetMetrics(
            likes: publicMetrics.like_count ?? 0,
            retweets: publicMetrics.retweet_count ?? 0,
            views: publicMetrics.impression_count ?? 0
        )

        #if DEBUG
        AppLogger.ui.debug("✓ Metrics Created:")
        AppLogger.ui.debug("  - Likes: \(metrics.likes)")
        AppLogger.ui.debug("  - Retweets: \(metrics.retweets)")
        AppLogger.ui.debug("  - Views: \(metrics.views)")
        #endif

        return metrics
    }

    private var tweetUrl: String? {
        if let retweetInfo = enrichedTweet.retweetInfo {
            let url = "https://twitter.com/\(retweetInfo.retweeter.username)/status/\(retweetInfo.retweetId)"
            #if DEBUG
            AppLogger.ui.debug("✓ Retweet URL: \(url)")
            #endif
            return url
        }

        guard let username = enrichedTweet.author?.username else {
            #if DEBUG
            AppLogger.ui.debug("✗ Cannot create URL - no author username")
            #endif
            return nil
        }
        let url = "https://twitter.com/\(username)/status/\(enrichedTweet.tweet.id)"
        #if DEBUG
        AppLogger.ui.debug("✓ Tweet URL: \(url)")
        #endif
        return url
    }
}

struct ToolCallIndicator: View {
    let toolName: String
    let status: ToolCallStatus
    let timestamp: Date

    var body: some View {
        HStack(spacing: 8) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedToolName)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(formatTime(timestamp))
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(8)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private var formattedToolName: String {
        if let tool = XTool(rawValue: toolName) {
            return tool.displayName
        }
        return toolName
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private var statusIcon: some View {
        Group {
            switch status {
            case .pending:
                Image(systemName: "clock.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.blue)
                    .scaleEffect(0.7)
            case .approved:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .rejected:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .executed(let success):
                Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(success ? .green : .orange)
            }
        }
    }

    private var statusText: String {
        switch status {
        case .pending: return "Awaiting approval"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .executed(let success): return success ? "Completed" : "Failed"
        }
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .blue
        case .approved: return .green
        case .rejected: return .red
        case .executed(let success): return success ? .green : .orange
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct SystemMessageBubble: View {
    let message: String
    let timestamp: Date

    var body: some View {
        HStack {
            Spacer()

            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            Spacer()
        }
        .padding(.horizontal)
    }
}

#Preview {
    let imageCache = ImageCache()
    VStack(spacing: 20) {
        ConversationItemView(item: ConversationItem(
            timestamp: Date(),
            type: .systemMessage("Connected to XAI Voice")
        ), imageCache: imageCache)

        ConversationItemView(item: ConversationItem(
            timestamp: Date(),
            type: .toolCall(name: "search_recent_tweets", status: .pending)
        ), imageCache: imageCache)

        ConversationItemView(item: ConversationItem(
            timestamp: Date(),
            type: .tweet(
                EnrichedTweet(
                    from: XTweet(
                        id: "1",
                        text: "This is a test tweet https://t.co/abc123",
                        author_id: "1",
                        created_at: nil,
                        attachments: nil,
                        public_metrics: XTweet.PublicMetrics(
                            retweet_count: 100,
                            reply_count: 50,
                            like_count: 500,
                            quote_count: 20,
                            impression_count: 10000,
                            bookmark_count: 30
                        ),
                        referenced_tweets: nil
                    ),
                    includes: XTweetResponse.Includes(
                        users: [XUser(id: "1", name: "Test User", username: "testuser", profile_image_url: nil)],
                        media: nil,
                        tweets: nil
                    )
                )
            )
        ), imageCache: imageCache)
    }
}


#Preview("Fetched post preview") {
    VStack {
        Button {
            print("Submitted")
        } label: {
            ConversationItemView(item: .init(timestamp: .now, type: .tweets([
                EnrichedTweet(
                    from: XTweet(
                        id: "1",
                        text: "This is a test tweet https://t.co/abc123",
                        author_id: "1",
                        created_at: nil,
                        attachments: nil,
                        public_metrics: XTweet.PublicMetrics(
                            retweet_count: 100,
                            reply_count: 50,
                            like_count: 500,
                            quote_count: 20,
                            impression_count: 10000,
                            bookmark_count: 30
                        ),
                        referenced_tweets: nil
                    ),
                    includes: XTweetResponse.Includes(
                        users: [XUser(id: "1", name: "Test User", username: "testuser", profile_image_url: nil)],
                        media: nil,
                        tweets: nil
                    )
                )
            ])), imageCache: .init())
        }
        .buttonStyle(.plain)
        .padding()
    }
}
