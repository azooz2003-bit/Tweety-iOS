//
//  GrokPrimaryContentBlock.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI

struct TweetMetrics {
    let likes: Int
    let retweets: Int
    let views: Int
}

struct GrokPrimaryContentBlock: View {
    let sourceIcon: ImageResource = ImageResource(name: "X", bundle: .main)
    let userIcon: ImageResource
    let displayName: String
    let username: String
    let text: String
    let mediaUrls: [String]?
    let metrics: TweetMetrics?  // Engagement metrics
    let tweetUrl: String?  // Deep link URL

    var body: some View {
        let _ = print("\n🖼️ ===== RENDERING TWEET CARD =====")
        let _ = print("🖼️ Display Name: \(displayName)")
        let _ = print("🖼️ Username: @\(username)")
        let _ = print("🖼️ Text Length: \(text.count) chars")
        let _ = print("🖼️ Media URLs: \(mediaUrls?.count ?? 0)")
        let _ = print("🖼️ Metrics: \(metrics != nil ? "PRESENT" : "NIL")")
        let _ = metrics.map { m in
            print("🖼️   - Rendering Likes: \(m.likes)")
            print("🖼️   - Rendering Retweets: \(m.retweets)")
            print("🖼️   - Rendering Views: \(m.views)")
        }
        let _ = print("🖼️ Tweet URL: \(tweetUrl != nil ? "YES" : "NO")")
        let _ = print("🖼️ ===========================\n")

        VStack(alignment: .center, spacing: 12) {
            // Top: User icon and name centered and stacked
            VStack(spacing: 6) {
                Image(userIcon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
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

            // Bottom: Engagement metrics
            if let metrics = metrics {
                HStack(spacing: 16) {
                    // Views
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.system(size: 11))
                        Text(formatCount(metrics.views))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)

                    // Retweets
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 11))
                        Text(formatCount(metrics.retweets))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)

                    // Likes
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.system(size: 11))
                        Text(formatCount(metrics.likes))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    // X source icon
                    Image(sourceIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .opacity(0.5)
                }
            } else {
                // Fallback if no metrics
                HStack {
                    Spacer()
                    Image(sourceIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .opacity(0.5)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.primaryChatItemBackground.opacity(0.3))
                .stroke(Color.gray.opacity(0.7), lineWidth: 0.5)
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

    // NEW: Media Grid View
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

        VStack {
            Spacer()

            GrokPrimaryContentBlock(
                userIcon: ImageResource(name: "Grok", bundle: .main),
                displayName: "Elon Musk",
                username: "elonmusk",
                text: "Just had a great conversation with Grok about the future of AI and space exploration. The possibilities are endless when you combine these technologies!",
                mediaUrls: nil,
                metrics: TweetMetrics(likes: 12500, retweets: 3400, views: 150000),
                tweetUrl: "https://twitter.com/elonmusk/status/1234567890"
            )

            Spacer()
        }
    }
}
