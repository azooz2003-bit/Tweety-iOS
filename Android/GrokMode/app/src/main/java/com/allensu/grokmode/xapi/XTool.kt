package com.allensu.grokmode.xapi

import org.json.JSONArray
import org.json.JSONObject

/**
 * Defines whether a tool requires user confirmation before execution.
 */
enum class PreviewBehavior {
    NONE,                   // Safe tools, auto-execute
    REQUIRES_CONFIRMATION   // Needs user approval with preview
}

/**
 * All X API tools available for voice assistant.
 * Ported from iOS XTool.swift implementation.
 */
enum class XTool(val toolName: String) {
    // MARK: - Posts/Tweets
    CREATE_TWEET("create_tweet"),
    REPLY_TO_TWEET("reply_to_tweet"),
    QUOTE_TWEET("quote_tweet"),
    CREATE_POLL_TWEET("create_poll_tweet"),
    DELETE_TWEET("delete_tweet"),
    EDIT_TWEET("edit_tweet"),
    GET_TWEET("get_tweet"),
    GET_TWEETS("get_tweets"),
    GET_USER_TWEETS("get_user_tweets"),
    GET_USER_MENTIONS("get_user_mentions"),
    GET_HOME_TIMELINE("get_home_timeline"),
    SEARCH_RECENT_TWEETS("search_recent_tweets"),
    SEARCH_ALL_TWEETS("search_all_tweets"),
    GET_RECENT_TWEET_COUNTS("get_recent_tweet_counts"),
    GET_ALL_TWEET_COUNTS("get_all_tweet_counts"),

    // MARK: - Users
    GET_USER_BY_ID("get_user_by_id"),
    GET_USER_BY_USERNAME("get_user_by_username"),
    GET_USERS_BY_ID("get_users_by_id"),
    GET_USERS_BY_USERNAME("get_users_by_username"),
    GET_AUTHENTICATED_USER("get_authenticated_user"),
    GET_USER_FOLLOWING("get_user_following"),
    FOLLOW_USER("follow_user"),
    UNFOLLOW_USER("unfollow_user"),
    GET_USER_FOLLOWERS("get_user_followers"),
    GET_MUTED_USERS("get_muted_users"),
    MUTE_USER("mute_user"),
    UNMUTE_USER("unmute_user"),
    GET_BLOCKED_USERS("get_blocked_users"),
    BLOCK_USER_DMS("block_user_dms"),
    UNBLOCK_USER_DMS("unblock_user_dms"),

    // MARK: - Likes
    GET_LIKING_USERS("get_liking_users"),
    LIKE_TWEET("like_tweet"),
    UNLIKE_TWEET("unlike_tweet"),
    GET_USER_LIKED_TWEETS("get_user_liked_tweets"),

    // MARK: - Retweets
    GET_RETWEETED_BY("get_retweeted_by"),
    RETWEET("retweet"),
    UNRETWEET("unretweet"),
    GET_RETWEETS("get_retweets"),
    GET_REPOSTS_OF_ME("get_reposts_of_me"),

    // MARK: - Lists
    CREATE_LIST("create_list"),
    DELETE_LIST("delete_list"),
    UPDATE_LIST("update_list"),
    GET_LIST("get_list"),
    GET_LIST_MEMBERS("get_list_members"),
    ADD_LIST_MEMBER("add_list_member"),
    REMOVE_LIST_MEMBER("remove_list_member"),
    GET_LIST_TWEETS("get_list_tweets"),
    GET_LIST_FOLLOWERS("get_list_followers"),
    PIN_LIST("pin_list"),
    UNPIN_LIST("unpin_list"),
    GET_PINNED_LISTS("get_pinned_lists"),
    GET_OWNED_LISTS("get_owned_lists"),
    GET_FOLLOWED_LISTS("get_followed_lists"),
    FOLLOW_LIST("follow_list"),
    UNFOLLOW_LIST("unfollow_list"),
    GET_LIST_MEMBERSHIPS("get_list_memberships"),

