//
//  PrimaryContentBlock.swift
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

struct PrimaryContentBlock: View {
    let sourceIcon: ImageResource = ImageResource(name: "X", bundle: .main)
    let profileImageUrl: String?  // URL to profile image
    let displayName: String
    let username: String
    let text: String
    let media: [XMedia]?
    let metrics: TweetMetrics?  // Engagement metrics
    let tweetUrl: String?  // Deep link URL

    var body: some View {
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
                .lineLimit(5)
                .frame(maxWidth: .infinity, maxHeight: 200, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)

            // Image Grid (if media exists)
            if let media = media, !media.isEmpty {
                mediaGrid(mediaItems: media)
                    .frame(maxWidth: .infinity)
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

    // Convert profile image URL to higher quality version
    private func highQualityProfileImageUrl(_ urlString: String?) -> URL? {
        guard let urlString = urlString else { return nil }

        // Replace _normal (48x48) with _400x400 for higher quality
        // X API supports: _mini (24x24), _normal (48x48), _bigger (73x73), _400x400 (400x400)
        let highQualityUrl = urlString.replacingOccurrences(of: "_normal", with: "_400x400")
        return URL(string: highQualityUrl)
    }

    @ViewBuilder
    private func imageView() -> some View {
        if let url = highQualityProfileImageUrl(profileImageUrl) {
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
    private func mediaGrid(mediaItems: [XMedia]) -> some View {
        let columns = mediaItems.count == 1 ? 1 : 2
        let gridItems = Array(repeating: GridItem(.flexible(minimum: 100, maximum: 400), spacing: 12), count: columns)
        let spacing: CGFloat = 8

        LazyVGrid(columns: gridItems, spacing: spacing) {
            ForEach(Array(mediaItems.prefix(4).enumerated()), id: \.offset) { index, media in
                let urlString = media.url

                if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            mediaPlaceholderBackground()
                                .overlay {
                                    ProgressView()
                                        .tint(.white)
                                }
                        case .success(let image):
                            image
                                .resizable()
                        case .failure(let error):
                            mediaPlaceholderBackground()
                                .overlay {
                                    VStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                        Text(error.localizedDescription)
                                            .multilineTextAlignment(.center)
                                            .font(.caption2)
                                            .lineLimit(2)
                                            .padding(.horizontal, 8)
                                    }
                                    .foregroundStyle(.white.opacity(0.6))
                                }
                        @unknown default:
                            fatalError()
                        }
                    }
                    .aspectRatio(aspectRatio(forMedia: media), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    mediaPlaceholderBackground()
                        .overlay {
                            Image("exclamationmark.triangle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func mediaPlaceholderBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .foregroundStyle(.gray.opacity(0.4))
    }

    private func aspectRatio(forMedia media: XMedia) -> CGFloat {
        guard let width = media.width, let height = media.height else {
            return 1
        }

        return CGFloat(width) / CGFloat(height)
    }
}

#Preview("Default States") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        ScrollView{
            VStack(spacing: 24){
                Spacer()

                PrimaryContentBlock(
                    profileImageUrl: nil,  // Will show X icon as fallback
                    displayName: "Elon Musk",
                    username: "elonmusk",
                    text: "Just had a great conversation with Grok about the future of AI and space exploration. The possibilities are endless when you combine these technologies!",
                    media: nil,
                    metrics: TweetMetrics(likes: 12500, retweets: 3400, views: 150000),
                    tweetUrl: "https://twitter.com/elonmusk/status/1234567890"
                )


                PrimaryContentBlock(
                    profileImageUrl: nil,  // Will show X icon as fallback
                    displayName: "Elon Musk",
                    username: "elonmusk",
                    text: "Just had a great conversation with Grok about the future of AI and space exploration. The possibilities are endless when you combine these technologies!",
                    media: nil,
                    metrics: TweetMetrics(likes: 12500, retweets: 3400, views: 150000),
                    tweetUrl: "https://twitter.com/elonmusk/status/1234567890"
                )




                PrimaryContentBlock(
                    profileImageUrl: nil,  // Will show X icon as fallback
                    displayName: "Elon Musk",
                    username: "elonmusk",
                    text: "Just had a great conversation with Grok about the future of AI and space exploration. The possibilities are endless when you combine these technologies! Just had a great conversation with Grok about the future of AI. Just had a great conversation with Grok about the future of AI",
                    media: nil,
                    metrics: TweetMetrics(likes: 12500, retweets: 3400, views: 150000),
                    tweetUrl: "https://twitter.com/elonmusk/status/1234567890"
                )


                Spacer()
            }}
    }
}

#Preview("Media Grid - Loading State") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        ScrollView {
            VStack(spacing: 24) {
                // Simulates loading state with slow/non-existent images
                PrimaryContentBlock(
                    profileImageUrl: nil,
                    displayName: "Tech News",
                    username: "technews",
                    text: "Breaking: New images from the latest tech conference!",
                    media: [
                        XMedia(
                            media_key: "1",
                            type: "photo",
                            url: "https://httpstat.us/200?sleep=5000", // Slow loading URL
                            preview_image_url: nil,
                            width: 1200,
                            height: 800
                        ),
                        XMedia(
                            media_key: "2",
                            type: "photo",
                            url: "https://httpstat.us/200?sleep=5000",
                            preview_image_url: nil,
                            width: 1080,
                            height: 1080
                        ),
                        XMedia(
                            media_key: "3",
                            type: "photo",
                            url: "https://httpstat.us/200?sleep=5000",
                            preview_image_url: nil,
                            width: 1920,
                            height: 1080
                        )
                    ],
                    metrics: TweetMetrics(likes: 5400, retweets: 1200, views: 45000),
                    tweetUrl: "https://twitter.com/technews/status/1234567891"
                )
            }
            .padding(.vertical)
        }
    }
}

