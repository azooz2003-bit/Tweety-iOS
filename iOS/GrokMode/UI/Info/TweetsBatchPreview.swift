//
//  TweetsBatchPreview.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 1/1/26.
//

import SwiftUI

struct TweetsBatchPreview: View {
    let tweets: [EnrichedTweet]
    let imageCache: ImageCache

    @State var presentTweets: Bool = false

    var profilePicUrlsToPreview: [URL] {
        let pfpUrls = tweets.compactMap(\.author?.profile_image_url).compactMap { urlString -> URL? in
            // Replace size modifiers with _400x400 for higher quality
            let highQualityUrl = urlString
                .replacingOccurrences(of: "_normal", with: "_400x400")
                .replacingOccurrences(of: "_bigger", with: "_400x400")
                .replacingOccurrences(of: "_mini", with: "_400x400")
                .replacingOccurrences(of: "_reasonably_small", with: "_400x400")
            return URL(string: highQualityUrl)
        }
        let uniquePfpUrls = Set(pfpUrls)

        return Array(uniquePfpUrls.prefix(3))
    }

    let interImageOffset: CGFloat = 20
    let imageWidthHeight: CGFloat = 30

    var body: some View {
        Button {
           presentTweets = true
        } label: {
            self.content
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $presentTweets) {
            TweetsBatchView(tweets: tweets, imageCache: imageCache)
        }
    }

    @ViewBuilder
    var content: some View {
        HStack {
            profilePics
                .padding(.trailing, 8)

            Text("Fetched \(tweets.count) posts")

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(Color(.label))
        }
        .fontWeight(.semibold)
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(.regularMaterial)
        .clipRoundedRectangleWithBorder(20, borderColor: .primaryChatItemBackground.opacity(0.5))
    }

    @ViewBuilder
    var profilePics: some View {
        ZStack(alignment: .leading) {
            ForEach(profilePicUrlsToPreview.enumerated(), id: \.element.absoluteString) { (index, url) in
                CachedAsyncImage(url: url, imageCache: imageCache) { image in
                    image
                        .resizable()
                }
                .frame(width: imageWidthHeight, height: imageWidthHeight)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color(.label), lineWidth: 1)
                }
                .frame(width: imageWidthHeight + interImageOffset * CGFloat(index), alignment: .trailing)
                .zIndex(Double(profilePicUrlsToPreview.count - index))
            }
        }
    }
}

#Preview {
    let mockTweets: [EnrichedTweet] = [
        EnrichedTweet(
            from: XTweet(
                id: "1",
                text: "Just shipped a new feature using SwiftUI!",
                author_id: "1",
                created_at: nil,
                attachments: nil,
                public_metrics: nil,
                referenced_tweets: nil
            ),
            includes: XTweetResponse.Includes(
                users: [
                    XUser(
                        id: "1",
                        name: "Tim Cook",
                        username: "tim_cook",
                        profile_image_url: "https://pbs.twimg.com/profile_images/1535420431766642689/0JEHvmKX_normal.jpg"
                    )
                ],
                media: nil, tweets: nil
            )
        ),
        EnrichedTweet(
            from: XTweet(
                id: "2",
                text: "SwiftUI is the future of app development!",
                author_id: "2",
                created_at: nil,
                attachments: nil,
                public_metrics: nil,
                referenced_tweets: nil
            ),
            includes: XTweetResponse.Includes(
                users: [
                    XUser(
                        id: "2",
                        name: "Craig Federighi",
                        username: "craig_fed",
                        profile_image_url: "https://pbs.twimg.com/profile_images/1326221840613482496/DOBh-vvL_normal.jpg"
                    )
                ],
                media: nil, tweets: nil
            )
        ),
        EnrichedTweet(
            from: XTweet(
                id: "3",
                text: "Excited about the new iPhone features!",
                author_id: "3",
                created_at: nil,
                attachments: nil,
                public_metrics: nil,
                referenced_tweets: nil
            ),
            includes: XTweetResponse.Includes(
                users: [
                    XUser(
                        id: "3",
                        name: "Apple",
                        username: "Apple",
                        profile_image_url: "https://pbs.twimg.com/profile_images/1283958620359516160/n7lF7evS_normal.jpg"
                    )
                ],
                media: nil, tweets: nil
            )
        ),
        EnrichedTweet(
            from: XTweet(
                id: "4",
                text: "Building the next generation of apps",
                author_id: "4",
                created_at: nil,
                attachments: nil,
                public_metrics: nil,
                referenced_tweets: nil
            ),
            includes: XTweetResponse.Includes(
                users: [
                    XUser(
                        id: "4",
                        name: "Developer",
                        username: "developer",
                        profile_image_url: "https://pbs.twimg.com/profile_images/1454487280991932422/RsNK3kZd_normal.jpg"
                    )
                ],
                media: nil, tweets: nil
            )
        ),
        EnrichedTweet(
            from: XTweet(
                id: "5",
                text: "iOS 18 is amazing!",
                author_id: "5",
                created_at: nil,
                attachments: nil,
                public_metrics: nil,
                referenced_tweets: nil
            ),
            includes: XTweetResponse.Includes(
                users: [
                    XUser(
                        id: "5",
                        name: "Tech Enthusiast",
                        username: "tech_fan",
                        profile_image_url: "https://pbs.twimg.com/profile_images/1785935048447508480/qbDxJE1d_normal.jpg"
                    )
                ],
                media: nil, tweets: nil
            )
        )
    ]

    TweetsBatchPreview(tweets: mockTweets, imageCache: .init())
        .padding()
}
