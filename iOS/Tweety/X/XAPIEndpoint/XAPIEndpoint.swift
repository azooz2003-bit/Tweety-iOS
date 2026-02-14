//
//  XAPIEndpoint.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/16/26.
//

import Foundation
import JSONSchema
internal import OrderedCollections

nonisolated
enum XAPIEndpoint: String, CaseIterable, Identifiable {
    enum PreviewBehavior {
        case none                      // Safe tools, auto-execute
        case requiresConfirmation      // Needs user approval with preview
    }
    
    // MARK: - Posts/Tweets
    case createTweet = "create_tweet"
    case replyToTweet = "reply_to_tweet"
    case quoteTweet = "quote_tweet"
    case createPollTweet = "create_poll_tweet"
    case deleteTweet = "delete_tweet"
    case editTweet = "edit_tweet"
    case getTweet = "get_tweet"
    case getTweets = "get_tweets"
    case getUserTweets = "get_user_tweets"
    case getUserMentions = "get_user_mentions"
    case getHomeTimeline = "get_home_timeline"
    case searchRecentTweets = "search_recent_tweets"
    case searchAllTweets = "search_all_tweets"
    case getRecentTweetCounts = "get_recent_tweet_counts"
    case getAllTweetCounts = "get_all_tweet_counts"

    // MARK: - Users
    case getUserById = "get_user_by_id"
    case getUserByUsername = "get_user_by_username"
    case getUsersById = "get_users_by_id"
    case getUsersByUsername = "get_users_by_username"
    case getAuthenticatedUser = "get_authenticated_user"
    case getUserFollowing = "get_user_following"
    case followUser = "follow_user"
    case unfollowUser = "unfollow_user"
    case getUserFollowers = "get_user_followers"
    case getMutedUsers = "get_muted_users"
    case muteUser = "mute_user"
    case unmuteUser = "unmute_user"
    case getBlockedUsers = "get_blocked_users"
    case blockUserDMs = "block_user_dms"
    case unblockUserDMs = "unblock_user_dms"

    // MARK: - Likes
    case getLikingUsers = "get_liking_users"
    case likeTweet = "like_tweet"
    case unlikeTweet = "unlike_tweet"
    case getUserLikedTweets = "get_user_liked_tweets"

    // MARK: - Retweets
    case getRetweetedBy = "get_retweeted_by"
    case retweet = "retweet"
    case unretweet = "unretweet"
    case getRetweets = "get_retweets"
//    case getRepostsOfMe = "get_reposts_of_me"

    // MARK: - Lists
    case createList = "create_list"
    case deleteList = "delete_list"
    case updateList = "update_list"
    case getList = "get_list"
    case getListMembers = "get_list_members"
    case addListMember = "add_list_member"
    case removeListMember = "remove_list_member"
    case getListTweets = "get_list_tweets"
    case getListFollowers = "get_list_followers"
    case pinList = "pin_list"
    case unpinList = "unpin_list"
    case getPinnedLists = "get_pinned_lists"
    case getOwnedLists = "get_owned_lists"
    case getFollowedLists = "get_followed_lists"
    case followList = "follow_list"
    case unfollowList = "unfollow_list"
    case getListMemberships = "get_list_memberships"

    // MARK: - Direct Messages
    case createDMConversation = "create_dm_conversation"
    case sendDMToConversation = "send_dm_to_conversation"
    case sendDMToParticipant = "send_dm_to_participant"
    case getDMEvents = "get_dm_events"
    case getConversationDMs = "get_conversation_dms"
    case getConversationDMsByParticipant = "get_conversation_dms_by_participant"
    case deleteDMEvent = "delete_dm_event"
    case getDMEventDetails = "get_dm_event_details"

    // MARK: - Bookmarks
    case addBookmark = "add_bookmark"
    case removeBookmark = "remove_bookmark"
    case getUserBookmarks = "get_user_bookmarks"

    // MARK: - Trends
    case getPersonalizedTrends = "get_personalized_trends"

    // MARK: - Community Notes
    case createNote = "create_note"
    case deleteNote = "delete_note"
    case evaluateNote = "evaluate_note"
    case getNotesWritten = "get_notes_written"
    case getPostsEligibleForNotes = "get_posts_eligible_for_notes"

