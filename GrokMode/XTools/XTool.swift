//
//  XTool.swift
//  XTools
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import Foundation
import JSONSchema
internal import OrderedCollections

enum XTool: String, CaseIterable, Identifiable {
    // MARK: - Posts/Tweets
    case createTweet = "create_tweet"
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

    // MARK: - Integrations
    case createLinearTicket = "create_linear_ticket"

    // MARK: - Media
    case uploadMedia = "upload_media"
    case getMediaStatus = "get_media_status"
    case initializeChunkedUpload = "initialize_chunked_upload"
    case appendChunkedUpload = "append_chunked_upload"
    case finalizeChunkedUpload = "finalize_chunked_upload"
    case createMediaMetadata = "create_media_metadata"
    case getMediaAnalytics = "get_media_analytics"

    var id: String { rawValue }
    var name: String { rawValue }

    var description: String {
        switch self {
        // Posts/Tweets
        case .createTweet: return "Create or edit a tweet"
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

        // Integrations
        case .createLinearTicket: return "Create a new ticket in Linear for engineering. Use this when the CEO asks to fix a bug or add a feature based on tweets."

        // Media
        case .uploadMedia: return "Upload media file"
        case .getMediaStatus: return "Get media upload status"
        case .initializeChunkedUpload: return "Initialize chunked media upload"
        case .appendChunkedUpload: return "Append data to chunked upload"
        case .finalizeChunkedUpload: return "Finalize chunked upload"
        case .createMediaMetadata: return "Create media metadata"
        case .getMediaAnalytics: return "Get media analytics"
        }
    }

    var jsonSchema: JSONSchema {
        switch self {
        // MARK: - Posts/Tweets
        case .createTweet:
            return .object(
                properties: [
                    "text": .string(description: "The text content of the tweet"),
                    "reply": .object(
                        properties: [
                            "in_reply_to_tweet_id": .string(description: "Tweet ID to reply to"),
                            "exclude_reply_user_ids": .array(description: "User IDs to exclude from reply", items: .string())
                        ],
                        required: ["in_reply_to_tweet_id"]
                    ),
                    "quote_tweet_id": .string(description: "Tweet ID to quote"),
                    "media": .object(
                        properties: [
                            "media_ids": .array(description: "Media IDs to attach", items: .string()),
                            "tagged_user_ids": .array(description: "IDs of users tagged in media", items: .string())
                        ],
                        required: ["media_ids"]
                    ),
                    "poll": .object(
                        properties: [
                            "options": .array(description: "Poll options, the text of a poll choice", items: .string()),
                            "duration_minutes": .integer(description: "Poll duration in minutes"),
                            "reply_settings": .string(description: "Settings to indicate who can reply to the Tweet.", enum: [.string("following"), .string("mentionedUsers"), .string("subscribers"), .string("verified")])
                        ],
                        required: ["options", "duration_minutes"]
                    ),
                    "direct_message_deep_link": .string(description: "Link to take the conversation from the public timeline to a private Direct Message."),
                    "for_super_followers_only": .boolean(description: "Restrict to super followers only", default: false),
                    "reply_settings": .string(
                        description: "Who can reply to the tweet",
                        enum: ["everyone", "mentionedUsers", "following", "verified"]
                    )
                ],
                required: ["text"]
            )

        case .deleteTweet:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID to delete")
                ],
                required: ["id"]
            )

