//
//  TweetInteractionView.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI
internal import os

struct TweetActionView: View {
    let title: String
    let content: String
    let actions: [ActionConfig]

    @State private var showFullContent = false

    struct ActionConfig: Identifiable {
        let id: UUID = UUID()
        let action: () -> Void
        let symbol: String
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    Button {
                        showFullContent = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 4)

            Text(content)
                .frame(maxHeight: 60)
                .padding(.bottom, 6)
                .font(.footnote)
                .frame(alignment: .top)

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
            RoundedRectangle(cornerRadius: 25)
                .fill(.primaryChatItemBackground.opacity(0.3))
                .stroke(Color.gray.opacity(0.7), lineWidth: 1)
        }
        .sheet(isPresented: $showFullContent) {
            fullContentSheet
        }
    }

    @ViewBuilder
    var fullContentSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(content)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Full Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFullContent = false
                    }
                }
            }
        }
    }

    func capsuleButton(action: @escaping () -> Void, symbol: String) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(.background)) // TODO: use system color
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(.label)))
        }
        .interactiveScale(scale: 1.05, hapticFeedback: .light)

    }
}

#Preview {
    VStack(alignment: .trailing, spacing: 20) {
        TweetActionView(
            title: "Reply?",
            content: "fuhwighiwulgawip oihguwihg wagrwr9gwa9 9ag8 9 rgwa8g 98a o98aw g4gw y9a98g",
            actions: [
                TweetActionView.ActionConfig(action: {
                    #if DEBUG
                    AppLogger.ui.debug("Xmark")
                    #endif
                }, symbol: "xmark"),
                TweetActionView.ActionConfig(action: {
                    #if DEBUG
                    AppLogger.ui.debug("Checkmark")
                    #endif
                }, symbol: "checkmark"),
            ]
        )
        .frame(width: 250)
        .padding(.horizontal)

        TweetActionView(
            title: "Create ticket?",
            content: "Id: fwfwg\nfewfwfwef",
            actions: [
                TweetActionView.ActionConfig(action: {
                    #if DEBUG
                    AppLogger.ui.debug("Xmark")
                    #endif
                }, symbol: "xmark"),
                TweetActionView.ActionConfig(action: {
                    #if DEBUG
                    AppLogger.ui.debug("Checkmark")
                    #endif
                }, symbol: "checkmark"),
            ]
        )
        .frame(width: 250)
        .padding(.horizontal)
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
}
