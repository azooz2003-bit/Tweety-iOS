package com.allensu.grokmode.xapi

import android.util.Log
import com.allensu.grokmode.auth.XAuthService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

private const val TAG = "XToolOrchestrator"
private const val BASE_URL = "https://api.x.com"

enum class HttpMethod(val value: String) {
    GET("GET"),
    POST("POST"),
    DELETE("DELETE"),
    PUT("PUT")
}

class XToolOrchestrator(private val authService: XAuthService) {

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    suspend fun executeTool(
        tool: XTool,
        parameters: Map<String, Any>,
        id: String? = null
    ): XToolCallResult = withContext(Dispatchers.IO) {
        try {
            val request = buildRequest(tool, parameters)

            Log.d(TAG, "TOOL CALL: Executing ${tool.toolName}")
            Log.d(TAG, "TOOL CALL: URL: ${request.url}")
            Log.d(TAG, "TOOL CALL: Method: ${request.method}")
            Log.d(TAG, "TOOL CALL: Headers: ${request.headers}")
            request.body?.let { body ->
                val buffer = okio.Buffer()
                body.writeTo(buffer)
                Log.d(TAG, "TOOL CALL: Body: ${buffer.readUtf8()}")
            }

            val response = httpClient.newCall(request).execute()
            val responseBody = response.body?.string() ?: ""

            Log.d(TAG, "TOOL CALL: Status Code: ${response.code}")
            Log.d(TAG, "TOOL CALL: Response: ${responseBody.take(500)}")

            when {
                response.isSuccessful -> {
                    XToolCallResult.success(
                        id = id,
                        toolName = tool.toolName,
                        response = responseBody,
                        statusCode = response.code
                    )
                }
                response.code == 401 -> {
                    Log.w(TAG, "TOOL CALL: 401 Unauthorized - $responseBody")
                    XToolCallResult.failure(
                        id = id,
                        toolName = tool.toolName,
                        error = XToolCallError.unauthorized(responseBody),
                        statusCode = response.code
                    )
                }
                else -> {
                    XToolCallResult.failure(
                        id = id,
                        toolName = tool.toolName,
                        error = XToolCallError.httpError(response.code, responseBody),
                        statusCode = response.code
                    )
                }
            }
        } catch (e: XToolCallError) {
            XToolCallResult.failure(id = id, toolName = tool.toolName, error = e)
        } catch (e: Exception) {
            Log.e(TAG, "TOOL CALL: Request failed", e)
            XToolCallResult.failure(
                id = id,
                toolName = tool.toolName,
                error = XToolCallError.requestFailed(e.message ?: "Unknown error")
            )
        }
    }

    private suspend fun getBearerToken(): String {
        return authService.getValidAccessToken()
            ?: throw XToolCallError.authRequired()
    }