    // MARK: - Direct Messages
    CREATE_DM_CONVERSATION("create_dm_conversation"),
    SEND_DM_TO_CONVERSATION("send_dm_to_conversation"),
    SEND_DM_TO_PARTICIPANT("send_dm_to_participant"),
    GET_DM_EVENTS("get_dm_events"),
    GET_CONVERSATION_DMS("get_conversation_dms"),
    DELETE_DM_EVENT("delete_dm_event"),
    GET_DM_EVENT_DETAILS("get_dm_event_details"),

    // MARK: - Bookmarks
    ADD_BOOKMARK("add_bookmark"),
    REMOVE_BOOKMARK("remove_bookmark"),
    GET_USER_BOOKMARKS("get_user_bookmarks"),

    // MARK: - Trends
    GET_PERSONALIZED_TRENDS("get_personalized_trends"),

    // MARK: - Community Notes
    CREATE_NOTE("create_note"),
    DELETE_NOTE("delete_note"),
    EVALUATE_NOTE("evaluate_note"),
    GET_NOTES_WRITTEN("get_notes_written"),
    GET_POSTS_ELIGIBLE_FOR_NOTES("get_posts_eligible_for_notes"),

    // MARK: - Media
    UPLOAD_MEDIA("upload_media"),
    GET_MEDIA_STATUS("get_media_status"),
    INITIALIZE_CHUNKED_UPLOAD("initialize_chunked_upload"),
    APPEND_CHUNKED_UPLOAD("append_chunked_upload"),
    FINALIZE_CHUNKED_UPLOAD("finalize_chunked_upload"),
    CREATE_MEDIA_METADATA("create_media_metadata"),
    GET_MEDIA_ANALYTICS("get_media_analytics"),

    // MARK: - News
    GET_NEWS_BY_ID("get_news_by_id"),
    SEARCH_NEWS("search_news"),

    // MARK: - Voice Confirmation
    CONFIRM_ACTION("confirm_action"),
    CANCEL_ACTION("cancel_action");