#Preview("Media Grid - Failure State") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        ScrollView {
            VStack(spacing: 24) {
                // Uses invalid URLs to trigger failure state
                PrimaryContentBlock(
                    profileImageUrl: nil,
                    displayName: "Photography",
                    username: "photoexample",
                    text: "Check out these amazing shots! (Note: Images failed to load)",
                    media: [
                        XMedia(
                            media_key: "1",
                            type: "photo",
                            url: "https://invalid-url-that-will-fail.example/image1.jpg",
                            preview_image_url: nil,
                            width: 1200,
                            height: 800
                        ),
                        XMedia(
                            media_key: "2",
                            type: "photo",
                            url: "https://invalid-url-that-will-fail.example/image2.jpg",
                            preview_image_url: nil,
                            width: 1080,
                            height: 1080
                        ),
                        XMedia(
                            media_key: "3",
                            type: "photo",
                            url: "https://invalid-url-that-will-fail.example/image3.jpg",
                            preview_image_url: nil,
                            width: 800,
                            height: 1200
                        ),
                        XMedia(
                            media_key: "4",
                            type: "photo",
                            url: "https://invalid-url-that-will-fail.example/image4.jpg",
                            preview_image_url: nil,
                            width: 1920,
                            height: 1080
                        )
                    ],
                    metrics: TweetMetrics(likes: 8900, retweets: 2100, views: 67000),
                    tweetUrl: "https://twitter.com/photoexample/status/1234567892"
                )

                // Single image failure
                PrimaryContentBlock(
                    profileImageUrl: nil,
                    displayName: "Artist",
                    username: "digitalartist",
                    text: "My latest work! (Failed to load)",
                    media: [
                        XMedia(
                            media_key: "1",
                            type: "photo",
                            url: "https://invalid-url.example/art.jpg",
                            preview_image_url: nil,
                            width: 1080,
                            height: 1350
                        )
                    ],
                    metrics: TweetMetrics(likes: 3200, retweets: 450, views: 28000),
                    tweetUrl: "https://twitter.com/digitalartist/status/1234567893"
                )
            }
            .padding(.vertical)
        }
    }
}

#Preview("Media Grid - Success State") {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        ScrollView {
            VStack(spacing: 24) {
                // Uses actual working image URLs
                PrimaryContentBlock(
                    profileImageUrl: nil,
                    displayName: "Sample User",
                    username: "sampleuser",
                    text: "Beautiful landscapes from today's hike!",
                    media: [
                        XMedia(
                            media_key: "1",
                            type: "photo",
                            url: "https://picsum.photos/1200/800",
                            preview_image_url: nil,
                            width: 1200,
                            height: 800
                        ),
                        XMedia(
                            media_key: "2",
                            type: "photo",
                            url: "https://picsum.photos/1080/1080",
                            preview_image_url: nil,
                            width: 1080,
                            height: 1080
                        ),
                        XMedia(
                            media_key: "3",
                            type: "photo",
                            url: "https://picsum.photos/1920/1080",
                            preview_image_url: nil,
                            width: 1920,
                            height: 1080
                        ),
                        XMedia(
                            media_key: "4",
                            type: "photo",
                            url: "https://picsum.photos/800/1200",
                            preview_image_url: nil,
                            width: 800,
                            height: 1200
                        )
                    ],
                    metrics: TweetMetrics(likes: 15600, retweets: 4200, views: 125000),
                    tweetUrl: "https://twitter.com/sampleuser/status/1234567894"
                )
            }
            .padding(.vertical)
        }
    }
}
