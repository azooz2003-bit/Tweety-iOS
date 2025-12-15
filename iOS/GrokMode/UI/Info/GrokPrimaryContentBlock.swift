//
//  GrokPrimaryContentBlock.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI
internal import os

struct TweetMetrics {
    let likes: Int
    let retweets: Int
    let views: Int
}

struct GrokPrimaryContentBlock: View {
    let sourceIcon: ImageResource = ImageResource(name: "X", bundle: .main)
    let profileImageUrl: String?  // URL to profile image
    let displayName: String
    let username: String
    let text: String
    let mediaUrls: [String]?
    let metrics: TweetMetrics?  // Engagement metrics
    let tweetUrl: String?  // Deep link URL

    var body: some View {
        #if DEBUG
        let _ = {
            AppLogger.ui.debug("===== RENDERING TWEET CARD =====")
            AppLogger.ui.debug("Display Name: \(displayName)")
            AppLogger.ui.debug("Username: @\(username)")
            AppLogger.ui.debug("Profile Image URL: \(profileImageUrl ?? "NIL")")
            AppLogger.ui.debug("Text Length: \(text.count) chars")
            AppLogger.ui.debug("Media URLs: \(mediaUrls?.count ?? 0)")
            AppLogger.ui.debug("Metrics: \(metrics != nil ? "PRESENT" : "NIL")")
            metrics.map { m in
                AppLogger.ui.debug("  - Rendering Likes: \(m.likes)")
                AppLogger.ui.debug("  - Rendering Retweets: \(m.retweets)")
                AppLogger.ui.debug("  - Rendering Views: \(m.views)")
            }
            AppLogger.ui.debug("Tweet URL: \(tweetUrl != nil ? "YES" : "NO")")
            AppLogger.ui.debug("===========================")
        }()
        #endif

        VStack(alignment: .center, spacing: 12) {
            // Top: User icon and name centered and stacked
            VStack(spacing: 6) {
                // Profile image with AsyncImage or fallback to X icon
                Group {
                    imageView()
                }
                .background(.white.opacity(0.3))
                .clipShape(Circle())

                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text("@\(username)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)

            // Middle: Tweet text content with max height
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, maxHeight: 200, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)

            // Image Grid (if media exists)
            if let mediaUrls = mediaUrls, !mediaUrls.isEmpty {
                mediaGrid(urls: mediaUrls)
            }

            bottomInfo()
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.primaryChatItemBackground.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if let urlString = tweetUrl, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }
    }

    // Format large numbers (e.g., 1234 -> "1.2K", 1234567 -> "1.2M")
    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }

    @ViewBuilder
    private func bottomInfo() -> some View {
        // Bottom: Engagement metrics
        if let metrics = metrics {
            HStack(spacing: 16) {
                // Views
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 11))
                    Text(formatCount(metrics.views))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.primary.opacity(0.9))

                // Retweets
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 11))
                    Text(formatCount(metrics.retweets))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.primary.opacity(0.9))

                // Likes
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .font(.system(size: 11))
                    Text(formatCount(metrics.likes))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.primary.opacity(0.9))

                Spacer()

                // X source icon
                Image(sourceIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .opacity(0.8)
            }
        } else {
            // Fallback if no metrics
            HStack {
                Spacer()
                Image(sourceIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .opacity(0.8)
            }
        }
    }

    @ViewBuilder
    private func imageView() -> some View {
        if let urlString = profileImageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 50, height: 50)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                case .failure:
                    Image(sourceIcon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                @unknown default:
                    Image(sourceIcon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                }
            }
        } else {
            Image(sourceIcon)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private func mediaGrid(urls: [String]) -> some View {
        let columns = urls.count == 1 ? 1 : 2
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: 8), count: columns)

        LazyVGrid(columns: gridItems, spacing: 8) {
            ForEach(Array(urls.prefix(4).enumerated()), id: \.offset) { index, urlString in
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 150)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 150)
                                .clipped()
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                                .frame(height: 150)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 150)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        ScrollView{
            VStack(spacing: 24){
                Spacer()
                
                GrokPrimaryContentBlock(
                    profileImageUrl: nil,  // Will show X icon as fallback
                    displayName: "Elon Musk",
                    username: "elonmusk",
                    text: "Just had a great conversation with Grok about the future of AI and space exploration. The possibilities are endless when you combine these technologies!",
                    mediaUrls: nil,
                    metrics: TweetMetrics(likes: 12500, retweets: 3400, views: 150000),
                    tweetUrl: "https://twitter.com/elonmusk/status/1234567890"
                )
                
                
                GrokPrimaryContentBlock(
                    profileImageUrl: nil,  // Will show X icon as fallback
                    displayName: "Elon Musk",
                    username: "elonmusk",
                    text: "Just had a great conversation with Grok about the future of AI and space exploration. The possibilities are endless when you combine these technologies!",
                    mediaUrls: nil,
                    metrics: TweetMetrics(likes: 12500, retweets: 3400, views: 150000),
                    tweetUrl: "https://twitter.com/elonmusk/status/1234567890"
                )
                
                
                
                
                GrokPrimaryContentBlock(
                    profileImageUrl: nil,  // Will show X icon as fallback
                    displayName: "Elon Musk",
                    username: "elonmusk",
                    text: "Just had a great conversation with Grok about the future of AI and space exploration. The possibilities are endless when you combine these technologies!",
                    mediaUrls: nil,
                    metrics: TweetMetrics(likes: 12500, retweets: 3400, views: 150000),
                    tweetUrl: "https://twitter.com/elonmusk/status/1234567890"
                )
                
                
                Spacer()
            }}
    }
}
