//
//  TweetInteractionView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI

struct TweetActionView: View {
    let title: String
    let content: String
    let actions: [ActionConfig]

    struct ActionConfig: Identifiable {
        let id: UUID = UUID()
        let action: () -> Void
        let symbol: String
    }

    var body: some View {
        VStack(alignment: .center) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.bottom, 4)
            Text(content)

            HStack {
                ForEach(actions) { action in
                    capsuleButton(action: action.action, symbol: action.symbol)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(.primaryChatItemBackground.opacity(0.3))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.7), lineWidth: 1)
        )
    }

    func capsuleButton(action: @escaping () -> Void, symbol: String) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(.black) // TODO:
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(.primary))
    }
}

#Preview {
    TweetActionView(title: "Reply?", content: "fuhwighiwulgawip oihguwihg wagrwr9gwa9 9ag8 9 rgwa8g 98a o98aw g4gw y9a98g", actions: [
        TweetActionView.ActionConfig(action: {
            print("Xmark")
        }, symbol: "xmark"),
        TweetActionView.ActionConfig(action: {
            print("Checkmark")
        }, symbol: "checkmark"),
    ])
    .padding(.horizontal)
}
