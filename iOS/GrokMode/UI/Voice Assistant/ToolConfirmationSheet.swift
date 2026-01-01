//
//  ToolConfirmationSheet.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/8/25.
//

import SwiftUI

struct ToolConfirmationSheet: View {
    let toolCall: PendingToolCall
    let serviceName: String
    let onApprove: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: toolCall.actionIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(.blue.gradient)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview Action")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(serviceName) needs your confirmation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.top, 4)

            Divider()
                .background(.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 8) {
                Text(toolCall.previewTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(toolCall.previewContent)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.1), lineWidth: 1)
            )

            Spacer()

            HStack(spacing: 16) {
                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .background(.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )

                Button {
                    onApprove()
                    dismiss()
                } label: {
                    Text("Approve")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .background(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
            }
        }
        .padding(24)
    }
}

private struct ToolIconRow: View {
    let functionName: String
    let iconName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(.blue.gradient)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(functionName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(iconName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview("Sheet") {
    ToolConfirmationSheet(toolCall: .init(id: "ddwd", functionName: "ffq", arguments: "fqfq", previewTitle: "fqf", previewContent: "fqffff"), serviceName: "xAI", onApprove: {}, onCancel: {})
}

#Preview("All Tool Icons") {
    List {
        Section("Posts & Tweets") {
            ToolIconRow(functionName: "create_tweet", iconName: "square.and.pencil")
            ToolIconRow(functionName: "reply_to_tweet", iconName: "arrowshape.turn.up.left.fill")
            ToolIconRow(functionName: "quote_tweet", iconName: "quote.bubble.fill")
            ToolIconRow(functionName: "create_poll_tweet", iconName: "chart.bar.doc.horizontal.fill")
            ToolIconRow(functionName: "delete_tweet", iconName: "trash.fill")
            ToolIconRow(functionName: "edit_tweet", iconName: "pencil.line")
        }

        Section("Likes & Retweets") {
            ToolIconRow(functionName: "like_tweet", iconName: "heart.fill")
            ToolIconRow(functionName: "unlike_tweet", iconName: "heart.slash.fill")
            ToolIconRow(functionName: "retweet", iconName: "arrow.2.squarepath")
            ToolIconRow(functionName: "unretweet", iconName: "arrow.uturn.backward")
        }

        Section("Follow & Unfollow") {
            ToolIconRow(functionName: "follow_user", iconName: "person.badge.plus.fill")
            ToolIconRow(functionName: "unfollow_user", iconName: "person.badge.minus.fill")
        }

        Section("Mute & Unmute") {
            ToolIconRow(functionName: "mute_user", iconName: "speaker.slash.fill")
            ToolIconRow(functionName: "unmute_user", iconName: "speaker.wave.2.fill")
        }

        Section("Block & Unblock DMs") {
            ToolIconRow(functionName: "block_user_dms", iconName: "hand.raised.slash.fill")
            ToolIconRow(functionName: "unblock_user_dms", iconName: "hand.raised.fill")
        }

        Section("Lists") {
            ToolIconRow(functionName: "create_list", iconName: "list.bullet.rectangle.portrait.fill")
            ToolIconRow(functionName: "delete_list", iconName: "list.bullet.rectangle.portrait")
            ToolIconRow(functionName: "update_list", iconName: "pencil.and.list.clipboard")
            ToolIconRow(functionName: "add_list_member", iconName: "person.crop.circle.badge.plus")
            ToolIconRow(functionName: "remove_list_member", iconName: "person.crop.circle.badge.minus")
            ToolIconRow(functionName: "pin_list", iconName: "pin.fill")
            ToolIconRow(functionName: "unpin_list", iconName: "pin.slash.fill")
            ToolIconRow(functionName: "follow_list", iconName: "list.bullet.circle.fill")
            ToolIconRow(functionName: "unfollow_list", iconName: "list.bullet.circle")
        }

        Section("Direct Messages") {
            ToolIconRow(functionName: "create_dm_conversation", iconName: "message.fill")
            ToolIconRow(functionName: "send_dm_to_conversation", iconName: "message.fill")
            ToolIconRow(functionName: "send_dm_to_participant", iconName: "message.fill")
            ToolIconRow(functionName: "delete_dm_event", iconName: "message.badge.filled.fill")
        }

        Section("Bookmarks") {
            ToolIconRow(functionName: "add_bookmark", iconName: "bookmark.fill")
            ToolIconRow(functionName: "remove_bookmark", iconName: "bookmark.slash.fill")
        }

        Section("Default") {
            ToolIconRow(functionName: "unknown_action", iconName: "hand.raised.fill")
        }
    }
    .listStyle(.insetGrouped)
}