    val description: String
        get() = when (this) {
            // Posts/Tweets
            CREATE_TWEET -> "Create or edit a tweet"
            REPLY_TO_TWEET -> "Reply to a specific tweet."
            QUOTE_TWEET -> "Quote tweet a specific tweet."
            CREATE_POLL_TWEET -> "Create a poll tweet"
            DELETE_TWEET -> "Delete a specific tweet by ID"
            EDIT_TWEET -> "Edit an existing tweet"
            GET_TWEET -> "Get details of a specific tweet by ID"
            GET_TWEETS -> "Get multiple tweets by their IDs"
            GET_USER_TWEETS -> "Get tweets posted by a specific user"
            GET_USER_MENTIONS -> "Get tweets mentioning a specific user"
            GET_HOME_TIMELINE -> "Get the authenticated user's home timeline"
            SEARCH_RECENT_TWEETS -> "Search tweets from the last 7 days"
            SEARCH_ALL_TWEETS -> "Search tweets from the full archive"
            GET_RECENT_TWEET_COUNTS -> "Get tweet counts for recent tweets"
            GET_ALL_TWEET_COUNTS -> "Get tweet counts from full archive"

            // Users
            GET_USER_BY_ID -> "Get user details by user ID"
            GET_USER_BY_USERNAME -> "Get user details by username"
            GET_USERS_BY_ID -> "Get multiple users by their IDs"
            GET_USERS_BY_USERNAME -> "Get multiple users by usernames"
            GET_AUTHENTICATED_USER -> "Get authenticated user details"
            GET_USER_FOLLOWING -> "Get list of users followed by a user"
            FOLLOW_USER -> "Follow a user"
            UNFOLLOW_USER -> "Unfollow a user"
            GET_USER_FOLLOWERS -> "Get a user's followers"
            GET_MUTED_USERS -> "Get list of muted users"
            MUTE_USER -> "Mute a user"
            UNMUTE_USER -> "Unmute a user"
            GET_BLOCKED_USERS -> "Get list of blocked users"
            BLOCK_USER_DMS -> "Block DMs from a user"
            UNBLOCK_USER_DMS -> "Unblock DMs from a user"

            // Likes
            GET_LIKING_USERS -> "Get users who liked a tweet"
            LIKE_TWEET -> "Like a tweet"
            UNLIKE_TWEET -> "Unlike a tweet"
            GET_USER_LIKED_TWEETS -> "Get tweets liked by a user"

            // Retweets
            GET_RETWEETED_BY -> "Get users who retweeted a tweet"
            RETWEET -> "Retweet a tweet"
            UNRETWEET -> "Remove a retweet"
            GET_RETWEETS -> "Get retweet posts of a specific tweet"
            GET_REPOSTS_OF_ME -> "Get reposts of the authenticated user's tweets"

            // Lists
            CREATE_LIST -> "Create a new list"
            DELETE_LIST -> "Delete a list"
            UPDATE_LIST -> "Update list details"
            GET_LIST -> "Get list details by ID"
            GET_LIST_MEMBERS -> "Get members of a list"
            ADD_LIST_MEMBER -> "Add a member to a list"
            REMOVE_LIST_MEMBER -> "Remove a member from a list"
            GET_LIST_TWEETS -> "Get tweets from a list"
            GET_LIST_FOLLOWERS -> "Get followers of a list"
            PIN_LIST -> "Pin a list"
            UNPIN_LIST -> "Unpin a list"
            GET_PINNED_LISTS -> "Get pinned lists for a user"
            GET_OWNED_LISTS -> "Get lists owned by a user"
            GET_FOLLOWED_LISTS -> "Get lists followed by a user"
            FOLLOW_LIST -> "Follow a list"
            UNFOLLOW_LIST -> "Unfollow a list"
            GET_LIST_MEMBERSHIPS -> "Get lists that a user is a member of"

            // Direct Messages
            CREATE_DM_CONVERSATION -> "Create a new DM conversation"
            SEND_DM_TO_CONVERSATION -> "Send a DM to a conversation"
            SEND_DM_TO_PARTICIPANT -> "Send a DM by participant ID"
            GET_DM_EVENTS -> "Get recent DM events"
            GET_CONVERSATION_DMS -> "Get messages for a conversation"
            DELETE_DM_EVENT -> "Delete a DM event"
            GET_DM_EVENT_DETAILS -> "Get DM event details"

            // Bookmarks
            ADD_BOOKMARK -> "Add a tweet to bookmarks"
            REMOVE_BOOKMARK -> "Remove a tweet from bookmarks"
            GET_USER_BOOKMARKS -> "Get user's bookmarked tweets"

            // Trends
            GET_PERSONALIZED_TRENDS -> "Get personalized trending topics"

            // Community Notes
            CREATE_NOTE -> "Create a community note"
            DELETE_NOTE -> "Delete a community note"
            EVALUATE_NOTE -> "Evaluate a community note"
            GET_NOTES_WRITTEN -> "Get notes written by user"
            GET_POSTS_ELIGIBLE_FOR_NOTES -> "Get posts eligible for notes"

            // Media
            UPLOAD_MEDIA -> "Upload media file"
            GET_MEDIA_STATUS -> "Get media upload status"
            INITIALIZE_CHUNKED_UPLOAD -> "Initialize chunked media upload"
            APPEND_CHUNKED_UPLOAD -> "Append data to chunked upload"
            FINALIZE_CHUNKED_UPLOAD -> "Finalize chunked upload"
            CREATE_MEDIA_METADATA -> "Create media metadata"
            GET_MEDIA_ANALYTICS -> "Get media analytics"

            // News
            GET_NEWS_BY_ID -> "Get news story by ID"
            SEARCH_NEWS -> "Search news stories"

            // Voice Confirmation
            CONFIRM_ACTION -> "Confirms and executes the pending action when the user says 'yes', 'confirm', 'do it', or similar affirmations"
            CANCEL_ACTION -> "Cancels the pending action when the user says 'no', 'cancel', 'don't', or similar rejections"
        }