    // MARK: - Media
    case uploadMedia = "upload_media"
    case getMediaStatus = "get_media_status"
    case initializeChunkedUpload = "initialize_chunked_upload"
    case appendChunkedUpload = "append_chunked_upload"
    case finalizeChunkedUpload = "finalize_chunked_upload"
    case createMediaMetadata = "create_media_metadata"
    case getMediaAnalytics = "get_media_analytics"

    // MARK: - News
    case getNewsById = "get_news_by_id"
    case searchNews = "search_news"

    var id: String { rawValue }
    var name: String { rawValue }

    var description: String {
        switch self {
        // Posts/Tweets
        case .createTweet: return "Create or edit a tweet"
        case .replyToTweet: return "Reply to a specific tweet."
        case .quoteTweet: return "Quote tweet a specific tweet."
        case .createPollTweet: return "Create a poll tweet"
        case .deleteTweet: return "Delete a specific tweet by ID"
        case .editTweet: return "Edit an existing tweet"
        case .getTweet: return "Get details of a specific tweet by ID"
        case .getTweets: return "Get multiple tweets by their IDs"
        case .getUserTweets: return "Get tweets posted by a specific user"
        case .getUserMentions: return "Get tweets mentioning a specific user"
        case .getHomeTimeline: return "Get the authenticated user's home timeline"
        case .searchRecentTweets: return "Search tweets from the last 7 days"
        case .searchAllTweets: return "Search tweets from the full archive"
        case .getRecentTweetCounts: return "Get tweet counts for recent tweets"
        case .getAllTweetCounts: return "Get tweet counts from full archive"

        // Users
        case .getUserById: return "Get user details by user ID"
        case .getUserByUsername: return "Get user details by username"
        case .getUsersById: return "Get multiple users by their IDs"
        case .getUsersByUsername: return "Get multiple users by usernames"
        case .getAuthenticatedUser: return "Get authenticated user details"
        case .getUserFollowing: return "Get list of users followed by a user"
        case .followUser: return "Follow a user"
        case .unfollowUser: return "Unfollow a user"
        case .getUserFollowers: return "Get a user's followers"
        case .getMutedUsers: return "Get list of muted users"
        case .muteUser: return "Mute a user"
        case .unmuteUser: return "Unmute a user"
        case .getBlockedUsers: return "Get list of blocked users"
        case .blockUserDMs: return "Block DMs from a user"
        case .unblockUserDMs: return "Unblock DMs from a user"

        // Likes
        case .getLikingUsers: return "Get users who liked a tweet"
        case .likeTweet: return "Like a tweet"
        case .unlikeTweet: return "Unlike a tweet"
        case .getUserLikedTweets: return "Get tweets liked by a user"

        // Retweets
        case .getRetweetedBy: return "Get users who retweeted a tweet"
        case .retweet: return "Retweet a tweet"
        case .unretweet: return "Remove a retweet"
        case .getRetweets: return "Get retweet posts of a specific tweet"
//        case .getRepostsOfMe: return "Get reposts of the authenticated user's tweets"

        // Lists
        case .createList: return "Create a new list"
        case .deleteList: return "Delete a list"
        case .updateList: return "Update list details"
        case .getList: return "Get list details by ID"
        case .getListMembers: return "Get members of a list"
        case .addListMember: return "Add a member to a list"
        case .removeListMember: return "Remove a member from a list"
        case .getListTweets: return "Get tweets from a list"
        case .getListFollowers: return "Get followers of a list"
        case .pinList: return "Pin a list"
        case .unpinList: return "Unpin a list"
        case .getPinnedLists: return "Get pinned lists for a user"
        case .getOwnedLists: return "Get lists owned by a user"
        case .getFollowedLists: return "Get lists followed by a user"
        case .followList: return "Follow a list"
        case .unfollowList: return "Unfollow a list"
        case .getListMemberships: return "Get lists that a user is a member of"

        // Direct Messages
        case .createDMConversation: return "Create a new DM conversation"
        case .sendDMToConversation: return "Send a DM to a conversation"
        case .sendDMToParticipant: return "Send a DM by participant ID"
        case .getDMEvents: return "Get ALL recent DM events across ALL conversations. Use this for general inbox view, NOT for specific conversations with a user."
        case .getConversationDMs: return "Get messages for a specific conversation by conversation ID. Only use if you already have the conversation ID."
        case .getConversationDMsByParticipant: return "Get the ENTIRE conversation (all messages) with a specific user by their user ID. USE THIS to fetch DM history with a specific person. This is the PRIMARY tool for retrieving conversation history between the authenticated user and another user."
        case .deleteDMEvent: return "Delete a DM event"
        case .getDMEventDetails: return "Get DM event details"

        // Bookmarks
        case .addBookmark: return "Add a tweet to bookmarks"
        case .removeBookmark: return "Remove a tweet from bookmarks"
        case .getUserBookmarks: return "Get user's bookmarked tweets"

        // Trends
        case .getPersonalizedTrends: return "Get personalized trending topics"

        // Community Notes
        case .createNote: return "Create a community note"
        case .deleteNote: return "Delete a community note"
        case .evaluateNote: return "Evaluate a community note"
        case .getNotesWritten: return "Get notes written by user"
        case .getPostsEligibleForNotes: return "Get posts eligible for notes"

        // Media
        case .uploadMedia: return "Upload media file"
        case .getMediaStatus: return "Get media upload status"
        case .initializeChunkedUpload: return "Initialize chunked media upload"
        case .appendChunkedUpload: return "Append data to chunked upload"
        case .finalizeChunkedUpload: return "Finalize chunked upload"
        case .createMediaMetadata: return "Create media metadata"
        case .getMediaAnalytics: return "Get media analytics"

        // News
        case .getNewsById: return "Get news story by ID"
        case .searchNews: return "Search news stories"
        }
    }

