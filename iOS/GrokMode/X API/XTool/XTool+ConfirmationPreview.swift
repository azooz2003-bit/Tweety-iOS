//
//  XTool+ConfirmationPreview.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/25/25.
//

import Foundation
import SwiftUI

extension XTool {
    var actionIcon: String {
        switch self {
        // Posts/Tweets
        case .createTweet:
            return "square.and.pencil"
        case .replyToTweet:
            return "arrowshape.turn.up.left.fill"
        case .quoteTweet:
            return "quote.bubble.fill"
        case .createPollTweet:
            return "chart.bar.doc.horizontal.fill"
        case .deleteTweet:
            return "trash.fill"
        case .editTweet:
            return "pencil.line"

        // Likes & Retweets
        case .likeTweet:
            return "heart.fill"
        case .unlikeTweet:
            return "heart.slash.fill"
        case .retweet:
            return "arrow.2.squarepath"
        case .unretweet:
            return "arrow.uturn.backward"

        // Follow/Unfollow
        case .followUser:
            return "person.badge.plus.fill"
        case .unfollowUser:
            return "person.badge.minus.fill"

        // Mute/Unmute
        case .muteUser:
            return "speaker.slash.fill"
        case .unmuteUser:
            return "speaker.wave.2.fill"

        // Block/Unblock DMs
        case .blockUserDMs:
            return "hand.raised.slash.fill"
        case .unblockUserDMs:
            return "hand.raised.fill"

        // Lists
        case .createList:
            return "list.bullet.rectangle.portrait.fill"
        case .deleteList:
            return "list.bullet.rectangle.portrait"
        case .updateList:
            return "pencil.and.list.clipboard"
        case .addListMember:
            return "person.crop.circle.badge.plus"
        case .removeListMember:
            return "person.crop.circle.badge.minus"
        case .pinList:
            return "pin.fill"
        case .unpinList:
            return "pin.slash.fill"
        case .followList:
            return "list.bullet.circle.fill"
        case .unfollowList:
            return "list.bullet.circle"

        // Direct Messages
        case .createDMConversation, .sendDMToConversation, .sendDMToParticipant:
            return "message.fill"
        case .deleteDMEvent:
            return "message.badge.filled.fill"

        // Bookmarks
        case .addBookmark:
            return "bookmark.fill"
        case .removeBookmark:
            return "bookmark.slash.fill"

        default:
            return "hand.raised.fill"
        }
    }

    var previewBehavior: PreviewBehavior {
        switch self {
        // Write operations require confirmation

        // Posts/Tweets
        case .createTweet, .replyToTweet, .quoteTweet, .createPollTweet, .deleteTweet, .editTweet:
            return .requiresConfirmation

        // Likes & Retweets
        case .likeTweet, .unlikeTweet, .retweet, .unretweet:
            return .requiresConfirmation

        // Follow/Unfollow
        case .followUser, .unfollowUser:
            return .requiresConfirmation

        // Mute/Unmute
        case .muteUser, .unmuteUser:
            return .requiresConfirmation

        // Block/Unblock DMs
        case .blockUserDMs, .unblockUserDMs:
            return .requiresConfirmation

        // Lists
        case .createList, .deleteList, .updateList, .addListMember, .removeListMember, .pinList, .unpinList, .followList, .unfollowList:
            return .requiresConfirmation

        // Direct Messages
        case .createDMConversation, .sendDMToConversation, .sendDMToParticipant, .deleteDMEvent:
            return .requiresConfirmation

        // Bookmarks
        case .addBookmark, .removeBookmark:
            return .requiresConfirmation

        // Voice Confirmation tools (must execute immediately without confirmation)
        case .confirmAction, .cancelAction:
            return .none

        // Read-only operations are safe (searches, gets, streams, etc.)
        default:
            return .none
        }
    }

