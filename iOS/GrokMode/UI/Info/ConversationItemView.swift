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

    var body: some View {
        Group {
            switch item.type {
            case .userSpeech(let transcript):
                UserSpeechBubble(transcript: transcript, timestamp: item.timestamp)

            case .assistantSpeech(let text):
                AssistantSpeechBubble(text: text, timestamp: item.timestamp)

            case .tweet(let tweet, let author, let mediaUrls):
                TweetConversationCard(tweet: tweet, author: author, mediaUrls: mediaUrls)

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
    let tweet: XTweet
    let author: XUser?
    let mediaUrls: [String]

    var body: some View {
        GrokPrimaryContentBlock(
            profileImageUrl: author?.profile_image_url,
            displayName: author?.name ?? "Unknown",
            username: author?.username ?? "unknown",
            text: tweet.text,
            mediaUrls: mediaUrls.isEmpty ? nil : mediaUrls,
            metrics: tweetMetrics,
            tweetUrl: tweetUrl
        )
        .listRowSeparator(.hidden)
        .padding(.vertical, 4)
    }

    private var tweetMetrics: TweetMetrics? {
        #if DEBUG
        AppLogger.ui.debug("===== UI: RENDERING TWEET =====")
        AppLogger.ui.debug("Tweet ID: \(tweet.id)")
        AppLogger.ui.debug("Tweet Text: \(String(tweet.text.prefix(50)))...")
        AppLogger.ui.debug("Author: \(author?.username ?? "nil")")
        AppLogger.ui.debug("Profile Image URL: \(author?.profile_image_url ?? "NIL")")
        AppLogger.ui.debug("Media URLs: \(mediaUrls.count)")
        AppLogger.ui.debug("Public Metrics Object: \(tweet.public_metrics != nil ? "EXISTS" : "NIL")")
        #endif

        guard let publicMetrics = tweet.public_metrics else {
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
        guard let username = author?.username else {
            #if DEBUG
            AppLogger.ui.debug("✗ Cannot create URL - no author username")
            #endif
            return nil
        }
        let url = "https://twitter.com/\(username)/status/\(tweet.id)"
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
                Text(toolName)
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

    private var statusIcon: some View {
        Group {
            switch status {
            case .pending:
                ProgressView()
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
    VStack(spacing: 20) {
        ConversationItemView(item: ConversationItem(
            timestamp: Date(),
            type: .systemMessage("Connected to XAI Voice")
        ))

        ConversationItemView(item: ConversationItem(
            timestamp: Date(),
            type: .toolCall(name: "search_recent_tweets", status: .executed(success: true))
        ))

        ConversationItemView(item: ConversationItem(
            timestamp: Date(),
            type: .tweet(
                XTweet(
                    id: "1",
                    text: "This is a test tweet",
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
                    
                ),
                author: XUser(id: "1", name: "Test User", username: "testuser", profile_image_url: nil),
                mediaUrls: []
            )
        ))
    }
}