    var jsonSchema: JSONSchema {
        switch self {
        // MARK: - Posts/Tweets
        case .createTweet:
            return .object(
                properties: [
                    "text": .string(description: "The text content of the tweet"),
                    "reply_settings": .string(
                        description: "Who can reply to the tweet. Note: To allow everyone to reply, do not include this field in the request.",
                        enum: ["following", "mentionedUsers", "subscribers", "verified"]
                    )
                ],
                required: ["text"]
            )
        case .replyToTweet:
            return .object(
                properties: [
                    "text": .string(description: "The text content of the reply tweet."),
                    "reply": .object(
                        properties: [
                            "in_reply_to_tweet_id": .string(description: "The ID of the tweet you would like to reply to."),
                        ],
                        required: ["in_reply_to_tweet_id"]
                    ),
                    "reply_settings": .string(
                        description: "Who can reply to the tweet. Note: To allow everyone to reply, do not include this field in the request.",
                        enum: ["following", "mentionedUsers", "subscribers", "verified"]
                    )
                ],
                required: ["text", "reply"]
            )
        case .quoteTweet:
            return .object(
                properties: [
                    "text": .string(description: "The text content of the tweet"),
                    "quote_tweet_id": .string(description: "The ID of the tweet you would like to quote tweet. Make sure that a tweet with this ID exists before passing it."),
                    "reply_settings": .string(
                        description: "Who can reply to the tweet. Note: To allow everyone to reply, do not include this field in the request.",
                        enum: ["following", "mentionedUsers", "subscribers", "verified"]
                    )
                ],
                required: ["text", "quote_tweet_id"]
            )
        case .createPollTweet:
            return .object(
                properties: [
                    "text": .string(description: "The text content of the tweet"),
                    "poll": .object(
                        properties: [
                            "options": .array(description: "An array of poll choices as strings. Minimum of 2 choices, maximum of 4 choices.", items: .string(description: "The text to display for the choice. A minimum of 1 character, and maximum of 25 characters is allowed per choice.")),
                            "duration_minutes": .integer(description: "Poll duration in minutes. Values must be within this range: 5 <= x <= 10080."),
                            "reply_settings": .string(description: "Settings to indicate who can reply to the poll.", enum: [.string("following"), .string("mentionedUsers"), .string("subscribers"), .string("verified")])
                        ],
                        required: ["options", "duration_minutes"]
                    ),
                    "reply_settings": .string(
                        description: "Who can reply to the tweet. Note: To allow everyone to reply, do not include this field in the request.",
                        enum: ["following", "mentionedUsers", "subscribers", "verified"]
                    )
                ],
                required: ["text", "poll"]
            )
        case .deleteTweet:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID to delete. Make sure that a tweet with this ID exists and belongs to the authenticated user before passing it.")
                ],
                required: ["id"]
            )