        case .getTweet:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID"),
                    "tweet.fields": .array(
                        description: "A comma separated list of Tweet fields to display.",
                        items: .string(
                            enum: [
                                "article", "attachments", "author_id", "card_uri", "community_id",
                                "context_annotations", "conversation_id", "created_at", "display_text_range",
                                "edit_controls", "edit_history_tweet_ids", "entities", "geo", "id",
                                "in_reply_to_user_id", "lang", "media_metadata", "non_public_metrics",
                                "note_tweet", "organic_metrics", "possibly_sensitive", "promoted_metrics",
                                "public_metrics", "referenced_tweets", "reply_settings", "scopes",
                                "source", "suggested_source_links", "text", "withheld"
                            ]
                        )
                    ),
                    "expansions": .array(
                        description: " The list of fields you can expand for a Tweet object. If the field has an ID, it can be expanded into a full object.",
                        items: .string(
                            enum: [
                                "article.cover_media", "article.media_entities", "attachments.media_keys",
                                "attachments.media_source_tweet", "attachments.poll_ids", "author_id",
                                "edit_history_tweet_ids", "entities.mentions.username", "geo.place_id",
                                "in_reply_to_user_id", "entities.note.mentions.username", "referenced_tweets.id",
                                "referenced_tweets.id.attachments.media_keys", "referenced_tweets.id.author_id"
                            ]
                        )
                    ),
                    "media.fields": .array(
                        description: "A comma separated list of Media fields to display",
                        items: .string(
                            enum: [
                                "alt_text", "duration_ms", "height", "media_key", "non_public_metrics",
                                "organic_metrics", "preview_image_url", "promoted_metrics", "public_metrics",
                                "type", "url", "variants", "width"
                            ]
                        )
                    ),
                    "poll.fields": .array(
                        description: "A comma separated list of Poll fields to display",
                        items: .string(
                            enum: [
                                "duration_minutes", "end_datetime", "id", "options", "voting_status"
                            ]
                        )
                    ),
                    "user.fields": .array(
                        description: "A comma separated list of User fields to display",
                        items: .string(
                            enum: [
                                "affiliation", "confirmed_email", "connection_status", "created_at", "description",
                                "entities", "id", "is_identity_verified", "location", "most_recent_tweet_id",
                                "name", "parody", "pinned_tweet_id", "profile_banner_url", "profile_image_url",
                                "protected", "public_metrics", "receives_your_dm", "subscription", "subscription_type",
                                "url", "username", "verified", "verified_followers_count", "verified_type", "withheld"
                            ]
                        )
                    ),
                    "place.fields": .array(
                        description: "A comma separated list of Place fields to display",
                        items: .string(
                            enum: [
                                "contained_within", "country", "country_code", "full_name", "geo", "id", "name", "place_type"
                            ]
                        )
                    )
                ],
                required: ["id"]
            )

        case .getTweets:
            return .object(
                properties: [
                    "ids": .array(description: "Tweet IDs", items: .string()),
                    "tweet.fields": .array(
                        description: "A comma separated list of Tweet fields to display.",
                        items: .string(
                            enum: [
                                "article", "attachments", "author_id", "card_uri", "community_id",
                                "context_annotations", "conversation_id", "created_at", "display_text_range",
                                "edit_controls", "edit_history_tweet_ids", "entities", "geo", "id",
                                "in_reply_to_user_id", "lang", "media_metadata", "non_public_metrics",
                                "note_tweet", "organic_metrics", "possibly_sensitive", "promoted_metrics",
                                "public_metrics", "referenced_tweets", "reply_settings", "scopes",
                                "source", "suggested_source_links", "text", "withheld"
                            ]
                        )
                    ),
                    "expansions": .array(
                        description: " The list of fields you can expand for a Tweet object. If the field has an ID, it can be expanded into a full object.",
                        items: .string(
                            enum: [
                                "article.cover_media", "article.media_entities", "attachments.media_keys",
                                "attachments.media_source_tweet", "attachments.poll_ids", "author_id",
                                "edit_history_tweet_ids", "entities.mentions.username", "geo.place_id",
                                "in_reply_to_user_id", "entities.note.mentions.username", "referenced_tweets.id",
                                "referenced_tweets.id.attachments.media_keys", "referenced_tweets.id.author_id"
                            ]
                        )
                    ),
                    "media.fields": .array(
                        description: "A comma separated list of Media fields to display",
                        items: .string(
                            enum: [
                                "alt_text", "duration_ms", "height", "media_key", "non_public_metrics",
                                "organic_metrics", "preview_image_url", "promoted_metrics", "public_metrics",
                                "type", "url", "variants", "width"
                            ]
                        )
                    ),
                    "poll.fields": .array(
                        description: "A comma separated list of Poll fields to display",
                        items: .string(
                            enum: [
                                "duration_minutes", "end_datetime", "id", "options", "voting_status"
                            ]
                        )
                    ),
                    "user.fields": .array(
                        description: "A comma separated list of User fields to display",
                        items: .string(
                            enum: [
                                "affiliation", "confirmed_email", "connection_status", "created_at", "description",
                                "entities", "id", "is_identity_verified", "location", "most_recent_tweet_id",
                                "name", "parody", "pinned_tweet_id", "profile_banner_url", "profile_image_url",
                                "protected", "public_metrics", "receives_your_dm", "subscription", "subscription_type",
                                "url", "username", "verified", "verified_followers_count", "verified_type", "withheld"
                            ]
                        )
                    ),
                    "place.fields": .array(
                        description: "A comma separated list of Place fields to display",
                        items: .string(
                            enum: [
                                "contained_within", "country", "country_code", "full_name", "geo", "id", "name", "place_type"
                            ]
                        )
                    )
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
                    "next_token": .string(description: "This parameter is used to get the next 'page' of results. The value used with the parameter is pulled directly from the response provided by the API, and should not be modified. "),
                    "pagination_token": .string(description: "This parameter is used to get the next 'page' of results. The value used with the parameter is pulled directly from the response provided by the API, and should not be modified."),
                    "sort_order": .string(description: "This order in which to return results.", enum: ["recency", "relevancy"]),
                    "tweet.fields": .array(
                        description: "A comma separated list of Tweet fields to display.",
                        items: .string(
                            enum: [
                                "article", "attachments", "author_id", "card_uri", "community_id",
                                "context_annotations", "conversation_id", "created_at", "display_text_range",
                                "edit_controls", "edit_history_tweet_ids", "entities", "geo", "id",
                                "in_reply_to_user_id", "lang", "media_metadata", "non_public_metrics",
                                "note_tweet", "organic_metrics", "possibly_sensitive", "promoted_metrics",
                                "public_metrics", "referenced_tweets", "reply_settings", "scopes",
                                "source", "suggested_source_links", "text", "withheld"
                            ]
                        )
                    ),
                    "expansions": .array(
                        description: " The list of fields you can expand for a Tweet object. If the field has an ID, it can be expanded into a full object.",
                        items: .string(
                            enum: [
                                "article.cover_media", "article.media_entities", "attachments.media_keys",
                                "attachments.media_source_tweet", "attachments.poll_ids", "author_id",
                                "edit_history_tweet_ids", "entities.mentions.username", "geo.place_id",
                                "in_reply_to_user_id", "entities.note.mentions.username", "referenced_tweets.id",
                                "referenced_tweets.id.attachments.media_keys", "referenced_tweets.id.author_id"
                            ]
                        )
                    ),
                    "media.fields": .array(
                        description: "A comma separated list of Media fields to display",
                        items: .string(
                            enum: [
                                "alt_text", "duration_ms", "height", "media_key", "non_public_metrics",
                                "organic_metrics", "preview_image_url", "promoted_metrics", "public_metrics",
                                "type", "url", "variants", "width"
                            ]
                        )
                    ),
                    "poll.fields": .array(
                        description: "A comma separated list of Poll fields to display",
                        items: .string(
                            enum: [
                                "duration_minutes", "end_datetime", "id", "options", "voting_status"
                            ]
                        )
                    ),
                    "user.fields": .array(
                        description: "A comma separated list of User fields to display",
                        items: .string(
                            enum: [
                                "affiliation", "confirmed_email", "connection_status", "created_at", "description",
                                "entities", "id", "is_identity_verified", "location", "most_recent_tweet_id",
                                "name", "parody", "pinned_tweet_id", "profile_banner_url", "profile_image_url",
                                "protected", "public_metrics", "receives_your_dm", "subscription", "subscription_type",
                                "url", "username", "verified", "verified_followers_count", "verified_type", "withheld"
                            ]
                        )
                    ),
                    "place.fields": .array(
                        description: "A comma separated list of Place fields to display",
                        items: .string(
                            enum: [
                                "contained_within", "country", "country_code", "full_name", "geo", "id", "name", "place_type"
                            ]
                        )
                    )
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
                    "next_token": .string(description: "This parameter is used to get the next 'page' of results. The value used with the parameter is pulled directly from the response provided by the API, and should not be modified. "),
                    "pagination_token": .string(description: "This parameter is used to get the next 'page' of results. The value used with the parameter is pulled directly from the response provided by the API, and should not be modified."),
                    "sort_order": .string(description: "This order in which to return results.", enum: ["recency", "relevancy"]),
                    "tweet.fields": .array(
                        description: "A comma separated list of Tweet fields to display.",
                        items: .string(
                            enum: [
                                "article", "attachments", "author_id", "card_uri", "community_id",
                                "context_annotations", "conversation_id", "created_at", "display_text_range",
                                "edit_controls", "edit_history_tweet_ids", "entities", "geo", "id",
                                "in_reply_to_user_id", "lang", "media_metadata", "non_public_metrics",
                                "note_tweet", "organic_metrics", "possibly_sensitive", "promoted_metrics",
                                "public_metrics", "referenced_tweets", "reply_settings", "scopes",
                                "source", "suggested_source_links", "text", "withheld"
                            ]
                        )
                    ),
                    "expansions": .array(
                        description: " The list of fields you can expand for a Tweet object. If the field has an ID, it can be expanded into a full object.",
                        items: .string(
                            enum: [
                                "article.cover_media", "article.media_entities", "attachments.media_keys",
                                "attachments.media_source_tweet", "attachments.poll_ids", "author_id",
                                "edit_history_tweet_ids", "entities.mentions.username", "geo.place_id",
                                "in_reply_to_user_id", "entities.note.mentions.username", "referenced_tweets.id",
                                "referenced_tweets.id.attachments.media_keys", "referenced_tweets.id.author_id"
                            ]
                        )
                    ),
                    "media.fields": .array(
                        description: "A comma separated list of Media fields to display",
                        items: .string(
                            enum: [
                                "alt_text", "duration_ms", "height", "media_key", "non_public_metrics",
                                "organic_metrics", "preview_image_url", "promoted_metrics", "public_metrics",
                                "type", "url", "variants", "width"
                            ]
                        )
                    ),
                    "poll.fields": .array(
                        description: "A comma separated list of Poll fields to display",
                        items: .string(
                            enum: [
                                "duration_minutes", "end_datetime", "id", "options", "voting_status"
                            ]
                        )
                    ),
                    "user.fields": .array(
                        description: "A comma separated list of User fields to display",
                        items: .string(
                            enum: [
                                "affiliation", "confirmed_email", "connection_status", "created_at", "description",
                                "entities", "id", "is_identity_verified", "location", "most_recent_tweet_id",
                                "name", "parody", "pinned_tweet_id", "profile_banner_url", "profile_image_url",
                                "protected", "public_metrics", "receives_your_dm", "subscription", "subscription_type",
                                "url", "username", "verified", "verified_followers_count", "verified_type", "withheld"
                            ]
                        )
                    ),
                    "place.fields": .array(
                        description: "A comma separated list of Place fields to display",
                        items: .string(
                            enum: [
                                "contained_within", "country", "country_code", "full_name", "geo", "id", "name", "place_type"
                            ]
                        )
                    )
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
                properties: [
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "place.fields": .string(description: "Comma-separated list of place fields"),
                    "poll.fields": .string(description: "Comma-separated list of poll fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ]
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
                    "id": .string(description: "The user ID"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["id"]
            )

        case .getUserByUsername:
            return .object(
                properties: [
                    "username": .string(description: "The username without @"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["username"]
            )

        case .getUsersById:
            return .object(
                properties: [
                    "ids": .array(description: "User IDs", items: .string()),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["ids"]
            )

        case .getUsersByUsername:
            return .object(
                properties: [
                    "usernames": .array(description: "Usernames without @", items: .string()),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["usernames"]
            )

        case .getAuthenticatedUser:
            return .object(
                properties: [
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ]
            )

        case .getUserFollowing:
            return .object(
                properties: [
                    "id": .string(description: "The user ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 1000),
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
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
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["id"]
            )

        case .getMutedUsers:
            return .object(
                properties: [
                    "id": .string(description: "The user ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 1000),
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
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
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
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
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "place.fields": .string(description: "Comma-separated list of place fields"),
                    "poll.fields": .string(description: "Comma-separated list of poll fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
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
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "place.fields": .string(description: "Comma-separated list of place fields"),
                    "poll.fields": .string(description: "Comma-separated list of poll fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["id"]
            )

        // MARK: - Retweets
        case .getRetweetedBy:
            return .object(
                properties: [
                    "id": .string(description: "The tweet ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "place.fields": .string(description: "Comma-separated list of place fields"),
                    "poll.fields": .string(description: "Comma-separated list of poll fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
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
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "place.fields": .string(description: "Comma-separated list of place fields"),
                    "poll.fields": .string(description: "Comma-separated list of poll fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
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
                    "id": .string(description: "The list ID"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "list.fields": .string(description: "Comma-separated list of list fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["id"]
            )

        case .getListMembers:
            return .object(
                properties: [
                    "id": .string(description: "The list ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
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
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "place.fields": .string(description: "Comma-separated list of place fields"),
                    "poll.fields": .string(description: "Comma-separated list of poll fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["id"]
            )

        case .getListFollowers:
            return .object(
                properties: [
                    "id": .string(description: "The list ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "list.fields": .string(description: "Comma-separated list of list fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
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
                required: ["conversation_type", "message"]
            )

        case .sendDMToConversation:
            return .object(
                properties: [
                    "dm_conversation_id": .string(description: "DM conversation ID"),
                    "text": .string(description: "Message text"),
                    "attachments": .array(
                        description: "Media attachments",
                        items: .object(
                            properties: [
                                "media_id": .string(description: "Media ID")
                            ]
                        )
                    )
                ],
                required: ["dm_conversation_id"]
            )

        case .sendDMToParticipant:
            return .object(
                properties: [
                    "participant_id": .string(description: "Recipient user ID"),
                    "text": .string(description: "Message text"),
                    "attachments": .array(
                        description: "Media attachments", items: .object(
                            properties: [
                                "media_id": .string(description: "Media ID")
                            ]
                        )
                    )
                ],
                required: ["participant_id"]
            )

        case .getDMEvents:
            return .object(
                properties: [
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Pagination token"),
                    "event_types": .string(description: "Comma-separated event types"),
                    "dm_event.fields": .string(description: "Comma-separated DM event fields"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields")
                ]
            )

        case .getConversationDMs:
            return .object(
                properties: [
                    "id": .string(description: "Conversation ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Pagination token"),
                    "event_types": .string(description: "Comma-separated event types"),
                    "dm_event.fields": .string(description: "Comma-separated DM event fields"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields")
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
                    "id": .string(description: "DM event ID"),
                    "dm_event.fields": .string(description: "Comma-separated DM event fields"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields")
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
                    "pagination_token": .string(description: "Pagination token"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "media.fields": .string(description: "Comma-separated list of media fields"),
                    "place.fields": .string(description: "Comma-separated list of place fields"),
                    "poll.fields": .string(description: "Comma-separated list of poll fields"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["id"]
            )

        // MARK: - Spaces
        case .getSpace:
            return .object(
                properties: [
                    "id": .string(description: "The space ID"),
                    "space.fields": .string(description: "Comma-separated space fields"),
                    "expansions": .string(description: "Comma-separated list of expansions")
                ],
                required: ["id"]
            )

        case .getSpaces:
            return .object(
                properties: [
                    "ids": .array(description: "Space IDs", items: .string()),
                    "space.fields": .string(description: "Comma-separated space fields"),
                    "expansions": .string(description: "Comma-separated list of expansions")
                ],
                required: ["ids"]
            )

        case .getSpacesByCreator:
            return .object(
                properties: [
                    "user_ids": .array(description: "Creator user IDs", items: .string()),
                    "space.fields": .string(description: "Comma-separated space fields"),
                    "expansions": .string(description: "Comma-separated list of expansions")
                ],
                required: ["user_ids"]
            )

        case .getSpaceTweets:
            return .object(
                properties: [
                    "id": .string(description: "The space ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "space.fields": .string(description: "Comma-separated space fields"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "tweet.fields": .string(description: "Comma-separated list of tweet fields"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
                ],
                required: ["id"]
            )

        case .searchSpaces:
            return .object(
                properties: [
                    "query": .string(description: "Search query"),
                    "state": .string(description: "Space state", enum: ["live", "scheduled", "ended"]),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "space.fields": .string(description: "Comma-separated space fields"),
                    "expansions": .string(description: "Comma-separated list of expansions")
                ],
                required: ["query"]
            )

        case .getSpaceBuyers:
            return .object(
                properties: [
                    "id": .string(description: "The space ID"),
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "space.fields": .string(description: "Comma-separated space fields"),
                    "expansions": .string(description: "Comma-separated list of expansions"),
                    "user.fields": .string(description: "Comma-separated list of user fields")
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
                    "pagination_token": .string(description: "Pagination token")
                ]
            )

        case .getPostsEligibleForNotes:
            return .object(
                properties: [
                    "max_results": .integer(description: "Maximum results", minimum: 1, maximum: 100),
                    "pagination_token": .string(description: "Pagination token")
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


        // MARK: - Integrations
        case .createLinearTicket:
            return .object(
                properties: [
                    "title": .string(description: "Title of the ticket"),
                    "description": .string(description: "Detailed description. MUST include tweet links and instructions.")
                ],
                required: ["title", "description"]
            )
        }
    }
}

// MARK: - XTool Extensions
extension XTool {
    static func getToolByName(_ name: String) -> XTool? {
        return XTool.allCases.first { $0.name == name }
    }

    static var supportedTools: [Self] {
        [.createTweet, .deleteTweet, .getTweet, .getTweets, .searchRecentTweets, .searchAllTweets, .getUserById, .getUserByUsername]
    }
}
