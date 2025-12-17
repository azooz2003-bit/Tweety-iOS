//
//  XTool.swift
//  XTools
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import Foundation
import JSONSchema
internal import OrderedCollections

enum PreviewBehavior {
    case none                      // Safe tools, auto-execute
    case requiresConfirmation      // Needs user approval with preview
}

nonisolated
enum XTool: String, CaseIterable, Identifiable {
    // MARK: - Posts/Tweets
    case createTweet = "create_tweet"
    case replyToTweet = "reply_to_tweet"
    case quoteTweet = "quote_tweet"
    case createPollTweet = "create_poll_tweet"
    case deleteTweet = "delete_tweet"
    case getTweet = "get_tweet"
    case getTweets = "get_tweets"
    case searchRecentTweets = "search_recent_tweets"
    case searchAllTweets = "search_all_tweets"
    case getRecentTweetCounts = "get_recent_tweet_counts"
    case getAllTweetCounts = "get_all_tweet_counts"

    // MARK: - Streaming
    case streamFilteredTweets = "stream_filtered_tweets"
    case manageStreamRules = "manage_stream_rules"
    case getStreamRules = "get_stream_rules"
    case getStreamRuleCounts = "get_stream_rule_counts"
    case streamSample = "stream_sample"
    case streamSample10 = "stream_sample_10"

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
    case blockUser = "block_user"
    case unblockUser = "unblock_user"
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

    // MARK: - Direct Messages
    case createDMConversation = "create_dm_conversation"
    case sendDMToConversation = "send_dm_to_conversation"
    case sendDMToParticipant = "send_dm_to_participant"
    case getDMEvents = "get_dm_events"
    case getConversationDMs = "get_conversation_dms"
    case deleteDMEvent = "delete_dm_event"
    case getDMEventDetails = "get_dm_event_details"

    // MARK: - Bookmarks
    case addBookmark = "add_bookmark"
    case removeBookmark = "remove_bookmark"
    case getUserBookmarks = "get_user_bookmarks"

    // MARK: - Spaces
    case getSpace = "get_space"
    case getSpaces = "get_spaces"
    case getSpacesByCreator = "get_spaces_by_creator"
    case getSpaceTweets = "get_space_tweets"
    case searchSpaces = "search_spaces"
    case getSpaceBuyers = "get_space_buyers"

    // MARK: - Trends
    case getTrendsByWoeid = "get_trends_by_woeid"
    case getPersonalizedTrends = "get_personalized_trends"

    // MARK: - Community Notes
    case createNote = "create_note"
    case deleteNote = "delete_note"
    case evaluateNote = "evaluate_note"
    case getNotesWritten = "get_notes_written"
    case getPostsEligibleForNotes = "get_posts_eligible_for_notes"

    // MARK: - Compliance
    case createComplianceJob = "create_compliance_job"
    case getComplianceJob = "get_compliance_job"

    case listComplianceJobs = "list_compliance_jobs"

    // MARK: - Media
    case uploadMedia = "upload_media"
    case getMediaStatus = "get_media_status"
    case initializeChunkedUpload = "initialize_chunked_upload"
    case appendChunkedUpload = "append_chunked_upload"
    case finalizeChunkedUpload = "finalize_chunked_upload"
    case createMediaMetadata = "create_media_metadata"
    case getMediaAnalytics = "get_media_analytics"

    // MARK: - Voice Confirmation
    case confirmAction = "confirm_action"
    case cancelAction = "cancel_action"

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
        case .getTweet: return "Get details of a specific tweet by ID"
        case .getTweets: return "Get multiple tweets by their IDs"
        case .searchRecentTweets: return "Search tweets from the last 7 days"
        case .searchAllTweets: return "Search tweets from the full archive"
        case .getRecentTweetCounts: return "Get tweet counts for recent tweets"
        case .getAllTweetCounts: return "Get tweet counts from full archive"

        // Streaming
        case .streamFilteredTweets: return "Stream tweets matching active rules"
        case .manageStreamRules: return "Add or delete streaming rules"
        case .getStreamRules: return "Get active streaming rules"
        case .getStreamRuleCounts: return "Get streaming rule counts"
        case .streamSample: return "Stream 1% sample of tweets"
        case .streamSample10: return "Stream 10% sample of tweets"

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
        case .blockUser: return "Block a user"
        case .unblockUser: return "Unblock a user"
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
        case .getRetweets: return "Get retweets of a specific tweet"

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