    val previewBehavior: PreviewBehavior
        get() = when (this) {
            // Write operations require confirmation
            CREATE_TWEET, REPLY_TO_TWEET, QUOTE_TWEET, CREATE_POLL_TWEET, DELETE_TWEET, EDIT_TWEET,
            LIKE_TWEET, UNLIKE_TWEET, RETWEET, UNRETWEET,
            FOLLOW_USER, UNFOLLOW_USER,
            MUTE_USER, UNMUTE_USER,
            BLOCK_USER_DMS, UNBLOCK_USER_DMS,
            CREATE_LIST, DELETE_LIST, UPDATE_LIST, ADD_LIST_MEMBER, REMOVE_LIST_MEMBER,
            PIN_LIST, UNPIN_LIST, FOLLOW_LIST, UNFOLLOW_LIST,
            CREATE_DM_CONVERSATION, SEND_DM_TO_CONVERSATION, SEND_DM_TO_PARTICIPANT, DELETE_DM_EVENT,
            ADD_BOOKMARK, REMOVE_BOOKMARK -> PreviewBehavior.REQUIRES_CONFIRMATION

            // Voice confirmation tools must execute immediately
            CONFIRM_ACTION, CANCEL_ACTION -> PreviewBehavior.NONE

            // All read-only operations are safe
            else -> PreviewBehavior.NONE
        }

    val displayName: String
        get() = toolName.split("_").joinToString(" ") {
            it.replaceFirstChar { char -> char.uppercase() }
        }