        case .editTweet:
            return .object(
                properties: [
                    "previous_post_id": .string(description: "The ID of the tweet to edit. This tweet must belong to the authenticated user."),
                    "text": .string(description: "The new text content for the tweet")
                ],
                required: ["previous_post_id", "text"]
            )

        case .getTweet:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID")
                ],
                required: ["id"]
            )

        case .getTweets:
            return .object(
                properties: [
                    "ids": .array(description: "Tweet IDs", items: .string()),
                ],
                required: ["ids"]
            )

        case .getUserTweets:
            return .object(
                properties: [
                    "id": .string(description: "The user ID whose tweets to retrieve"),
                    "max_results": .integer(description: "Maximum number of tweets to return. Must be between 5 and 100. Defaults to 10."),
                    "exclude": .array(description: "Tweet types to exclude (e.g., 'retweets', 'replies')", items: .string(enum: ["retweets", "replies"])),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .getUserMentions:
            return .object(
                properties: [
                    "id": .string(description: "The user ID whose mentions to retrieve"),
                    "max_results": .integer(description: "Maximum number of mentions to return. Must be between 5 and 100. Defaults to 10."),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .getHomeTimeline:
            return .object(
                properties: [
                    "id": .string(description: "The ID of the authenticated source User to list Reverse Chronological Timeline Posts of. Unique identifier of this User. The value must be the same as the authenticated user."),
                    "max_results": .integer(description: "Maximum number of tweets to return. Must be between 1 and 100. Defaults to 10."),
                    "exclude": .array(description: "Tweet types to exclude (e.g., 'retweets', 'replies')", items: .string(enum: ["retweets", "replies"])),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .searchRecentTweets:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "max_results": .integer(description: "The maximum number of search results to be returned by a request. Should be at least 10 and at most 100, otherwise API will return error.", minimum: 10, maximum: 100),
                    "sort_order": .string(description: "This order in which to return results.", enum: ["recency", "relevancy"]),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["query"]
            )

        case .searchAllTweets:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "max_results": .integer(description: "The maximum number of search results to be returned by a request. Should be at least 10 and at most 500, otherwise API will return error.", minimum: 10, maximum: 500),
                    "sort_order": .string(description: "This order in which to return results.", enum: ["recency", "relevancy"]),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["query"]
            )

        case .getRecentTweetCounts:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "granularity": .string(description: "Time granularity", enum: ["minute", "hour", "day"])
                ],
                required: ["query"]
            )

        case .getAllTweetCounts:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "granularity": .string(description: "Time granularity", enum: ["minute", "hour", "day"])
                ],
                required: ["query"]
            )

        // MARK: - Users
        case .getUserById:
            return .object(
                properties: [
                    "id": .string(description: "The user ID")
                ],
                required: ["id"]
            )

        case .getUserByUsername:
            return .object(
                properties: [
                    "username": .string(description: "The username without @")
                ],
                required: ["username"]
            )

        case .getUsersById:
            return .object(
                properties: [
                    "ids": .array(description: "User IDs", items: .string())
                ],
                required: ["ids"]
            )

        case .getUsersByUsername:
            return .object(
                properties: [
                    "usernames": .array(description: "Usernames without @", items: .string())
                ],
                required: ["usernames"]
            )

        case .getAuthenticatedUser:
            return .empty

        case .getUserFollowing:
            return .object(
                properties: [
                    "id": .string(description: "The user ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 1000),
                    "pagination_token": .string(description: "Pagination token")
                ],
                required: ["id"]
            )

        case .followUser:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "target_user_id": .string(description: "The user ID to follow")
                ],
                required: ["id", "target_user_id"]
            )

        case .unfollowUser:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "target_user_id": .string(description: "The user ID to unfollow")
                ],
                required: ["id", "target_user_id"]
            )

        case .getUserFollowers:
            return .object(
                properties: [
                    "id": .string(description: "The user ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 1000),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .getMutedUsers:
            return .object(
                properties: [
                    "id": .string(description: "The user ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 1000),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .muteUser:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "target_user_id": .string(description: "The user ID to mute")
                ],
                required: ["id", "target_user_id"]
            )

        case .unmuteUser:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "target_user_id": .string(description: "The user ID to unmute")
                ],
                required: ["id", "target_user_id"]
            )

        case .getBlockedUsers:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 1000),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .blockUserDMs:
            return .object(
                properties: [
                    "target_user_id": .string(description: "The user ID to block DMs from. Can't be the authenticated user.")
                ],
                required: ["target_user_id"]
            )

        case .unblockUserDMs:
            return .object(
                properties: [
                    "target_user_id": .string(description: "The user ID to unblock DMs from. Can't be the authenticated user.")
                ],
                required: ["target_user_id"]
            )

        // MARK: - Likes
        case .getLikingUsers:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Pagination token")
                ],
                required: ["id"]
            )

        case .likeTweet:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "tweet_id": .string(description: "The tweet ID to like")
                ],
                required: ["id", "tweet_id"]
            )

        case .unlikeTweet:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "tweet_id": .string(description: "The tweet ID to unlike")
                ],
                required: ["id", "tweet_id"]
            )

        case .getUserLikedTweets:
            return .object(
                properties: [
                    "id": .string(description: "The user ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 5, maximum: 100),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        // MARK: - Retweets
        case .getRetweetedBy:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .retweet:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "tweet_id": .string(description: "The tweet ID to retweet")
                ],
                required: ["id", "tweet_id"]
            )

        case .unretweet:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "source_tweet_id": .string(description: "The tweet ID of the original post to unretweet. NOT the ID of the authenticated user's post id which encapsulates the original post.")
                ],
                required: ["id", "source_tweet_id"]
            )

        case .getRetweets:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID of the original post we want to see retweets of."),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