        // Direct Messages
        case .createDMConversation: return "Create a new DM conversation"
        case .sendDMToConversation: return "Send a DM to a conversation"
        case .sendDMToParticipant: return "Send a DM by participant ID"
        case .getDMEvents: return "Get recent DM events"
        case .getConversationDMs: return "Get messages for a conversation"
        case .deleteDMEvent: return "Delete a DM event"
        case .getDMEventDetails: return "Get DM event details"

        // Bookmarks
        case .addBookmark: return "Add a tweet to bookmarks"
        case .removeBookmark: return "Remove a tweet from bookmarks"
        case .getUserBookmarks: return "Get user's bookmarked tweets"

        // Spaces
        case .getSpace: return "Get space details by ID"
        case .getSpaces: return "Get multiple spaces by IDs"
        case .getSpacesByCreator: return "Get spaces created by specific users"
        case .getSpaceTweets: return "Get tweets shared in a space"
        case .searchSpaces: return "Search spaces by query"
        case .getSpaceBuyers: return "Get users who purchased space tickets"

        // Trends
        case .getTrendsByWoeid: return "Get trends for a location by WOEID"
        case .getPersonalizedTrends: return "Get personalized trending topics"

        // Community Notes
        case .createNote: return "Create a community note"
        case .deleteNote: return "Delete a community note"
        case .evaluateNote: return "Evaluate a community note"
        case .getNotesWritten: return "Get notes written by user"
        case .getPostsEligibleForNotes: return "Get posts eligible for notes"

        // Compliance
        case .createComplianceJob: return "Create a compliance job"
        case .getComplianceJob: return "Get compliance job details"
        case .listComplianceJobs: return "List all compliance jobs"

        // Media
        case .uploadMedia: return "Upload media file"
        case .getMediaStatus: return "Get media upload status"
        case .initializeChunkedUpload: return "Initialize chunked media upload"
        case .appendChunkedUpload: return "Append data to chunked upload"
        case .finalizeChunkedUpload: return "Finalize chunked upload"
        case .createMediaMetadata: return "Create media metadata"
        case .getMediaAnalytics: return "Get media analytics"