    /**
     * Returns the JSON Schema for this tool's parameters.
     * Used by the voice service to configure available tools.
     */
    fun getJsonSchema(): JSONObject {
        return when (this) {
            // MARK: - Posts/Tweets
            CREATE_TWEET -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "text" to stringProp("The text content of the tweet"),
                        "reply_settings" to stringProp(
                            "Who can reply to the tweet. Note: To allow everyone to reply, do not include this field.",
                            enumValues = listOf("following", "mentionedUsers", "subscribers", "verified")
                        )
                    ),
                    required = listOf("text")
                )
            }

            REPLY_TO_TWEET -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "text" to stringProp("The text content of the reply tweet."),
                        "reply" to objectProp(
                            properties = mapOf(
                                "in_reply_to_tweet_id" to stringProp("The ID of the tweet you would like to reply to.")
                            ),
                            required = listOf("in_reply_to_tweet_id")
                        ),
                        "reply_settings" to stringProp(
                            "Who can reply to the tweet.",
                            enumValues = listOf("following", "mentionedUsers", "subscribers", "verified")
                        )
                    ),
                    required = listOf("text", "reply")
                )
            }

            QUOTE_TWEET -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "text" to stringProp("The text content of the tweet"),
                        "quote_tweet_id" to stringProp("The ID of the tweet you would like to quote tweet."),
                        "reply_settings" to stringProp(
                            "Who can reply to the tweet.",
                            enumValues = listOf("following", "mentionedUsers", "subscribers", "verified")
                        )
                    ),
                    required = listOf("text", "quote_tweet_id")
                )
            }

            CREATE_POLL_TWEET -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "text" to stringProp("The text content of the tweet"),
                        "poll" to objectProp(
                            properties = mapOf(
                                "options" to arrayProp("An array of poll choices as strings. Min 2, max 4.", stringProp()),
                                "duration_minutes" to integerProp("Poll duration in minutes. 5 <= x <= 10080."),
                                "reply_settings" to stringProp(
                                    "Who can reply to the poll.",
                                    enumValues = listOf("following", "mentionedUsers", "subscribers", "verified")
                                )
                            ),
                            required = listOf("options", "duration_minutes")
                        ),
                        "reply_settings" to stringProp(
                            "Who can reply to the tweet.",
                            enumValues = listOf("following", "mentionedUsers", "subscribers", "verified")
                        )
                    ),
                    required = listOf("text", "poll")
                )
            }

            DELETE_TWEET -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The tweet ID to delete.")
                    ),
                    required = listOf("id")
                )
            }

            EDIT_TWEET -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "previous_post_id" to stringProp("The ID of the tweet to edit."),
                        "text" to stringProp("The new text content for the tweet")
                    ),
                    required = listOf("previous_post_id", "text")
                )
            }

            GET_TWEET -> jsonSchema {
                objectType(
                    properties = mapOf("id" to stringProp("The tweet ID")),
                    required = listOf("id")
                )
            }

            GET_TWEETS -> jsonSchema {
                objectType(
                    properties = mapOf("ids" to arrayProp("Tweet IDs", stringProp())),
                    required = listOf("ids")
                )
            }

            GET_USER_TWEETS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The user ID whose tweets to retrieve"),
                        "max_results" to integerProp("Maximum number of tweets. 5-100, default 10."),
                        "exclude" to arrayProp("Tweet types to exclude", stringProp(enumValues = listOf("retweets", "replies")))
                    ),
                    required = listOf("id")
                )
            }

            GET_USER_MENTIONS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The user ID whose mentions to retrieve"),
                        "max_results" to integerProp("Maximum number of mentions. 5-100, default 10.")
                    ),
                    required = listOf("id")
                )
            }

            GET_HOME_TIMELINE -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The ID of the authenticated user."),
                        "max_results" to integerProp("Maximum number of tweets. 1-100, default 10."),
                        "exclude" to arrayProp("Tweet types to exclude", stringProp(enumValues = listOf("retweets", "replies")))
                    ),
                    required = listOf("id")
                )
            }

            SEARCH_RECENT_TWEETS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "query" to stringProp("Search query"),
                        "max_results" to integerProp("Max results. 10-100.", min = 10, max = 100),
                        "sort_order" to stringProp("Result order", enumValues = listOf("recency", "relevancy"))
                    ),
                    required = listOf("query")
                )
            }

            SEARCH_ALL_TWEETS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "query" to stringProp("Search query"),
                        "max_results" to integerProp("Max results. 10-500.", min = 10, max = 500),
                        "sort_order" to stringProp("Result order", enumValues = listOf("recency", "relevancy"))
                    ),
                    required = listOf("query")
                )
            }

            GET_RECENT_TWEET_COUNTS, GET_ALL_TWEET_COUNTS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "query" to stringProp("Search query"),
                        "granularity" to stringProp("Time granularity", enumValues = listOf("minute", "hour", "day"))
                    ),
                    required = listOf("query")
                )
            }

            // MARK: - Users
            GET_USER_BY_ID -> jsonSchema {
                objectType(
                    properties = mapOf("id" to stringProp("The user ID")),
                    required = listOf("id")
                )
            }

            GET_USER_BY_USERNAME -> jsonSchema {
                objectType(
                    properties = mapOf("username" to stringProp("The username without @")),
                    required = listOf("username")
                )
            }

            GET_USERS_BY_ID -> jsonSchema {
                objectType(
                    properties = mapOf("ids" to arrayProp("User IDs", stringProp())),
                    required = listOf("ids")
                )
            }

            GET_USERS_BY_USERNAME -> jsonSchema {
                objectType(
                    properties = mapOf("usernames" to arrayProp("Usernames without @", stringProp())),
                    required = listOf("usernames")
                )
            }

            GET_AUTHENTICATED_USER -> jsonSchema { emptyObject() }

            GET_USER_FOLLOWING, GET_USER_FOLLOWERS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The user ID"),
                        "max_results" to integerProp("Maximum results", min = 1, max = 1000),
                        "pagination_token" to stringProp("Pagination token")
                    ),
                    required = listOf("id")
                )
            }

            FOLLOW_USER, UNFOLLOW_USER -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The authenticated user's ID"),
                        "target_user_id" to stringProp("The user ID to follow/unfollow")
                    ),
                    required = listOf("id", "target_user_id")
                )
            }

            GET_MUTED_USERS, GET_BLOCKED_USERS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The user ID"),
                        "max_results" to integerProp("Maximum results", min = 1, max = 1000)
                    ),
                    required = listOf("id")
                )
            }

            MUTE_USER, UNMUTE_USER -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The authenticated user's ID"),
                        "target_user_id" to stringProp("The user ID to mute/unmute")
                    ),
                    required = listOf("id", "target_user_id")
                )
            }

            BLOCK_USER_DMS, UNBLOCK_USER_DMS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "target_user_id" to stringProp("The user ID to block/unblock DMs from.")
                    ),
                    required = listOf("target_user_id")
                )
            }

            // MARK: - Likes
            GET_LIKING_USERS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The tweet ID"),
                        "max_results" to integerProp("Maximum results", min = 1, max = 100),
                        "pagination_token" to stringProp("Pagination token")
                    ),
                    required = listOf("id")
                )
            }

            LIKE_TWEET, UNLIKE_TWEET -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The authenticated user's ID"),
                        "tweet_id" to stringProp("The tweet ID to like/unlike")
                    ),
                    required = listOf("id", "tweet_id")
                )
            }

            GET_USER_LIKED_TWEETS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The user ID"),
                        "max_results" to integerProp("Maximum results", min = 5, max = 100)
                    ),
                    required = listOf("id")
                )
            }

            // MARK: - Retweets
            GET_RETWEETED_BY, GET_RETWEETS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The tweet ID"),
                        "max_results" to integerProp("Maximum results", min = 1, max = 100)
                    ),
                    required = listOf("id")
                )
            }

            RETWEET -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The authenticated user's ID"),
                        "tweet_id" to stringProp("The tweet ID to retweet")
                    ),
                    required = listOf("id", "tweet_id")
                )
            }

            UNRETWEET -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The authenticated user's ID"),
                        "source_tweet_id" to stringProp("The original tweet ID to unretweet.")
                    ),
                    required = listOf("id", "source_tweet_id")
                )
            }

            GET_REPOSTS_OF_ME -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "max_results" to integerProp("Maximum results", min = 1, max = 100)
                    )
                )
            }

            // MARK: - Lists
            CREATE_LIST -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "name" to stringProp("List name"),
                        "description" to stringProp("List description"),
                        "private" to booleanProp("Whether the list is private")
                    ),
                    required = listOf("name")
                )
            }

            DELETE_LIST, GET_LIST -> jsonSchema {
                objectType(
                    properties = mapOf("id" to stringProp("The list ID")),
                    required = listOf("id")
                )
            }

            UPDATE_LIST -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The list ID"),
                        "name" to stringProp("List name"),
                        "description" to stringProp("List description"),
                        "private" to booleanProp("Whether the list is private")
                    ),
                    required = listOf("id")
                )
            }

            GET_LIST_MEMBERS, GET_LIST_TWEETS, GET_LIST_FOLLOWERS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The list ID"),
                        "max_results" to integerProp("Maximum results", min = 1, max = 100)
                    ),
                    required = listOf("id")
                )
            }

            ADD_LIST_MEMBER, REMOVE_LIST_MEMBER -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The list ID"),
                        "user_id" to stringProp("The user ID to add/remove")
                    ),
                    required = listOf("id", "user_id")
                )
            }

            PIN_LIST, UNPIN_LIST, FOLLOW_LIST, UNFOLLOW_LIST -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The authenticated user's ID"),
                        "list_id" to stringProp("The list ID")
                    ),
                    required = listOf("id", "list_id")
                )
            }

            GET_PINNED_LISTS -> jsonSchema {
                objectType(
                    properties = mapOf("id" to stringProp("The ID of the authenticated user")),
                    required = listOf("id")
                )
            }

            GET_OWNED_LISTS, GET_FOLLOWED_LISTS, GET_LIST_MEMBERSHIPS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The user ID"),
                        "max_results" to integerProp("Maximum results", min = 1, max = 100)
                    ),
                    required = listOf("id")
                )
            }

            // MARK: - Direct Messages
            CREATE_DM_CONVERSATION -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "conversation_type" to stringProp("Conversation type", enumValues = listOf("Group")),
                        "participant_ids" to arrayProp("User IDs for the conversation", stringProp()),
                        "message" to objectProp(
                            properties = mapOf(
                                "text" to stringProp("Message text"),
                                "attachments" to arrayProp("Attachments", objectProp(
                                    properties = mapOf("media_id" to stringProp("Media ID"))
                                ))
                            ),
                            required = listOf("text")
                        )
                    ),
                    required = listOf("conversation_type", "message", "participant_ids")
                )
            }

            SEND_DM_TO_CONVERSATION -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "dm_conversation_id" to stringProp("DM conversation ID"),
                        "text" to stringProp("Message text, must not be empty"),
                        "attachments" to arrayProp("Media attachments", objectProp(
                            properties = mapOf("media_id" to stringProp("Media ID"))
                        ))
                    ),
                    required = listOf("dm_conversation_id", "text")
                )
            }

            SEND_DM_TO_PARTICIPANT -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "participant_id" to stringProp("User ID to send message to"),
                        "text" to stringProp("Message text, must not be empty"),
                        "attachments" to arrayProp("Media attachments", objectProp(
                            properties = mapOf("media_id" to stringProp("Media ID"))
                        ))
                    ),
                    required = listOf("participant_id", "text")
                )
            }

            GET_DM_EVENTS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "max_results" to integerProp("Maximum results", min = 1, max = 100),
                        "event_types" to stringProp("Comma-separated event types")
                    )
                )
            }

            GET_CONVERSATION_DMS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("Conversation ID"),
                        "max_results" to integerProp("Maximum results", min = 1, max = 100),
                        "event_types" to stringProp("Comma-separated event types")
                    ),
                    required = listOf("id")
                )
            }

            DELETE_DM_EVENT -> jsonSchema {
                objectType(
                    properties = mapOf("dm_event_id" to stringProp("Event ID of the DM to delete")),
                    required = listOf("dm_event_id")
                )
            }

            GET_DM_EVENT_DETAILS -> jsonSchema {
                objectType(
                    properties = mapOf("id" to stringProp("DM event ID")),
                    required = listOf("id")
                )
            }

            // MARK: - Bookmarks
            ADD_BOOKMARK, REMOVE_BOOKMARK -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The authenticated user's ID"),
                        "tweet_id" to stringProp("The tweet ID")
                    ),
                    required = listOf("id", "tweet_id")
                )
            }

            GET_USER_BOOKMARKS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The user ID"),
                        "max_results" to integerProp("Maximum results", min = 1, max = 100)
                    ),
                    required = listOf("id")
                )
            }

            // MARK: - Trends
            GET_PERSONALIZED_TRENDS -> jsonSchema { emptyObject() }

            // MARK: - Community Notes
            CREATE_NOTE -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "tweet_id" to stringProp("The tweet ID to add a note to"),
                        "text" to stringProp("Note text content")
                    ),
                    required = listOf("tweet_id", "text")
                )
            }

            DELETE_NOTE -> jsonSchema {
                objectType(
                    properties = mapOf("id" to stringProp("The note ID to delete")),
                    required = listOf("id")
                )
            }

            EVALUATE_NOTE -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "id" to stringProp("The note ID to evaluate"),
                        "helpful" to booleanProp("Whether the note is helpful")
                    ),
                    required = listOf("id", "helpful")
                )
            }

            GET_NOTES_WRITTEN, GET_POSTS_ELIGIBLE_FOR_NOTES -> jsonSchema {
                objectType(
                    properties = mapOf("max_results" to integerProp("Maximum results", min = 1, max = 100))
                )
            }

            // MARK: - Media
            UPLOAD_MEDIA -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "media" to stringProp("Base64 encoded media data"),
                        "media_category" to stringProp(
                            "Media category",
                            enumValues = listOf("tweet_image", "tweet_video", "tweet_gif", "dm_image", "dm_video", "dm_gif")
                        ),
                        "additional_owners" to arrayProp("Additional user IDs who can use the media", stringProp())
                    ),
                    required = listOf("media")
                )
            }

            GET_MEDIA_STATUS -> jsonSchema {
                objectType(
                    properties = mapOf("media_id" to stringProp("The media ID")),
                    required = listOf("media_id")
                )
            }

            INITIALIZE_CHUNKED_UPLOAD -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "total_bytes" to integerProp("Total bytes of media file"),
                        "media_type" to stringProp("MIME type (e.g., image/jpeg, video/mp4)"),
                        "media_category" to stringProp(
                            "Media category",
                            enumValues = listOf("tweet_image", "tweet_video", "tweet_gif", "dm_image", "dm_video", "dm_gif")
                        )
                    ),
                    required = listOf("total_bytes", "media_type")
                )
            }

            APPEND_CHUNKED_UPLOAD -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "media_id" to stringProp("The media ID from initialization"),
                        "segment_index" to integerProp("Index of the chunk segment"),
                        "media" to stringProp("Base64 encoded chunk data")
                    ),
                    required = listOf("media_id", "segment_index", "media")
                )
            }

            FINALIZE_CHUNKED_UPLOAD -> jsonSchema {
                objectType(
                    properties = mapOf("media_id" to stringProp("The media ID to finalize")),
                    required = listOf("media_id")
                )
            }

            CREATE_MEDIA_METADATA -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "media_id" to stringProp("The media ID"),
                        "alt_text" to stringProp("Alternative text for accessibility")
                    ),
                    required = listOf("media_id")
                )
            }

            GET_MEDIA_ANALYTICS -> jsonSchema {
                objectType(
                    properties = mapOf("media_key" to stringProp("The media key")),
                    required = listOf("media_key")
                )
            }

            // MARK: - News
            GET_NEWS_BY_ID -> jsonSchema {
                objectType(
                    properties = mapOf("id" to stringProp("The ID of the news story")),
                    required = listOf("id")
                )
            }

            SEARCH_NEWS -> jsonSchema {
                objectType(
                    properties = mapOf(
                        "query" to stringProp("The search query"),
                        "max_results" to integerProp("Number of results", min = 1, max = 100),
                        "max_age_hours" to integerProp("Maximum age in hours", min = 1, max = 720)
                    ),
                    required = listOf("query")
                )
            }

            // MARK: - Voice Confirmation
            CONFIRM_ACTION -> jsonSchema {
                objectType(
                    properties = mapOf("tool_call_id" to stringProp("The ID of the tool call being confirmed")),
                    required = listOf("tool_call_id")
                )
            }

            CANCEL_ACTION -> jsonSchema {
                objectType(
                    properties = mapOf("tool_call_id" to stringProp("The ID of the tool call being cancelled")),
                    required = listOf("tool_call_id")
                )
            }
        }
    }

    companion object {
        fun fromName(name: String): XTool? = entries.find { it.toolName == name }

        /**
         * Returns all supported tools (excluding searchAllTweets due to API tier limitations)
         */
        val supportedTools: List<XTool>
            get() = entries.filter { it != SEARCH_ALL_TWEETS }
    }
}