    func generatePreview(from arguments: String, orchestrator: XToolOrchestrator) async -> (title: String, content: String)? {
        guard previewBehavior == .requiresConfirmation else { return nil }

        // Parse JSON arguments
        guard let data = arguments.data(using: .utf8),
              let params = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (title: "Allow \(name)?", content: "Unable to parse parameters")
        }

        // Tool-specific formatting
        switch self {
        case .createTweet:
            let text = params["text"] as? String ?? ""
            return (title: "Post Tweet", content: "\"\(text)\"")

        case .replyToTweet:
            let text = params["text"] as? String ?? ""

            if let replyObj = params["reply"] as? [String: Any],
               let replyToId = replyObj["in_reply_to_tweet_id"] as? String {
                // Fetch the tweet being replied to with author info
                let result = await orchestrator.executeTool(.getTweet, parameters: [
                    "id": replyToId,
                    "tweet.fields": ["text", "author_id"],
                    "expansions": ["author_id"],
                    "user.fields": ["username"]
                ])

                if result.success,
                   let responseData = result.response?.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let tweetData = json["data"] as? [String: Any],
                   let originalText = tweetData["text"] as? String {

                    // Extract username from expanded includes
                    var username = "user"
                    if let includes = json["includes"] as? [String: Any],
                       let users = includes["users"] as? [[String: Any]],
                       let user = users.first,
                       let handle = user["username"] as? String {
                        username = handle
                    }

                    let truncatedOriginal = originalText.count > 60 ? "\(originalText.prefix(60))..." : originalText
                    return (
                        title: "Reply to @\(username)",
                        content: "Original: \"\(truncatedOriginal)\"\n\nYour reply: \"\(text)\""
                    )
                }
            }
            return (title: "Reply to Tweet", content: "\"\(text)\"")

        case .quoteTweet:
            let text = params["text"] as? String ?? ""
            let quoteId = params["quote_tweet_id"] as? String ?? ""

            // Fetch the tweet being quoted with author info
            let result = await orchestrator.executeTool(.getTweet, parameters: [
                "id": quoteId,
                "tweet.fields": ["text", "author_id"],
                "expansions": ["author_id"],
                "user.fields": ["username"]
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let tweetData = json["data"] as? [String: Any],
               let originalText = tweetData["text"] as? String {

                // Extract username from expanded includes
                var username = "user"
                if let includes = json["includes"] as? [String: Any],
                   let users = includes["users"] as? [[String: Any]],
                   let user = users.first,
                   let handle = user["username"] as? String {
                    username = handle
                }

                let truncatedOriginal = originalText.count > 60 ? "\(originalText.prefix(60))..." : originalText
                return (
                    title: "Quote @\(username)",
                    content: "Quoting: \"\(truncatedOriginal)\"\n\nYour quote: \"\(text)\""
                )
            }
            return (title: "Quote Tweet", content: "\"\(text)\"")

        case .createPollTweet:
            let text = params["text"] as? String ?? ""
            if let pollObj = params["poll"] as? [String: Any],
               let options = pollObj["options"] as? [String],
               let duration = pollObj["duration_minutes"] as? Int {
                let optionsText = options.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
                return (title: "Create Poll", content: "\"\(text)\"\n\nPoll options:\n\(optionsText)\n\nDuration: \(duration) minutes")
            }
            return (title: "Create Poll", content: "\"\(text)\"")

        case .deleteTweet:
            let id = params["id"] as? String ?? ""

            // Fetch the tweet to be deleted
            let result = await orchestrator.executeTool(.getTweet, parameters: [
                "id": id,
                "tweet.fields": ["text"]
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let tweetData = json["data"] as? [String: Any],
               let tweetText = tweetData["text"] as? String {
                return (title: "Delete Tweet", content: "\"\(tweetText)\"")
            }
            return (title: "Delete Tweet", content: "Delete this tweet?")

        case .editTweet:
            let previousPostId = params["previous_post_id"] as? String ?? ""
            let newText = params["text"] as? String ?? ""

            // Fetch the tweet to be edited
            let result = await orchestrator.executeTool(.getTweet, parameters: [
                "id": previousPostId,
                "tweet.fields": ["text"]
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let tweetData = json["data"] as? [String: Any],
               let oldText = tweetData["text"] as? String {
                let truncatedOld = oldText.count > 40 ? "\(oldText.prefix(40))..." : oldText
                let truncatedNew = newText.count > 40 ? "\(newText.prefix(40))..." : newText
                return (title: "Edit Tweet", content: "From: \"\(truncatedOld)\"\nTo: \"\(truncatedNew)\"")
            }
            let truncatedNew = newText.count > 60 ? "\(newText.prefix(60))..." : newText
            return (title: "Edit Tweet", content: "\"\(truncatedNew)\"")

        case .likeTweet:
            let id = params["tweet_id"] as? String ?? ""

            // Fetch the tweet to be liked
            let result = await orchestrator.executeTool(.getTweet, parameters: [
                "id": id,
                "tweet.fields": ["text"]
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let tweetData = json["data"] as? [String: Any],
               let tweetText = tweetData["text"] as? String {
                let truncated = tweetText.count > 60 ? "\(tweetText.prefix(60))..." : tweetText
                return (title: "Like Tweet", content: "\"\(truncated)\"")
            }
            return (title: "Like Tweet", content: "Like this tweet?")

        case .unlikeTweet:
            let id = params["tweet_id"] as? String ?? ""

            // Fetch the tweet to be unliked
            let result = await orchestrator.executeTool(.getTweet, parameters: [
                "id": id,
                "tweet.fields": ["text"]
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let tweetData = json["data"] as? [String: Any],
               let tweetText = tweetData["text"] as? String {
                let truncated = tweetText.count > 60 ? "\(tweetText.prefix(60))..." : tweetText
                return (title: "Unlike Tweet", content: "\"\(truncated)\"")
            }
            return (title: "Unlike Tweet", content: "Unlike this tweet?")

        case .retweet:
            let id = params["tweet_id"] as? String ?? ""

            // Fetch the tweet to be retweeted
            let result = await orchestrator.executeTool(.getTweet, parameters: [
                "id": id,
                "tweet.fields": ["text"]
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let tweetData = json["data"] as? [String: Any],
               let tweetText = tweetData["text"] as? String {
                let truncated = tweetText.count > 60 ? "\(tweetText.prefix(60))..." : tweetText
                return (title: "Retweet", content: "\"\(truncated)\"")
            }
            return (title: "Retweet", content: "Retweet this?")

        case .unretweet:
            let id = params["source_tweet_id"] as? String ?? ""

            // Fetch the tweet to be unretweeted
            let result = await orchestrator.executeTool(.getTweet, parameters: [
                "id": id,
                "tweet.fields": ["text"]
            ])

            if result.success,
            let responseData = result.response?.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
            let tweetData = json["data"] as? [String: Any],
            let tweetText = tweetData["text"] as? String {
                let truncated = tweetText.count > 60 ? "\(tweetText.prefix(60))..." : tweetText
                return (title: "Undo Retweet", content: "\"\(truncated)\"")
            }
            return (title: "Undo Retweet", content: "Undo retweet?")

        // MARK: - Direct Messages
        case .sendDMToParticipant:
            let text = params["text"] as? String ?? ""
            let participantId = params["participant_id"] as? String ?? ""

            // Fetch the user being messaged
            let result = await orchestrator.executeTool(.getUserById, parameters: [
                "id": participantId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let username = userData["username"] as? String {
                return (title: "Send DM to @\(username)", content: "\"\(text)\"")
            }
            return (title: "Send Direct Message", content: "\"\(text)\"")

        case .sendDMToConversation:
            let text = params["text"] as? String ?? ""
            return (title: "Send DM", content: "\"\(text)\"")

        case .createDMConversation:
            let text: String
            if let messageObj = params["message"] as? [String: Any],
               let messageText = messageObj["text"] as? String {
                text = messageText
            } else {
                text = ""
            }

            let participantIds = params["participant_ids"] as? [String] ?? []
            let conversationType = params["conversation_type"] as? String ?? "DirectMessage"

            if conversationType == "Group" {
                return (title: "Create Group DM", content: "\"\(text)\"\n\nWith \(participantIds.count) participants")
            } else if let participantId = participantIds.first {
                // Fetch the user being messaged
                let result = await orchestrator.executeTool(.getUserById, parameters: [
                    "id": participantId
                ])

                if result.success,
                   let responseData = result.response?.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let userData = json["data"] as? [String: Any],
                   let username = userData["username"] as? String {
                    return (title: "New DM to @\(username)", content: "\"\(text)\"")
                }
            }
            return (title: "Create DM Conversation", content: "\"\(text)\"")

        case .deleteDMEvent:
            return (title: "Delete Message", content: "Delete this DM?")

        // MARK: - User Actions
        case .followUser:
            let targetUserId = params["target_user_id"] as? String ?? ""

            // Fetch the user to be followed
            let result = await orchestrator.executeTool(.getUserById, parameters: [
                "id": targetUserId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let username = userData["username"] as? String,
               let name = userData["name"] as? String {
                return (title: "Follow @\(username)", content: "\(name)")
            }
            return (title: "Follow User", content: "Follow this user?")

        case .unfollowUser:
            let targetUserId = params["target_user_id"] as? String ?? ""

            // Fetch the user to be unfollowed
            let result = await orchestrator.executeTool(.getUserById, parameters: [
                "id": targetUserId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let username = userData["username"] as? String,
               let name = userData["name"] as? String {
                return (title: "Unfollow @\(username)", content: "\(name)")
            }
            return (title: "Unfollow User", content: "Unfollow this user?")

        case .muteUser:
            let targetUserId = params["target_user_id"] as? String ?? ""

            // Fetch the user to be muted
            let result = await orchestrator.executeTool(.getUserById, parameters: [
                "id": targetUserId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let username = userData["username"] as? String,
               let name = userData["name"] as? String {
                return (title: "Mute @\(username)", content: "\(name)")
            }
            return (title: "Mute User", content: "Mute this user?")

        case .unmuteUser:
            let targetUserId = params["target_user_id"] as? String ?? ""

            // Fetch the user to be unmuted
            let result = await orchestrator.executeTool(.getUserById, parameters: [
                "id": targetUserId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let username = userData["username"] as? String,
               let name = userData["name"] as? String {
                return (title: "Unmute @\(username)", content: "\(name)")
            }
            return (title: "Unmute User", content: "Unmute this user?")

        case .blockUserDMs:
            let targetUserId = params["target_user_id"] as? String ?? ""

            // Fetch the user
            let result = await orchestrator.executeTool(.getUserById, parameters: [
                "id": targetUserId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let username = userData["username"] as? String,
               let name = userData["name"] as? String {
                return (title: "Block DMs from @\(username)", content: "\(name)")
            }
            return (title: "Block DMs", content: "Block DMs from this user?")

        case .unblockUserDMs:
            let targetUserId = params["target_user_id"] as? String ?? ""

            // Fetch the user
            let result = await orchestrator.executeTool(.getUserById, parameters: [
                "id": targetUserId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let username = userData["username"] as? String,
               let name = userData["name"] as? String {
                return (title: "Unblock DMs from @\(username)", content: "\(name)")
            }
            return (title: "Unblock DMs", content: "Unblock DMs from this user?")

        // MARK: - Lists
        case .createList:
            let name = params["name"] as? String ?? ""
            let description = params["description"] as? String ?? ""
            let isPrivate = params["private"] as? Bool ?? false
            let privacy = isPrivate ? "Private" : "Public"
            return (title: "Create List", content: "\(name)\n\(privacy)\n\n\(description)")

        case .deleteList:
            let listId = params["id"] as? String ?? ""

            // Fetch the list
            let result = await orchestrator.executeTool(.getList, parameters: [
                "id": listId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let listData = json["data"] as? [String: Any],
               let listName = listData["name"] as? String {
                return (title: "Delete List", content: "\(listName)")
            }
            return (title: "Delete List", content: "Delete this list?")

        case .updateList:
            let name = params["name"] as? String
            let description = params["description"] as? String
            let isPrivate = params["private"] as? Bool

            var updates: [String] = []
            if let name = name { updates.append("Name: \(name)") }
            if let description = description { updates.append("Description: \(description)") }
            if let isPrivate = isPrivate {
                updates.append("Privacy: \(isPrivate ? "Private" : "Public")")
            }

            return (title: "Update List", content: "\(updates.joined(separator: "\n"))")

        case .addListMember:
            let listId = params["id"] as? String ?? ""
            let userId = params["user_id"] as? String ?? ""

            // Fetch both list and user
            async let listResult = orchestrator.executeTool(.getList, parameters: ["id": listId])
            async let userResult = orchestrator.executeTool(.getUserById, parameters: ["id": userId])

            let (list, user) = await (listResult, userResult)

            var listName = "list"
            if list.success,
               let responseData = list.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let listData = json["data"] as? [String: Any],
               let name = listData["name"] as? String {
                listName = name
            }

            var username = "user"
            if user.success,
               let responseData = user.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let handle = userData["username"] as? String {
                username = "@\(handle)"
            }

            return (title: "Add to List", content: "\(listName)\n\(username)")

        case .removeListMember:
            let listId = params["id"] as? String ?? ""
            let userId = params["user_id"] as? String ?? ""

            // Fetch both list and user
            async let listResult = orchestrator.executeTool(.getList, parameters: ["id": listId])
            async let userResult = orchestrator.executeTool(.getUserById, parameters: ["id": userId])

            let (list, user) = await (listResult, userResult)

            var listName = "list"
            if list.success,
               let responseData = list.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let listData = json["data"] as? [String: Any],
               let name = listData["name"] as? String {
                listName = name
            }

            var username = "user"
            if user.success,
               let responseData = user.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let handle = userData["username"] as? String {
                username = "@\(handle)"
            }

            return (title: "Remove from List", content: "\(listName)\n\(username)")

        case .pinList:
            let listId = params["list_id"] as? String ?? ""

            // Fetch the list
            let result = await orchestrator.executeTool(.getList, parameters: [
                "id": listId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let listData = json["data"] as? [String: Any],
               let listName = listData["name"] as? String {
                return (title: "Pin List", content: "\(listName)")
            }
            return (title: "Pin List", content: "Pin this list?")

        case .unpinList:
            let listId = params["list_id"] as? String ?? ""

            // Fetch the list
            let result = await orchestrator.executeTool(.getList, parameters: [
                "id": listId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let listData = json["data"] as? [String: Any],
               let listName = listData["name"] as? String {
                return (title: "Unpin List", content: "\(listName)")
            }
            return (title: "Unpin List", content: "Unpin this list?")

        case .followList:
            let listId = params["list_id"] as? String ?? ""

            // Fetch the list
            let result = await orchestrator.executeTool(.getList, parameters: [
                "id": listId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let listData = json["data"] as? [String: Any],
               let listName = listData["name"] as? String {
                return (title: "Follow List", content: "\(listName)")
            }
            return (title: "Follow List", content: "Follow this list?")

        case .unfollowList:
            let listId = params["list_id"] as? String ?? ""

            // Fetch the list
            let result = await orchestrator.executeTool(.getList, parameters: [
                "id": listId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let listData = json["data"] as? [String: Any],
               let listName = listData["name"] as? String {
                return (title: "Unfollow List", content: "\(listName)")
            }
            return (title: "Unfollow List", content: "Unfollow this list?")

        // MARK: - Bookmarks
        case .addBookmark:
            let tweetId = params["tweet_id"] as? String ?? ""

            // Fetch the tweet to be bookmarked
            let result = await orchestrator.executeTool(.getTweet, parameters: [
                "id": tweetId,
                "tweet.fields": ["text"]
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let tweetData = json["data"] as? [String: Any],
               let tweetText = tweetData["text"] as? String {
                let truncated = tweetText.count > 60 ? "\(tweetText.prefix(60))..." : tweetText
                return (title: "Bookmark Tweet", content: "\"\(truncated)\"")
            }
            return (title: "Bookmark Tweet", content: "Save this tweet?")

        case .removeBookmark:
            let tweetId = params["tweet_id"] as? String ?? ""

            // Fetch the tweet to be unbookmarked
            let result = await orchestrator.executeTool(.getTweet, parameters: [
                "id": tweetId,
                "tweet.fields": ["text"]
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let tweetData = json["data"] as? [String: Any],
               let tweetText = tweetData["text"] as? String {
                let truncated = tweetText.count > 60 ? "\(tweetText.prefix(60))..." : tweetText
                return (title: "Remove Bookmark", content: "\"\(truncated)\"")
            }
            return (title: "Remove Bookmark", content: "Remove bookmark?")

        default:
            return (title: "Allow \(name)?", content: arguments)
        }
    }
}

// MARK: - Preview Helpers

private struct ToolPreviewRow: View {
    let tool: XTool
    let sampleTitle: String
    let sampleContent: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: tool.actionIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(.blue.gradient)
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(sampleTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(sampleContent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            Text(tool.rawValue)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview("Tool Previews") {
    List {
        Section("Posts & Tweets") {
            ToolPreviewRow(
                tool: .createTweet,
                sampleTitle: "Post Tweet",
                sampleContent: "\"Just discovered an amazing new feature in SwiftUI!\""
            )
            ToolPreviewRow(
                tool: .replyToTweet,
                sampleTitle: "Reply to @johndoe",
                sampleContent: "Original: \"What's everyone working on today?\"\n\nYour reply: \"Building a new iOS app with SwiftUI!\""
            )
            ToolPreviewRow(
                tool: .quoteTweet,
                sampleTitle: "Quote @janedoe",
                sampleContent: "Quoting: \"SwiftUI makes building UIs so much easier!\"\n\nYour quote: \"Couldn't agree more! The declarative syntax is game-changing.\""
            )
            ToolPreviewRow(
                tool: .createPollTweet,
                sampleTitle: "Create Poll",
                sampleContent: "\"Which programming language do you prefer?\"\n\nPoll options:\n1. Swift\n2. Kotlin\n3. JavaScript\n4. Python\n\nDuration: 1440 minutes"
            )
            ToolPreviewRow(
                tool: .deleteTweet,
                sampleTitle: "Delete Tweet",
                sampleContent: "\"This tweet didn't age well\""
            )
            ToolPreviewRow(
                tool: .editTweet,
                sampleTitle: "Edit Tweet",
                sampleContent: "From: \"I love coding in Swift!\"\nTo: \"I love coding in Swift and SwiftUI!\""
            )
        }

        Section("Likes & Retweets") {
            ToolPreviewRow(
                tool: .likeTweet,
                sampleTitle: "Like Tweet",
                sampleContent: "\"SwiftUI's new features in iOS 18 are incredible!\""
            )
            ToolPreviewRow(
                tool: .unlikeTweet,
                sampleTitle: "Unlike Tweet",
                sampleContent: "\"Hot take: tabs are better than spaces\""
            )
            ToolPreviewRow(
                tool: .retweet,
                sampleTitle: "Retweet",
                sampleContent: "\"Just shipped v2.0 of our app! Check it out on the App Store.\""
            )
            ToolPreviewRow(
                tool: .unretweet,
                sampleTitle: "Undo Retweet",
                sampleContent: "\"Reposted this too early, the event got rescheduled\""
            )
        }

        Section("Follow & Unfollow") {
            ToolPreviewRow(
                tool: .followUser,
                sampleTitle: "Follow @apple",
                sampleContent: "Apple Inc."
            )
            ToolPreviewRow(
                tool: .unfollowUser,
                sampleTitle: "Unfollow @spambot",
                sampleContent: "Spam Bot Account"
            )
        }

        Section("Mute & Unmute") {
            ToolPreviewRow(
                tool: .muteUser,
                sampleTitle: "Mute @noisyuser",
                sampleContent: "Too Many Posts Daily"
            )
            ToolPreviewRow(
                tool: .unmuteUser,
                sampleTitle: "Unmute @goodfriend",
                sampleContent: "Good Friend"
            )
        }

        Section("Block & Unblock DMs") {
            ToolPreviewRow(
                tool: .blockUserDMs,
                sampleTitle: "Block DMs from @spammer",
                sampleContent: "Spam Account"
            )
            ToolPreviewRow(
                tool: .unblockUserDMs,
                sampleTitle: "Unblock DMs from @colleague",
                sampleContent: "Work Colleague"
            )
        }

        Section("Lists") {
            ToolPreviewRow(
                tool: .createList,
                sampleTitle: "Create List",
                sampleContent: "iOS Developers\nPublic\n\nDevelopers building amazing iOS apps"
            )
            ToolPreviewRow(
                tool: .deleteList,
                sampleTitle: "Delete List",
                sampleContent: "Old Projects"
            )
            ToolPreviewRow(
                tool: .updateList,
                sampleTitle: "Update List",
                sampleContent: "Name: SwiftUI Enthusiasts\nDescription: People who love SwiftUI\nPrivacy: Private"
            )
            ToolPreviewRow(
                tool: .addListMember,
                sampleTitle: "Add to List",
                sampleContent: "iOS Developers\n@johndoe"
            )
            ToolPreviewRow(
                tool: .removeListMember,
                sampleTitle: "Remove from List",
                sampleContent: "iOS Developers\n@janedoe"
            )
            ToolPreviewRow(
                tool: .pinList,
                sampleTitle: "Pin List",
                sampleContent: "Favorite Developers"
            )
            ToolPreviewRow(
                tool: .unpinList,
                sampleTitle: "Unpin List",
                sampleContent: "Random Topics"
            )
            ToolPreviewRow(
                tool: .followList,
                sampleTitle: "Follow List",
                sampleContent: "Tech News"
            )
            ToolPreviewRow(
                tool: .unfollowList,
                sampleTitle: "Unfollow List",
                sampleContent: "Outdated Resources"
            )
        }

        Section("Direct Messages") {
            ToolPreviewRow(
                tool: .createDMConversation,
                sampleTitle: "New DM to @colleague",
                sampleContent: "\"Hey, can we discuss the project?\""
            )
            ToolPreviewRow(
                tool: .sendDMToConversation,
                sampleTitle: "Send DM",
                sampleContent: "\"Thanks for the quick response!\""
            )
            ToolPreviewRow(
                tool: .sendDMToParticipant,
                sampleTitle: "Send DM to @friend",
                sampleContent: "\"Want to grab coffee this weekend?\""
            )
            ToolPreviewRow(
                tool: .deleteDMEvent,
                sampleTitle: "Delete Message",
                sampleContent: "Delete this DM?"
            )
        }

        Section("Bookmarks") {
            ToolPreviewRow(
                tool: .addBookmark,
                sampleTitle: "Bookmark Tweet",
                sampleContent: "\"Great tutorial on advanced Swift patterns: [link]\""
            )
            ToolPreviewRow(
                tool: .removeBookmark,
                sampleTitle: "Remove Bookmark",
                sampleContent: "\"Already read this article and implemented it\""
            )
        }
    }
    .listStyle(.insetGrouped)
}