        // Voice Confirmation
        case .confirmAction: return "Confirms and executes the pending action when the user says 'yes', 'confirm', 'do it', or similar affirmations"
        case .cancelAction: return "Cancels the pending action when the user says 'no', 'cancel', 'don't', or similar rejections"
        }
    }

    var jsonSchema: JSONSchema {
        switch self {
        // MARK: - Posts/Tweets
        case .createTweet:
            return .object(
                properties: [
                    "text": .string(description: "The text content of the tweet"),
//                    "media": .object(
//                        properties: [
//                            "media_ids": .array(description: "Media IDs to attach", items: .string()),
//                            "tagged_user_ids": .array(description: "IDs of users tagged in media", items: .string())
//                        ],
//                        required: ["media_ids"]
//                    ),
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
//                            "exclude_reply_user_ids": .array(description: "User IDs to exclude from reply", items: .string())
                        ],
                        required: ["in_reply_to_tweet_id"]
                    ),
//                    "media": .object(
//                        properties: [
//                            "media_ids": .array(description: "Media IDs to attach", items: .string()),
//                            "tagged_user_ids": .array(description: "IDs of users tagged in media", items: .string())
//                        ],
//                        required: ["media_ids"]
//                    ),
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
//                    "media": .object(
//                        properties: [
//                            "media_ids": .array(description: "Media IDs to attach", items: .string()),
//                            "tagged_user_ids": .array(description: "IDs of users tagged in media", items: .string())
//                        ],
//                        required: ["media_ids"]
//                    ),
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

        case .searchRecentTweets:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "start_time": .string(description: "YYYY-MM-DDTHH:mm:ssZ. The oldest UTC timestamp from which the Posts will be provided. Timestamp is in second granularity and is inclusive (i.e. 12:00:01 includes the first second of the minute).", examples: ["2025-01-01T00:00:00Z"]),
                    "end_time": .string(description: "YYYY-MM-DDTHH:mm:ssZ. The newest, most recent UTC timestamp to which the Posts will be provided. Timestamp is in second granularity and is exclusive (i.e. 12:00:01 excludes the first second of the minute).", examples: ["2025-01-01T00:00:00Z"]),
                    "since_id": .string(description: "Tweet ID for filtering results. Returns results with a Post ID greater than (that is, more recent than) the specified ID."),
                    "until_id": .string(description: "Tweet ID for filtering results. Returns results with a Post ID less than (that is, older than) the specified ID."),
                    "max_results": .integer(description: "The maximum number of search results to be returned by a request. Should be at least 10 and at most 100, otherwise API will return error.", minimum: 10, maximum: 100),
                    "sort_order": .string(description: "This order in which to return results.", enum: ["recency", "relevancy"]),
                ],
                required: ["query"]
            )

        case .searchAllTweets:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "start_time": .string(description: "YYYY-MM-DDTHH:mm:ssZ. The oldest UTC timestamp from which the Posts will be provided. Timestamp is in second granularity and is inclusive (i.e. 12:00:01 includes the first second of the minute).", examples: ["2025-01-01T00:00:00Z"]),
                    "end_time": .string(description: "YYYY-MM-DDTHH:mm:ssZ. The newest, most recent UTC timestamp to which the Posts will be provided. Timestamp is in second granularity and is exclusive (i.e. 12:00:01 excludes the first second of the minute).", examples: ["2025-01-01T00:00:00Z"]),
                    "since_id": .string(description: "Tweet ID for filtering results. Returns results with a Post ID greater than (that is, more recent than) the specified ID."),
                    "until_id": .string(description: "Tweet ID for filtering results. Returns results with a Post ID less than (that is, older than) the specified ID."),
                    "max_results": .integer(description: "The maximum number of search results to be returned by a request. Should be at least 10 and at most 500, otherwise API will return error.", minimum: 10, maximum: 500),
                    "sort_order": .string(description: "This order in which to return results.", enum: ["recency", "relevancy"]),
                ],
                required: ["query"]
            )

        case .getRecentTweetCounts:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "start_time": .string(description: "ISO 8601 datetime"),
                    "end_time": .string(description: "ISO 8601 datetime"),
                    "since_id": .string(description: "Tweet ID for filtering"),
                    "until_id": .string(description: "Tweet ID for filtering"),
                    "granularity": .string(description: "Time granularity", enum: ["minute", "hour", "day"])
                ],
                required: ["query"]
            )

        case .getAllTweetCounts:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "start_time": .string(description: "ISO 8601 datetime"),
                    "end_time": .string(description: "ISO 8601 datetime"),
                    "since_id": .string(description: "Tweet ID for filtering"),
                    "until_id": .string(description: "Tweet ID for filtering"),
                    "granularity": .string(description: "Time granularity", enum: ["minute", "hour", "day"])
                ],
                required: ["query"]
            )

        // MARK: - Streaming
        case .streamFilteredTweets:
            return .object(
                properties: [:]
            )

        case .manageStreamRules:
            return .object(
                properties: [
                    "add": .array(
                        description: "Rules to add",
                        items: .object(
                            properties: [
                                "value": .string(description: "Rule filter query"),
                                "tag": .string(description: "Rule tag")
                            ],
                            required: ["value"]
                        )
                    ),
                    "delete": .object(
                        properties: [
                            "ids": .array(description: "Rule IDs to delete", items: .string())
                        ]
                    )
                ]
            )

        case .getStreamRules:
            return .object(properties: [:])

        case .getStreamRuleCounts:
            return .object(properties: [:])

        case .streamSample:
            return .object(
                properties: [
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "place.fields": .string(description: "Comma-separated list of place fields"),
                    "poll.fields": .string(description: "Comma-separated list of poll fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ]
            )

        case .streamSample10:
            return .object(
                properties: [
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "place.fields": .string(description: "Comma-separated list of place fields"),
                    "poll.fields": .string(description: "Comma-separated list of poll fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ]
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
            return .object(
                properties: [:]
            )

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
                ],
                required: ["id"]
            )

        case .getMutedUsers:
            return .object(
                properties: [
                    "id": .string(description: "The user ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 1000),
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
                    "id": .string(description: "The user ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 1000),
                ],
                required: ["id"]
            )

        case .blockUser:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "target_user_id": .string(description: "The user ID to block")
                ],
                required: ["id", "target_user_id"]
            )

        case .unblockUser:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "target_user_id": .string(description: "The user ID to unblock")
                ],
                required: ["id", "target_user_id"]
            )

        case .blockUserDMs:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "target_user_id": .string(description: "The user ID to block DMs from")
                ],
                required: ["id", "target_user_id"]
            )

        case .unblockUserDMs:
            return .object(
                properties: [
                    "id": .string(description: "The authenticated user's ID"),
                    "target_user_id": .string(description: "The user ID to unblock DMs from")
                ],
                required: ["id", "target_user_id"]
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
                ],
                required: ["id"]
            )

        // MARK: - Retweets
        case .getRetweetedBy:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
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
                    "source_tweet_id": .string(description: "The tweet ID to unretweet")
                ],
                required: ["id", "source_tweet_id"]
            )

        case .getRetweets:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                ],
                required: ["id"]
            )

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

        // MARK: - Direct Messages
        case .createDMConversation:
            return .object(
                properties: [
                    "conversation_type": .string(description: "Conversation type", enum: ["Group", "DirectMessage"]),
                    "participant_ids": .array(description: "Participant user IDs", items: .string()),
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
                    "dm_conversation_id": .string(description: "DM conversation ID"),
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
                    "participant_id": .string(description: "Recipient user ID"),
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
                    "event_types": .string(description: "Comma-separated event types")
                ]
            )

        case .getConversationDMs:
            return .object(
                properties: [
                    "id": .string(description: "Conversation ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "event_types": .string(description: "Comma-separated event types")
                ],
                required: ["id"]
            )

        case .deleteDMEvent:
            return .object(
                properties: [
                    "dm_event_id": .string(description: "DM event ID to delete")
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
                ],
                required: ["id"]
            )

        // MARK: - Spaces
        case .getSpace:
            return .object(
                properties: [
                    "id": .string(description: "The space ID")
                ],
                required: ["id"]
            )

        case .getSpaces:
            return .object(
                properties: [
                    "ids": .array(description: "Space IDs", items: .string())
                ],
                required: ["ids"]
            )

        case .getSpacesByCreator:
            return .object(
                properties: [
                    "user_ids": .array(description: "Creator user IDs", items: .string())
                ],
                required: ["user_ids"]
            )

        case .getSpaceTweets:
            return .object(
                properties: [
                    "id": .string(description: "The space ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100)
                ],
                required: ["id"]
            )

        case .searchSpaces:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "state": .string(description: "Space state", enum: ["live", "scheduled", "ended"]),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100)
                ],
                required: ["query"]
            )

        case .getSpaceBuyers:
            return .object(
                properties: [
                    "id": .string(description: "The space ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100)
                ],
                required: ["id"]
            )

        // MARK: - Trends
        case .getTrendsByWoeid:
            return .object(
                properties: [
                    "woeid": .string(description: "Where On Earth ID for location")
                ],
                required: ["woeid"]
            )

        case .getPersonalizedTrends:
            return .object(properties: [:])

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

        // MARK: - Compliance
        case .createComplianceJob:
            return .object(
                properties: [
                    "type": .string(description: "Job type", enum: ["tweets", "users"]),
                    "name": .string(description: "Job name"),
                    "resumable": .boolean(description: "Whether the job is resumable")
                ],
                required: ["type"]
            )

        case .getComplianceJob:
            return .object(
                properties: [
                    "id": .string(description: "The compliance job ID")
                ],
                required: ["id"]
            )

        case .listComplianceJobs:
            return .object(
                properties: [
                    "type": .string(description: "Job type filter", enum: ["tweets", "users"]),
                    "status": .string(description: "Job status filter", enum: ["created", "in_progress", "complete", "failed"])
                ],
                required: ["type"]
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

        // MARK: - Voice Confirmation
        case .confirmAction:
            return .object(
                properties: [
                    "tool_call_id": .string(description: "The ID of the original tool call that is being confirmed")
                ],
                required: ["tool_call_id"]
            )

        case .cancelAction:
            return .object(
                properties: [
                    "tool_call_id": .string(description: "The ID of the original tool call that is being cancelled")
                ],
                required: ["tool_call_id"]
            )
        }
    }
}