    private suspend fun buildRequest(tool: XTool, parameters: Map<String, Any>): Request {
        var path: String
        var method: HttpMethod
        var queryParams: Map<String, Any> = emptyMap()
        var bodyParams: Map<String, Any> = emptyMap()

        when (tool) {
            // MARK: - Posts/Tweets
            XTool.CREATE_TWEET, XTool.REPLY_TO_TWEET, XTool.QUOTE_TWEET, XTool.CREATE_POLL_TWEET -> {
                path = "/2/tweets"
                method = HttpMethod.POST
                bodyParams = parameters
            }

            XTool.DELETE_TWEET -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/tweets/$id"
                method = HttpMethod.DELETE
            }

            XTool.EDIT_TWEET -> {
                val previousPostId = parameters["previous_post_id"]
                    ?: throw XToolCallError.missingParam("previous_post_id")
                val text = parameters["text"]
                    ?: throw XToolCallError.missingParam("text")
                path = "/2/tweets"
                method = HttpMethod.POST
                bodyParams = mapOf(
                    "edit_options" to mapOf("previous_post_id" to previousPostId),
                    "text" to text
                )
            }

            XTool.GET_TWEET -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/tweets/$id"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_TWEETS -> {
                path = "/2/tweets"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters)
            }

            XTool.GET_USER_TWEETS -> {
                val userId = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$userId/tweets"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_USER_MENTIONS -> {
                val userId = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$userId/mentions"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_HOME_TIMELINE -> {
                val userId = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$userId/timelines/reverse_chronological"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters.filterKeys { it != "id" })
            }

            XTool.SEARCH_RECENT_TWEETS -> {
                path = "/2/tweets/search/recent"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters)
            }

            XTool.SEARCH_ALL_TWEETS -> {
                path = "/2/tweets/search/all"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters)
            }

            XTool.GET_RECENT_TWEET_COUNTS -> {
                path = "/2/tweets/counts/recent"
                method = HttpMethod.GET
                queryParams = parameters
            }

            XTool.GET_ALL_TWEET_COUNTS -> {
                path = "/2/tweets/counts/all"
                method = HttpMethod.GET
                queryParams = parameters
            }

            // MARK: - Users
            XTool.GET_USER_BY_ID -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_USER_BY_USERNAME -> {
                val username = parameters["username"] as? String
                    ?: throw XToolCallError.missingParam("username")
                path = "/2/users/by/username/$username"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters.filterKeys { it != "username" })
            }

            XTool.GET_USERS_BY_ID -> {
                path = "/2/users"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters)
            }

            XTool.GET_USERS_BY_USERNAME -> {
                path = "/2/users/by"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters)
            }

            XTool.GET_AUTHENTICATED_USER -> {
                path = "/2/users/me"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters)
            }

            XTool.GET_USER_FOLLOWING -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/following"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters.filterKeys { it != "id" })
            }

            XTool.FOLLOW_USER -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/following"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "id" }
            }

            XTool.UNFOLLOW_USER -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                val targetUserId = parameters["target_user_id"] as? String
                    ?: throw XToolCallError.missingParam("target_user_id")
                path = "/2/users/$id/following/$targetUserId"
                method = HttpMethod.DELETE
            }

            XTool.GET_USER_FOLLOWERS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/followers"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_MUTED_USERS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/muting"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters.filterKeys { it != "id" })
            }

            XTool.MUTE_USER -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/muting"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "id" }
            }

            XTool.UNMUTE_USER -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                val targetUserId = parameters["target_user_id"] as? String
                    ?: throw XToolCallError.missingParam("target_user_id")
                path = "/2/users/$id/muting/$targetUserId"
                method = HttpMethod.DELETE
            }

            XTool.GET_BLOCKED_USERS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/blocking"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters.filterKeys { it != "id" })
            }

            XTool.BLOCK_USER_DMS -> {
                val targetUserId = parameters["target_user_id"] as? String
                    ?: throw XToolCallError.missingParam("target_user_id")
                path = "/2/users/$targetUserId/dm/block"
                method = HttpMethod.POST
            }

            XTool.UNBLOCK_USER_DMS -> {
                val targetUserId = parameters["target_user_id"] as? String
                    ?: throw XToolCallError.missingParam("target_user_id")
                path = "/2/users/$targetUserId/dm/unblock"
                method = HttpMethod.POST
            }

            // MARK: - Likes
            XTool.GET_LIKING_USERS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/tweets/$id/liking_users"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters.filterKeys { it != "id" })
            }

            XTool.LIKE_TWEET -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/likes"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "id" }
            }

            XTool.UNLIKE_TWEET -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                val tweetId = parameters["tweet_id"] as? String
                    ?: throw XToolCallError.missingParam("tweet_id")
                path = "/2/users/$id/likes/$tweetId"
                method = HttpMethod.DELETE
            }

            XTool.GET_USER_LIKED_TWEETS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/liked_tweets"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters.filterKeys { it != "id" })
            }

            // MARK: - Retweets
            XTool.GET_RETWEETED_BY -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/tweets/$id/retweeted_by"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters.filterKeys { it != "id" })
            }

            XTool.RETWEET -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/retweets"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "id" }
            }

            XTool.UNRETWEET -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                val sourceTweetId = parameters["source_tweet_id"] as? String
                    ?: throw XToolCallError.missingParam("source_tweet_id")
                path = "/2/users/$id/retweets/$sourceTweetId"
                method = HttpMethod.DELETE
            }

            XTool.GET_RETWEETS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/tweets/$id/retweets"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_REPOSTS_OF_ME -> {
                path = "/2/users/reposts_of_me"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters)
            }

            // MARK: - Lists
            XTool.CREATE_LIST -> {
                path = "/2/lists"
                method = HttpMethod.POST
                bodyParams = parameters
            }

            XTool.DELETE_LIST -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/lists/$id"
                method = HttpMethod.DELETE
            }

            XTool.UPDATE_LIST -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/lists/$id"
                method = HttpMethod.PUT
                bodyParams = parameters.filterKeys { it != "id" }
            }

            XTool.GET_LIST -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/lists/$id"
                method = HttpMethod.GET
                queryParams = enrichWithListFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_LIST_MEMBERS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/lists/$id/members"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters.filterKeys { it != "id" })
            }

            XTool.ADD_LIST_MEMBER -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/lists/$id/members"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "id" }
            }

            XTool.REMOVE_LIST_MEMBER -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                val userId = parameters["user_id"] as? String
                    ?: throw XToolCallError.missingParam("user_id")
                path = "/2/lists/$id/members/$userId"
                method = HttpMethod.DELETE
            }

            XTool.GET_LIST_TWEETS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/lists/$id/tweets"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_LIST_FOLLOWERS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/lists/$id/followers"
                method = HttpMethod.GET
                queryParams = enrichWithUserFields(parameters.filterKeys { it != "id" })
            }

            XTool.PIN_LIST -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/pinned_lists"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "id" }
            }

            XTool.UNPIN_LIST -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                val listId = parameters["list_id"] as? String
                    ?: throw XToolCallError.missingParam("list_id")
                path = "/2/users/$id/pinned_lists/$listId"
                method = HttpMethod.DELETE
            }

            XTool.GET_PINNED_LISTS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/pinned_lists"
                method = HttpMethod.GET
                queryParams = enrichWithListFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_OWNED_LISTS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/owned_lists"
                method = HttpMethod.GET
                queryParams = enrichWithListFields(parameters.filterKeys { it != "id" })
            }

            XTool.GET_FOLLOWED_LISTS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/followed_lists"
                method = HttpMethod.GET
                queryParams = enrichWithListFields(parameters.filterKeys { it != "id" })
            }

            XTool.FOLLOW_LIST -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                val listId = parameters["list_id"] as? String
                    ?: throw XToolCallError.missingParam("list_id")
                path = "/2/users/$id/followed_lists/$listId"
                method = HttpMethod.POST
            }

            XTool.UNFOLLOW_LIST -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                val listId = parameters["list_id"] as? String
                    ?: throw XToolCallError.missingParam("list_id")
                path = "/2/users/$id/followed_lists/$listId"
                method = HttpMethod.DELETE
            }

            XTool.GET_LIST_MEMBERSHIPS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/list_memberships"
                method = HttpMethod.GET
                queryParams = enrichWithListFields(parameters.filterKeys { it != "id" })
            }

            // MARK: - Direct Messages
            XTool.CREATE_DM_CONVERSATION -> {
                path = "/2/dm_conversations"
                method = HttpMethod.POST
                bodyParams = parameters
            }

            XTool.SEND_DM_TO_CONVERSATION -> {
                val dmConversationId = parameters["dm_conversation_id"] as? String
                    ?: throw XToolCallError.missingParam("dm_conversation_id")
                path = "/2/dm_conversations/$dmConversationId/messages"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "dm_conversation_id" }
            }

            XTool.SEND_DM_TO_PARTICIPANT -> {
                val participantId = parameters["participant_id"] as? String
                    ?: throw XToolCallError.missingParam("participant_id")
                path = "/2/dm_conversations/with/$participantId/messages"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "participant_id" }
            }

            XTool.GET_DM_EVENTS -> {
                path = "/2/dm_events"
                method = HttpMethod.GET
                queryParams = enrichWithDMFields(parameters)
            }

            XTool.GET_CONVERSATION_DMS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/dm_conversations/$id/dm_events"
                method = HttpMethod.GET
                queryParams = enrichWithDMFields(parameters.filterKeys { it != "id" })
            }

            XTool.DELETE_DM_EVENT -> {
                val dmEventId = parameters["dm_event_id"] as? String
                    ?: throw XToolCallError.missingParam("dm_event_id")
                path = "/2/dm_events/$dmEventId"
                method = HttpMethod.DELETE
            }

            XTool.GET_DM_EVENT_DETAILS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/dm_events/$id"
                method = HttpMethod.GET
                queryParams = enrichWithDMFields(parameters.filterKeys { it != "id" })
            }

            // MARK: - Bookmarks
            XTool.ADD_BOOKMARK -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/bookmarks"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "id" }
            }

            XTool.REMOVE_BOOKMARK -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                val tweetId = parameters["tweet_id"] as? String
                    ?: throw XToolCallError.missingParam("tweet_id")
                path = "/2/users/$id/bookmarks/$tweetId"
                method = HttpMethod.DELETE
            }

            XTool.GET_USER_BOOKMARKS -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/users/$id/bookmarks"
                method = HttpMethod.GET
                queryParams = enrichWithTweetFields(parameters.filterKeys { it != "id" })
            }

            // MARK: - Trends
            XTool.GET_PERSONALIZED_TRENDS -> {
                path = "/2/users/personalized_trends"
                method = HttpMethod.GET
                queryParams = mapOf(
                    "personalized_trend.fields" to "category,post_count,trend_name,trending_since"
                )
            }

            // MARK: - Community Notes
            XTool.CREATE_NOTE -> {
                path = "/2/notes"
                method = HttpMethod.POST
                bodyParams = parameters
            }

            XTool.DELETE_NOTE -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/notes/$id"
                method = HttpMethod.DELETE
            }

            XTool.EVALUATE_NOTE -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/notes/$id/evaluate"
                method = HttpMethod.PUT
                bodyParams = parameters.filterKeys { it != "id" }
            }

            XTool.GET_NOTES_WRITTEN -> {
                path = "/2/notes/search/notes_written"
                method = HttpMethod.GET
                queryParams = parameters
            }

            XTool.GET_POSTS_ELIGIBLE_FOR_NOTES -> {
                path = "/2/notes/search/posts_eligible_for_notes"
                method = HttpMethod.GET
                queryParams = parameters
            }

            // MARK: - Media
            XTool.UPLOAD_MEDIA -> {
                path = "/2/media/upload"
                method = HttpMethod.POST
                bodyParams = parameters
            }

            XTool.GET_MEDIA_STATUS -> {
                path = "/2/media/upload"
                method = HttpMethod.GET
                queryParams = parameters
            }

            XTool.INITIALIZE_CHUNKED_UPLOAD -> {
                path = "/2/media"
                method = HttpMethod.POST
                bodyParams = parameters
            }

            XTool.APPEND_CHUNKED_UPLOAD -> {
                path = "/2/media/append"
                method = HttpMethod.POST
                bodyParams = parameters
            }

            XTool.FINALIZE_CHUNKED_UPLOAD -> {
                path = "/2/media/finalize"
                method = HttpMethod.POST
                bodyParams = parameters
            }

            XTool.CREATE_MEDIA_METADATA -> {
                val mediaId = parameters["media_id"] as? String
                    ?: throw XToolCallError.missingParam("media_id")
                path = "/2/media/$mediaId/metadata"
                method = HttpMethod.POST
                bodyParams = parameters.filterKeys { it != "media_id" }
            }

            XTool.GET_MEDIA_ANALYTICS -> {
                val mediaKey = parameters["media_key"] as? String
                    ?: throw XToolCallError.missingParam("media_key")
                path = "/2/media/$mediaKey"
                method = HttpMethod.GET
            }

            // MARK: - News
            XTool.GET_NEWS_BY_ID -> {
                val id = parameters["id"] as? String
                    ?: throw XToolCallError.missingParam("id")
                path = "/2/news/$id"
                method = HttpMethod.GET
                queryParams = enrichWithNewsFields(parameters.filterKeys { it != "id" })
            }

            XTool.SEARCH_NEWS -> {
                path = "/2/news/search"
                method = HttpMethod.GET
                queryParams = enrichWithNewsFields(parameters)
            }

            // Voice confirmation tools should not reach orchestrator
            XTool.CONFIRM_ACTION, XTool.CANCEL_ACTION -> {
                throw XToolCallError.notSupported(tool.toolName)
            }
        }

        // Build URL with query parameters
        val urlBuilder = StringBuilder(BASE_URL).append(path)
        if (queryParams.isNotEmpty()) {
            urlBuilder.append("?")
            urlBuilder.append(buildQueryString(queryParams))
        }

        val token = getBearerToken()

        val requestBuilder = Request.Builder()
            .url(urlBuilder.toString())
            .addHeader("Authorization", "Bearer $token")
            .addHeader("Content-Type", "application/json")

        when (method) {
            HttpMethod.GET -> requestBuilder.get()
            HttpMethod.POST -> {
                val body = if (bodyParams.isNotEmpty()) {
                    convertToJson(bodyParams).toString()
                } else {
                    "{}"
                }
                requestBuilder.post(body.toRequestBody("application/json".toMediaType()))
            }
            HttpMethod.PUT -> {
                val body = if (bodyParams.isNotEmpty()) {
                    convertToJson(bodyParams).toString()
                } else {
                    "{}"
                }
                requestBuilder.put(body.toRequestBody("application/json".toMediaType()))
            }
            HttpMethod.DELETE -> requestBuilder.delete()
        }

        return requestBuilder.build()
    }

    // MARK: - Field Enrichment Helpers

    private fun enrichWithTweetFields(params: Map<String, Any>): Map<String, Any> {
        val enriched = params.toMutableMap()
        enriched.putIfAbsent("expansions", "attachments.poll_ids,attachments.media_keys,author_id,referenced_tweets.id")
        enriched.putIfAbsent("tweet.fields", "text,author_id,created_at,public_metrics,referenced_tweets,entities,conversation_id,in_reply_to_user_id,edit_controls,note_tweet,reply_settings")
        enriched.putIfAbsent("user.fields", "username,name,verified,verified_type,profile_image_url")
        enriched.putIfAbsent("media.fields", "url,type,preview_image_url,width,height")
        enriched.putIfAbsent("poll.fields", "options,voting_status,end_datetime")
        return enriched
    }

    private fun enrichWithUserFields(params: Map<String, Any>): Map<String, Any> {
        val enriched = params.toMutableMap()
        enriched.putIfAbsent("user.fields", "username,name,verified,verified_type,profile_image_url,description,created_at,public_metrics")
        enriched.putIfAbsent("expansions", "pinned_tweet_id")
        enriched.putIfAbsent("tweet.fields", "text,created_at,public_metrics")
        return enriched
    }

    private fun enrichWithListFields(params: Map<String, Any>): Map<String, Any> {
        val enriched = params.toMutableMap()
        enriched.putIfAbsent("list.fields", "name,description,owner_id,member_count,follower_count,private")
        enriched.putIfAbsent("user.fields", "username,name,verified,verified_type,profile_image_url")
        enriched.putIfAbsent("expansions", "owner_id")
        return enriched
    }

    private fun enrichWithDMFields(params: Map<String, Any>): Map<String, Any> {
        val enriched = params.toMutableMap()
        enriched.putIfAbsent("dm_event.fields", "id,text,event_type,created_at,sender_id,participant_ids")
        enriched.putIfAbsent("user.fields", "username,name,profile_image_url")
        enriched.putIfAbsent("expansions", "sender_id,participant_ids,referenced_tweets.id,attachments.media_keys")
        enriched.putIfAbsent("media.fields", "url,type,preview_image_url")
        enriched.putIfAbsent("tweet.fields", "text,author_id,created_at")
        return enriched
    }

    private fun enrichWithNewsFields(params: Map<String, Any>): Map<String, Any> {
        val enriched = params.toMutableMap()
        enriched.putIfAbsent("news.fields", "category,cluster_posts_results,contexts,disclaimer,hook,id,keywords,name,summary,updated_at")
        return enriched
    }

    // MARK: - Helper Methods

    private fun buildQueryString(params: Map<String, Any>): String {
        return params.map { (key, value) ->
            val stringValue = when (value) {
                is List<*> -> value.joinToString(",") { it.toString() }
                else -> value.toString()
            }
            "${URLEncoder.encode(key, "UTF-8")}=${URLEncoder.encode(stringValue, "UTF-8")}"
        }.joinToString("&")
    }

    private fun convertToJson(params: Map<String, Any>): JSONObject {
        val json = JSONObject()
        for ((key, value) in params) {
            when (value) {
                is Map<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    json.put(key, convertToJson(value as Map<String, Any>))
                }
                is List<*> -> {
                    val array = JSONArray()
                    for (item in value) {
                        when (item) {
                            is Map<*, *> -> {
                                @Suppress("UNCHECKED_CAST")
                                array.put(convertToJson(item as Map<String, Any>))
                            }
                            else -> array.put(item)
                        }
                    }
                    json.put(key, array)
                }
                else -> json.put(key, value)
            }
        }
        return json
    }
}