// MARK: - JSON Schema Builder DSL

private class JsonSchemaBuilder {
    fun stringProp(
        description: String? = null,
        enumValues: List<String>? = null
    ): JSONObject = JSONObject().apply {
        put("type", "string")
        description?.let { put("description", it) }
        enumValues?.let { put("enum", JSONArray(it)) }
    }

    fun integerProp(
        description: String? = null,
        min: Int? = null,
        max: Int? = null
    ): JSONObject = JSONObject().apply {
        put("type", "integer")
        description?.let { put("description", it) }
        min?.let { put("minimum", it) }
        max?.let { put("maximum", it) }
    }

    fun booleanProp(description: String? = null): JSONObject = JSONObject().apply {
        put("type", "boolean")
        description?.let { put("description", it) }
    }

    fun arrayProp(description: String? = null, items: JSONObject): JSONObject = JSONObject().apply {
        put("type", "array")
        description?.let { put("description", it) }
        put("items", items)
    }

    fun objectProp(
        properties: Map<String, JSONObject>,
        required: List<String>? = null
    ): JSONObject = JSONObject().apply {
        put("type", "object")
        put("properties", JSONObject().apply {
            properties.forEach { (key, value) -> put(key, value) }
        })
        required?.let { put("required", JSONArray(it)) }
    }

    fun objectType(
        properties: Map<String, JSONObject>,
        required: List<String>? = null
    ): JSONObject = objectProp(properties, required)

    fun emptyObject(): JSONObject = JSONObject().apply {
        put("type", "object")
        put("properties", JSONObject())
    }
}

private fun jsonSchema(block: JsonSchemaBuilder.() -> JSONObject): JSONObject {
    return JsonSchemaBuilder().block()
}