// MARK: - XTool Extensions
extension XTool {
    var previewBehavior: PreviewBehavior {
        switch self {
        // Write operations require confirmation

        // Posts/Tweets
        case .createTweet, .replyToTweet, .quoteTweet, .createPollTweet, .deleteTweet:
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

        // Block/Unblock
        case .blockUser, .unblockUser, .blockUserDMs, .unblockUserDMs:
            return .requiresConfirmation

        // Lists
        case .createList, .deleteList, .updateList, .addListMember, .removeListMember, .pinList, .unpinList:
            return .requiresConfirmation

        // Direct Messages
        case .createDMConversation, .sendDMToConversation, .sendDMToParticipant, .deleteDMEvent:
            return .requiresConfirmation

        // Bookmarks
        case .addBookmark, .removeBookmark:
            return .requiresConfirmation

        // Stream Rules
        case .manageStreamRules:
            return .requiresConfirmation

        // Compliance
        case .createComplianceJob:
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
                        content: "Original: \"\(truncatedOriginal)\"\n\n↩️ Your reply: \"\(text)\""
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
                    content: "Quoting: \"\(truncatedOriginal)\"\n\n🔁 Your quote: \"\(text)\""
                )
            }
            return (title: "Quote Tweet", content: "\"\(text)\"")

