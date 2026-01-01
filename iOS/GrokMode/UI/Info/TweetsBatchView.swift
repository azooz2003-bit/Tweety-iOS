//
//  TweetsBatchView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 1/1/26.
//

import SwiftUI

struct TweetsBatchView: View {
    let tweets: [EnrichedTweet]
    let imageCache: ImageCache

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List(tweets, id: \.tweet.id) { tweet in
                TweetConversationCard(enrichedTweet: tweet, imageCache: imageCache)
                    .listRowSeparator(.hidden)
                    .listRowSpacing(10)
            }
            .listStyle(.plain)
            .navigationTitle("Posts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
    }
}
