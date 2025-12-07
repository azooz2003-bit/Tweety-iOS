//
//  GrokPrimaryContentBlock.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI

struct GrokPrimaryContentBlock: View {
    let sourceIcon: ImageResource = ImageResource(name: "X", bundle: .main)
    let userIcon: ImageResource
    let displayName: String
    let username: String
    let text: String

    var body: some View {
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

            // Bottom: Source icon at trailing edge
            HStack {
                Spacer()

                Image(sourceIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .opacity(0.6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.primaryChatItemBackground.opacity(0.3))
                .stroke(Color.gray.opacity(0.7), lineWidth: 0.5)
        )
        .padding(.horizontal, 10)
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
                text: "Just had a great conversation with Grok about the future of AI and space exploration. The possibilities are endless when you combine these technologies!"
            )

            Spacer()
        }
    }
}