        case .createPollTweet:
            let text = params["text"] as? String ?? ""
            if let pollObj = params["poll"] as? [String: Any],
               let options = pollObj["options"] as? [String],
               let duration = pollObj["duration_minutes"] as? Int {
                let optionsText = options.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
                return (title: "Create Poll", content: "\"\(text)\"\n\n📊 Poll options:\n\(optionsText)\n\n⏱ Duration: \(duration) minutes")
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
                return (title: "Delete Tweet", content: "🗑️ \"\(tweetText)\"")
            }
            return (title: "Delete Tweet", content: "🗑️ Delete this tweet?")

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
                return (title: "Like Tweet", content: "❤️ \"\(truncated)\"")
            }
            return (title: "Like Tweet", content: "❤️ Like this tweet?")

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
                return (title: "Unlike Tweet", content: "💔 \"\(truncated)\"")
            }
            return (title: "Unlike Tweet", content: "💔 Unlike this tweet?")

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
                return (title: "Retweet", content: "🔁 \"\(truncated)\"")
            }
            return (title: "Retweet", content: "🔁 Retweet this?")

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
                return (title: "Undo Retweet", content: "↩️ \"\(truncated)\"")
            }
            return (title: "Undo Retweet", content: "↩️ Undo retweet?")

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
                return (title: "Send DM to @\(username)", content: "💬 \"\(text)\"")
            }
            return (title: "Send Direct Message", content: "💬 \"\(text)\"")

        case .sendDMToConversation:
            let text = params["text"] as? String ?? ""
            let conversationId = params["dm_conversation_id"] as? String ?? ""
            return (title: "Send DM", content: "💬 \"\(text)\"\n\nConversation ID: \(conversationId)")

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
                return (title: "Create Group DM", content: "💬 \"\(text)\"\n\nWith \(participantIds.count) participants")
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
                    return (title: "New DM to @\(username)", content: "💬 \"\(text)\"")
                }
            }
            return (title: "Create DM Conversation", content: "💬 \"\(text)\"")

        case .deleteDMEvent:
            let eventId = params["dm_event_id"] as? String ?? ""
            return (title: "Delete Message", content: "🗑️ Delete this DM?\n\nEvent ID: \(eventId)")

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
                return (title: "Follow @\(username)", content: "➕ \(name)")
            }
            return (title: "Follow User", content: "➕ Follow this user?")

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
                return (title: "Unfollow @\(username)", content: "➖ \(name)")
            }
            return (title: "Unfollow User", content: "➖ Unfollow this user?")

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
                return (title: "Mute @\(username)", content: "🔇 \(name)")
            }
            return (title: "Mute User", content: "🔇 Mute this user?")

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
                return (title: "Unmute @\(username)", content: "🔊 \(name)")
            }
            return (title: "Unmute User", content: "🔊 Unmute this user?")

        case .blockUser:
            let targetUserId = params["target_user_id"] as? String ?? ""

            // Fetch the user to be blocked
            let result = await orchestrator.executeTool(.getUserById, parameters: [
                "id": targetUserId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let username = userData["username"] as? String,
               let name = userData["name"] as? String {
                return (title: "Block @\(username)", content: "🚫 \(name)")
            }
            return (title: "Block User", content: "🚫 Block this user?")

        case .unblockUser:
            let targetUserId = params["target_user_id"] as? String ?? ""

            // Fetch the user to be unblocked
            let result = await orchestrator.executeTool(.getUserById, parameters: [
                "id": targetUserId
            ])

            if result.success,
               let responseData = result.response?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               let username = userData["username"] as? String,
               let name = userData["name"] as? String {
                return (title: "Unblock @\(username)", content: "✅ \(name)")
            }
            return (title: "Unblock User", content: "✅ Unblock this user?")

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
                return (title: "Block DMs from @\(username)", content: "🚫💬 \(name)")
            }
            return (title: "Block DMs", content: "🚫💬 Block DMs from this user?")

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
                return (title: "Unblock DMs from @\(username)", content: "✅💬 \(name)")
            }
            return (title: "Unblock DMs", content: "✅💬 Unblock DMs from this user?")

        // MARK: - Lists
        case .createList:
            let name = params["name"] as? String ?? ""
            let description = params["description"] as? String ?? ""
            let isPrivate = params["private"] as? Bool ?? false
            let privacy = isPrivate ? "🔒 Private" : "🌐 Public"
            return (title: "Create List", content: "📋 \(name)\n\(privacy)\n\n\(description)")

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
                return (title: "Delete List", content: "🗑️ \(listName)")
            }
            return (title: "Delete List", content: "🗑️ Delete this list?")

        case .updateList:
            let listId = params["id"] as? String ?? ""
            let name = params["name"] as? String
            let description = params["description"] as? String
            let isPrivate = params["private"] as? Bool

            var updates: [String] = []
            if let name = name { updates.append("Name: \(name)") }
            if let description = description { updates.append("Description: \(description)") }
            if let isPrivate = isPrivate {
                updates.append("Privacy: \(isPrivate ? "🔒 Private" : "🌐 Public")")
            }

            return (title: "Update List", content: "📋 \(updates.joined(separator: "\n"))")

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

            return (title: "Add to List", content: "📋 \(listName)\n➕ \(username)")

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

            return (title: "Remove from List", content: "📋 \(listName)\n➖ \(username)")

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
                return (title: "Pin List", content: "📌 \(listName)")
            }
            return (title: "Pin List", content: "📌 Pin this list?")

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
                return (title: "Unpin List", content: "📍 \(listName)")
            }
            return (title: "Unpin List", content: "📍 Unpin this list?")

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
                return (title: "Bookmark Tweet", content: "🔖 \"\(truncated)\"")
            }
            return (title: "Bookmark Tweet", content: "🔖 Save this tweet?")

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
                return (title: "Remove Bookmark", content: "🔖❌ \"\(truncated)\"")
            }
            return (title: "Remove Bookmark", content: "🔖❌ Remove bookmark?")

        // MARK: - Stream Rules
        case .manageStreamRules:
            var content: [String] = []

            if let add = params["add"] as? [[String: Any]] {
                let addRules = add.compactMap { $0["value"] as? String }
                if !addRules.isEmpty {
                    content.append("➕ Add rules:\n" + addRules.map { "  • \($0)" }.joined(separator: "\n"))
                }
            }

            if let delete = params["delete"] as? [String: Any],
               let ids = delete["ids"] as? [String] {
                if !ids.isEmpty {
                    content.append("➖ Delete \(ids.count) rule(s)")
                }
            }

            return (title: "Manage Stream Rules", content: content.joined(separator: "\n\n"))

        default:
            return (title: "Allow \(name)?", content: arguments)
        }
    }

    static func getToolByName(_ name: String) -> XTool? {
        return XTool.allCases.first { $0.name == name }
    }

    static var supportedTools: [Self] {
        [.createTweet, .replyToTweet, .quoteTweet, .createPollTweet, .deleteTweet, .getTweet, .getTweets, .searchRecentTweets, .getUserById, .getUserByUsername, .sendDMToParticipant, .sendDMToConversation]
    }
}