//        case .getRepostsOfMe:
//            return .object(
//                properties: [
//                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
//                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
//                ]
//            )

        // MARK: - Lists
        case .createList:
            return .object(
                properties: [
                    "name": .string(description: "List name"),
                    "description": .string(description: "List description"),
                    "private": .boolean(description: "Whether the list is private")
                ],
                required: ["name"]
            )

        case .deleteList:
            return .object(
                properties: [
                    "id": .string(description: "The list ID")
                ],
                required: ["id"]
            )

        case .updateList:
            return .object(
                properties: [
                    "id": .string(description: "The list ID"),
                    "name": .string(description: "List name"),
                    "description": .string(description: "List description"),
                    "private": .boolean(description: "Whether the list is private")
                ],
                required: ["id"]
            )

        case .getList:
            return .object(
                properties: [
                    "id": .string(description: "The list ID")
                ],
                required: ["id"]
            )

        case .getListMembers:
            return .object(
                properties: [
                    "id": .string(description: "The list ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .addListMember:
            return .object(
                properties: [
                    "id": .string(description: "The list ID"),
                    "user_id": .string(description: "The user ID to add")
                ],
                required: ["id", "user_id"]
            )

        case .removeListMember:
            return .object(
                properties: [
                    "id": .string(description: "The list ID"),
                    "user_id": .string(description: "The user ID to remove")
                ],
                required: ["id", "user_id"]
            )

        case .getListTweets:
            return .object(
                properties: [
                    "id": .string(description: "The list ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .getListFollowers:
            return .object(
                properties: [
                    "id": .string(description: "The list ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Pagination token")
                ],
                required: ["id"]
            )

        case .pinList:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "list_id": .string(description: "The list ID to pin")
                ],
                required: ["id", "list_id"]
            )

        case .unpinList:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "list_id": .string(description: "The list ID to unpin")
                ],
                required: ["id", "list_id"]
            )

        case .getPinnedLists:
            return .object(
                properties: [
                    "id": .string(description: "The ID of the authenticated user")
                ],
                required: ["id"]
            )

        case .getOwnedLists:
            return .object(
                properties: [
                    "id": .string(description: "The user ID whose owned lists to retrieve"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .getFollowedLists:
            return .object(
                properties: [
                    "id": .string(description: "The user ID whose followed lists to retrieve"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        case .followList:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "list_id": .string(description: "The list ID to follow")
                ],
                required: ["id", "list_id"]
            )

        case .unfollowList:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "list_id": .string(description: "The list ID to unfollow")
                ],
                required: ["id", "list_id"]
            )

        case .getListMemberships:
            return .object(
                properties: [
                    "id": .string(description: "The user ID whose list memberships to retrieve"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        // MARK: - Direct Messages
        case .createDMConversation:
            return .object(
                properties: [
                    "conversation_type": .string(description: "Conversation type", enum: ["Group"]),
                    "participant_ids": .array(description: "A list of user IDs associated with profiles you want to send the message to. User IDs must be valid IDs for existing users.", items: .string()),
                    "message": .object(
                        properties: [
                            "text": .string(description: "Message text"),
                            "attachments": .array(
                                items: .object(
                                    properties: [
                                        "media_id": .string(description: "Media ID")
                                    ]
                                )
                            )
                        ],
                        required: ["text"]
                    )
                ],
                required: ["conversation_type", "message", "participant_ids"]
            )

        case .sendDMToConversation:
            return .object(
                properties: [
                    "dm_conversation_id": .string(description: "DM conversation ID, must be valid for an actual conversation that exists in the authenticated user's account."),
                    "text": .string(description: "Message text, must not be empty"),
                    "attachments": .array(
                        description: "Media attachments",
                        items: .object(
                            properties: [
                                "media_id": .string(description: "Media ID")
                            ]
                        )
                    )
                ],
                required: ["dm_conversation_id", "text"]
            )

        case .sendDMToParticipant:
            return .object(
                properties: [
                    "participant_id": .string(description: "User ID associated with the profile you want to send the message to. User ID must be valid ID for existing user."),
                    "text": .string(description: "Message text, must not be empty."),
                    "attachments": .array(
                        description: "Media attachments", items: .object(
                            properties: [
                                "media_id": .string(description: "Media ID")
                            ]
                        )
                    )
                ],
                required: ["participant_id", "text"]
            )

        case .getDMEvents:
            return .object(
                properties: [
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "event_types": .string(description: "Comma-separated event types"),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ]
            )

        case .getConversationDMs:
            return .object(
                properties: [
                    "id": .string(description: "Conversation ID"),
                    "max_results": .integer(description: "Maximum results per page", minimum: 1, maximum: 100),
                    "event_types": .array(description: "Types of DM events to include. Defaults to all types.", items: .string(enum: ["MessageCreate", "ParticipantsJoin", "ParticipantsLeave"])),
                    "pagination_token": .string(description: "Pagination token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response. This tool supports pagination."),
                ],
                required: ["id"]
            )

        case .getConversationDMsByParticipant:
            return .object(
                properties: [
                    "participant_id": .string(description: "The user ID of the other participant in the 1-on-1 conversation. This is the user you want to see the DM conversation with. NOT the authenticated user's ID."),
                    "max_results": .integer(description: "Maximum results per page", minimum: 1, maximum: 100),
                    "event_types": .array(description: "Types of DM events to include. Defaults to all types.", items: .string(enum: ["MessageCreate", "ParticipantsJoin", "ParticipantsLeave"])),
                    "pagination_token": .string(description: "Pagination token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response. This tool SUPPORTS PAGINATION - use pagination_token to fetch additional pages of the conversation."),
                ],
                required: ["participant_id"]
            )

        case .deleteDMEvent:
            return .object(
                properties: [
                    "dm_event_id": .string(description: "Event ID associated with the DM to delete. Event IDs must be valid IDs for existing DMs.")
                ],
                required: ["dm_event_id"]
            )

        case .getDMEventDetails:
            return .object(
                properties: [
                    "id": .string(description: "DM event ID")
                ],
                required: ["id"]
            )

        // MARK: - Bookmarks
        case .addBookmark:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "tweet_id": .string(description: "The tweet ID to bookmark")
                ],
                required: ["id", "tweet_id"]
            )

        case .removeBookmark:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "tweet_id": .string(description: "The tweet ID to remove from bookmarks")
                ],
                required: ["id", "tweet_id"]
            )

        case .getUserBookmarks:
            return .object(
                properties: [
                    "id": .string(description: "The user ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Token to retrieve the next page of results. Use the value from 'meta.next_token' in the previous response."),
                ],
                required: ["id"]
            )

        // MARK: - Trends
        case .getPersonalizedTrends:
            return .empty

        // MARK: - Community Notes
        case .createNote:
            return .object(
                properties: [
                    "tweet_id": .string(description: "The tweet ID to add a note to"),
                    "text": .string(description: "Note text content")
                ],
                required: ["tweet_id", "text"]
            )

        case .deleteNote:
            return .object(
                properties: [
                    "id": .string(description: "The note ID to delete")
                ],
                required: ["id"]
            )

        case .evaluateNote:
            return .object(
                properties: [
                    "id": .string(description: "The note ID to evaluate"),
                    "helpful": .boolean(description: "Whether the note is helpful")
                ],
                required: ["id", "helpful"]
            )

        case .getNotesWritten:
            return .object(
                properties: [
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                ]
            )

        case .getPostsEligibleForNotes:
            return .object(
                properties: [
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                ]
            )

        // MARK: - Media
        case .uploadMedia:
            return .object(
                properties: [
                    "media": .string(description: "Base64 encoded media data"),
                    "media_category": .string(
                        description: "Media category",
                        enum: ["tweet_image", "tweet_video", "tweet_gif", "dm_image", "dm_video", "dm_gif"]
                    ),
                    "additional_owners": .array(description: "Additional user IDs who can use the media", items: .string())
                ],
                required: ["media"]
            )

        case .getMediaStatus:
            return .object(
                properties: [
                    "media_id": .string(description: "The media ID")
                ],
                required: ["media_id"]
            )

        case .initializeChunkedUpload:
            return .object(
                properties: [
                    "total_bytes": .integer(description: "Total bytes of media file"),
                    "media_type": .string(description: "MIME type", examples: ["image/jpeg", "video/mp4"]),
                    "media_category": .string(
                        description: "Media category",
                        enum: ["tweet_image", "tweet_video", "tweet_gif", "dm_image", "dm_video", "dm_gif"]
                    )
                ],
                required: ["total_bytes", "media_type"]
            )

        case .appendChunkedUpload:
            return .object(
                properties: [
                    "media_id": .string(description: "The media ID from initialization"),
                    "segment_index": .integer(description: "Index of the chunk segment"),
                    "media": .string(description: "Base64 encoded chunk data")
                ],
                required: ["media_id", "segment_index", "media"]
            )

        case .finalizeChunkedUpload:
            return .object(
                properties: [
                    "media_id": .string(description: "The media ID to finalize")
                ],
                required: ["media_id"]
            )

        case .createMediaMetadata:
            return .object(
                properties: [
                    "media_id": .string(description: "The media ID"),
                    "alt_text": .string(description: "Alternative text for accessibility")
                ],
                required: ["media_id"]
            )

        case .getMediaAnalytics:
            return .object(
                properties: [
                    "media_key": .string(description: "The media key")
                ],
                required: ["media_key"]
            )

        // MARK: - News
        case .getNewsById:
            return .object(
                properties: [
                    "id": .string(description: "The ID of the news story")
                ],
                required: ["id"]
            )

        case .searchNews:
            return .object(
                properties: [
                    "query": .string(description: "The search query"),
                    "max_results": .integer(description: "The number of results to return", minimum: 1, maximum: 100),
                    "max_age_hours": .integer(description: "The maximum age of the news story to search for", minimum: 1, maximum: 720)
                ],
                required: ["query"]
            )
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

        // Read-only operations are safe (searches, gets, streams, etc.)
        default:
            return .none
        }
    }

    static func getEndpointByName(_ name: String) -> XAPIEndpoint? {
        return XAPIEndpoint.allCases.first { $0.name == name }
    }

    /// API endpoints that are supported and should be exposed to the LLM.
    /// Excludes Community Notes and Media tools.
    static var supportedEndpoints: [XAPIEndpoint] {
        return allCases.filter { endpoint in
            switch endpoint {
            // Exclude Community Notes tools
            case .createNote, .deleteNote, .evaluateNote, .getNotesWritten, .getPostsEligibleForNotes:
                return false
            // Exclude Media tools
            case .uploadMedia, .getMediaStatus, .initializeChunkedUpload, .appendChunkedUpload,
                 .finalizeChunkedUpload, .createMediaMetadata, .getMediaAnalytics:
                return false
            // Include all other tools
            default:
                return true
            }
        }
    }

    /// All endpoints that require confirmation (have .requiresConfirmation preview behavior)
    static var confirmationSensitiveEndpoints: [XAPIEndpoint] {
        return allCases.filter { $0.previewBehavior == .requiresConfirmation }
    }
}
