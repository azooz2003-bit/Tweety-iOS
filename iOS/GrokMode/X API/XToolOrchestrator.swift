//
//  XToolOrchestrator.swift
//  XTools
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import Foundation
internal import os

nonisolated
enum HTTPMethod: String {
    case get = "GET", post = "POST", delete = "DELETE", put = "PUT"
}

actor XToolOrchestrator {
    private var baseURL: URL { Config.baseXURL }
    private let authService: XAuthService

    init(authService: XAuthService) {
        self.authService = authService
    }

    // MARK: - Authentication

    /// Determines which bearer token to use based on the endpoint requirements
    /// - OAuth 2.0 User Context: For user actions and private data access
    /// - App-only Bearer Token: For public data lookups
    private func getBearerToken(for tool: XTool) async throws -> String? {
        // Use user OAuth token for endpoints that require user context
        guard let userToken = await authService.getValidAccessToken() else {
            throw XToolCallError(
                code: "AUTH_REQUIRED",
                message: "This action requires user authentication. Please log in to your X/Twitter account."
            )
        }
        return userToken
    }

    public func executeTool(_ tool: XTool, parameters: [String: Any], id: String? = nil) async -> XToolCallResult {
        return await executeToolWithRetry(tool, parameters: parameters, id: id, attempt: 1)
    }

    private func executeToolWithRetry(_ tool: XTool, parameters: [String: Any], id: String?, attempt: Int) async -> XToolCallResult {
        do {
            let request = try await buildRequest(for: tool, parameters: parameters)

            #if DEBUG
            AppLogger.tools.debug("TOOL CALL: Executing \(tool.name) (attempt \(attempt))")
            AppLogger.tools.debug("TOOL CALL: URL: \(request.url?.absoluteString ?? "nil")")
            AppLogger.tools.debug("TOOL CALL: Method: \(request.httpMethod ?? "nil")")
            if let body = request.httpBody {
                AppLogger.logSensitive(AppLogger.tools, level: .debug, "TOOL CALL: Body:\n\(AppLogger.prettyJSON(body))")
            }
            #endif

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.network.error("TOOL CALL: Invalid Response")
                return .failure(
                    id: id,
                    toolName: tool.name,
                    error: XToolCallError(code: "INVALID_RESPONSE", message: "Response is not HTTP"),
                    statusCode: nil
                )
            }

            #if DEBUG
            AppLogger.network.debug("TOOL CALL: Status Code: \(httpResponse.statusCode)")
            AppLogger.logSensitive(AppLogger.network, level: .debug, "TOOL CALL: Response:\n\(AppLogger.prettyJSON(data))")
            #endif

            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                let responseString = String(data: data, encoding: .utf8)
                return .success(id: id, toolName: tool.name, response: responseString, statusCode: httpResponse.statusCode)
            } else if httpResponse.statusCode == 401 {
                // 401 = unauthorized (permissions issue or other API error)
                // Note: Token refresh is already handled by getValidAccessToken()
                // If refresh token was expired, user would already be logged out (getValidAccessToken returns nil)
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unauthorized"
                AppLogger.auth.warning("TOOL CALL: 401 Unauthorized - \(errorMessage)")
                return .failure(
                    id: id,
                    toolName: tool.name,
                    error: XToolCallError(
                        code: "UNAUTHORIZED",
                        message: "You don't have permission to perform this action: \(errorMessage)"
                    ),
                    statusCode: httpResponse.statusCode
                )
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                return .failure(
                    id: id,
                    toolName: tool.name,
                    error: XToolCallError(
                        code: "HTTP_\(httpResponse.statusCode)",
                        message: errorMessage
                    ),
                    statusCode: httpResponse.statusCode
                )
            }
        } catch let error as XToolCallError {
            return .failure(
                id: id,
                toolName: tool.name,
                error: error,
                statusCode: nil
            )
        } catch {
            return .failure(
                id: id,
                toolName: tool.name,
                error: XToolCallError(
                    code: "REQUEST_FAILED",
                    message: error.localizedDescription
                ),
                statusCode: nil
            )
        }
    }

    // MARK: - Helper Methods

    private func filterParams(_ params: [String: Any], excluding keys: Set<String>) -> [String: Any] {
        params.filter { !keys.contains($0.key) }
    }

    private func buildQueryItems(from params: [String: Any], excluding keys: Set<String> = []) -> [URLQueryItem] {
        filterParams(params, excluding: keys).map { key, value in
            if let arrayValue = value as? [Any] {
                let stringValue = arrayValue.map { "\($0)" }.joined(separator: ",")
                return URLQueryItem(name: key, value: stringValue)
            } else {
                return URLQueryItem(name: key, value: "\(value)")
            }
        }
    }

    // MARK: - Field Enrichment Helpers

    /// Enriches parameters with essential tweet-related fields
    private func enrichWithTweetFields(_ params: [String: Any]) -> [String: Any] {
        var enriched = params
        enriched["expansions"] = enriched["expansions"] ?? "attachments.poll_ids,attachments.media_keys,author_id,referenced_tweets.id,referenced_tweets.id.author_id,referenced_tweets.id.attachments.media_keys"
        enriched["tweet.fields"] = enriched["tweet.fields"] ?? "text,author_id,created_at,public_metrics,referenced_tweets,entities,conversation_id,in_reply_to_user_id,edit_controls,note_tweet,reply_settings"
        enriched["user.fields"] = enriched["user.fields"] ?? "username,name,verified,verified_type,profile_image_url"
        enriched["media.fields"] = enriched["media.fields"] ?? "url,type,preview_image_url,width,height"
        enriched["poll.fields"] = enriched["poll.fields"] ?? "options,voting_status,end_datetime"
        return enriched
    }

    /// Enriches parameters with essential user-related fields
    private func enrichWithUserFields(_ params: [String: Any]) -> [String: Any] {
        var enriched = params
        enriched["user.fields"] = enriched["user.fields"] ?? "username,name,verified,verified_type,profile_image_url,description,created_at,public_metrics"
        enriched["expansions"] = enriched["expansions"] ?? "pinned_tweet_id"
        enriched["tweet.fields"] = enriched["tweet.fields"] ?? "text,created_at,public_metrics"
        return enriched
    }

    /// Enriches parameters with essential list-related fields
    private func enrichWithListFields(_ params: [String: Any]) -> [String: Any] {
        var enriched = params
        enriched["list.fields"] = enriched["list.fields"] ?? "name,description,owner_id,member_count,follower_count,private"
        enriched["user.fields"] = enriched["user.fields"] ?? "username,name,verified,verified_type,profile_image_url"
        enriched["expansions"] = enriched["expansions"] ?? "owner_id"
        return enriched
    }

    /// Enriches parameters with essential DM-related fields
    private func enrichWithDMFields(_ params: [String: Any]) -> [String: Any] {
        var enriched = params
        enriched["dm_event.fields"] = enriched["dm_event.fields"] ?? "id,text,event_type,created_at,sender_id,participant_ids"
        enriched["user.fields"] = enriched["user.fields"] ?? "username,name,profile_image_url"
        enriched["expansions"] = enriched["expansions"] ?? "sender_id,participant_ids,referenced_tweets.id,attachments.media_keys"
        enriched["media.fields"] = enriched["media.fields"] ?? "url,type,preview_image_url"
        enriched["tweet.fields"] = enriched["tweet.fields"] ?? "text,author_id,created_at"
        return enriched
    }

    /// Enriches parameters with all news-related fields
    private func enrichWithNewsFields(_ params: [String: Any]) -> [String: Any] {
        var enriched = params
        // All news fields
        enriched["news.fields"] = enriched["news.fields"] ?? "category,cluster_posts_results,contexts,disclaimer,hook,id,keywords,name,summary,updated_at"
        return enriched
    }

    internal func buildRequest(for tool: XTool, parameters: [String: Any]) async throws -> URLRequest {
        var path: String
        var method: HTTPMethod
        var queryItems: [URLQueryItem] = []
        var bodyParams: [String: Any] = [:]

        switch tool {
        // MARK: - Posts/Tweets
        case .createTweet:
            path = "/2/tweets"
            method = .post
            bodyParams = parameters

        case .replyToTweet:
            path = "/2/tweets"
            method = .post
            bodyParams = parameters

        case .quoteTweet:
            path = "/2/tweets"
            method = .post
            bodyParams = parameters

        case .createPollTweet:
            path = "/2/tweets"
            method = .post
            bodyParams = parameters

        case .deleteTweet:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)"
            method = .delete

        case .editTweet:
            guard let previousPostId = parameters["previous_post_id"], let text = parameters["text"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters: previous_post_id and text")
            }
            path = "/2/tweets"
            method = .post
            bodyParams = [
                "edit_options": ["previous_post_id": previousPostId],
                "text": text
            ]

        case .getTweet:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .getTweets:
            path = "/2/tweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters))

        case .getUserTweets:
            guard let userId = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(userId)/tweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .getUserMentions:
            guard let userId = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(userId)/mentions"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .getHomeTimeline:
            guard let userId = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(userId)/timelines/reverse_chronological"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .searchRecentTweets:
            path = "/2/tweets/search/recent"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters))

        case .searchAllTweets:
            path = "/2/tweets/search/all"
            method = .get

            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters))

        case .getRecentTweetCounts:
            path = "/2/tweets/counts/recent"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .getAllTweetCounts:
            path = "/2/tweets/counts/all"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        // MARK: - Users
        case .getUserById:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)"
            method = .get

            var enrichedParams = parameters

            // Use provided values or essential defaults via nil coalescing (as comma-separated strings)
            enrichedParams["user.fields"] = enrichedParams["user.fields"] ?? "username,name,verified,verified_type,profile_image_url,description,created_at,public_metrics"

            enrichedParams["expansions"] = enrichedParams["expansions"] ?? "pinned_tweet_id"

            enrichedParams["tweet.fields"] = enrichedParams["tweet.fields"] ?? "text,created_at,public_metrics"

            queryItems = buildQueryItems(from: enrichedParams, excluding: ["id"])

        case .getUserByUsername:
            guard let username = parameters["username"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: username") }
            path = "/2/users/by/username/\(username)"
            method = .get

            var enrichedParams = parameters

            // Use provided values or essential defaults via nil coalescing (as comma-separated strings)
            enrichedParams["user.fields"] = enrichedParams["user.fields"] ?? "username,name,verified,verified_type,profile_image_url,description,created_at,public_metrics"

            enrichedParams["expansions"] = enrichedParams["expansions"] ?? "pinned_tweet_id"

            enrichedParams["tweet.fields"] = enrichedParams["tweet.fields"] ?? "text,created_at,public_metrics"

            queryItems = buildQueryItems(from: enrichedParams, excluding: ["username"])

        case .getUsersById:
            path = "/2/users"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters))

        case .getUsersByUsername:
            path = "/2/users/by"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters))

        case .getAuthenticatedUser:
            path = "/2/users/me"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters))

        case .getUserFollowing:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/following"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .followUser:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/following"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unfollowUser:
            guard let id = parameters["id"], let targetUserId = parameters["target_user_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/following/\(targetUserId)"
            method = .delete

        case .getUserFollowers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/followers"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .getMutedUsers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/muting"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .muteUser:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/muting"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unmuteUser:
            guard let id = parameters["id"], let targetUserId = parameters["target_user_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/muting/\(targetUserId)"
            method = .delete

        case .getBlockedUsers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/blocking"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .blockUserDMs:
            guard let targetUserId = parameters["target_user_id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(targetUserId)/dm/block"
            method = .post

        case .unblockUserDMs:
            guard let targetUserId = parameters["target_user_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(targetUserId)/dm/unblock"
            method = .post

        // MARK: - Likes
        case .getLikingUsers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)/liking_users"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .likeTweet:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/likes"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unlikeTweet:
            guard let id = parameters["id"], let tweetId = parameters["tweet_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/likes/\(tweetId)"
            method = .delete

        case .getUserLikedTweets:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/liked_tweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        // MARK: - Retweets
        case .getRetweetedBy:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)/retweeted_by"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .retweet:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/retweets"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unretweet:
            guard let id = parameters["id"], let sourceTweetId = parameters["source_tweet_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/retweets/\(sourceTweetId)"
            method = .delete

        case .getRetweets:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)/retweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .getRepostsOfMe:
            path = "/2/users/reposts_of_me"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters))

        // MARK: - Lists
        case .createList:
            path = "/2/lists"
            method = .post
            bodyParams = parameters

        case .deleteList:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/lists/\(id)"
            method = .delete

        case .updateList:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/lists/\(id)"
            method = .put
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .getList:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/lists/\(id)"
            method = .get
            queryItems = buildQueryItems(from: enrichWithListFields(parameters), excluding: ["id"])

        case .getListMembers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/members"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .addListMember:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/members"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .removeListMember:
            guard let id = parameters["id"], let userId = parameters["user_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/lists/\(id)/members/\(userId)"
            method = .delete

        case .getListTweets:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/tweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .getListFollowers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/followers"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .pinList:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/pinned_lists"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unpinList:
            guard let id = parameters["id"], let listId = parameters["list_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/pinned_lists/\(listId)"
            method = .delete

        case .getPinnedLists:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/pinned_lists"
            method = .get
            queryItems = buildQueryItems(from: enrichWithListFields(parameters), excluding: ["id"])

        case .getOwnedLists:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/owned_lists"
            method = .get
            queryItems = buildQueryItems(from: enrichWithListFields(parameters), excluding: ["id"])

        case .getFollowedLists:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/followed_lists"
            method = .get
            queryItems = buildQueryItems(from: enrichWithListFields(parameters), excluding: ["id"])

        case .followList:
            guard let id = parameters["id"], let listId = parameters["list_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/followed_lists/\(listId)"
            method = .post

        case .unfollowList:
            guard let id = parameters["id"], let listId = parameters["list_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/followed_lists/\(listId)"
            method = .delete

        case .getListMemberships:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/list_memberships"
            method = .get
            queryItems = buildQueryItems(from: enrichWithListFields(parameters), excluding: ["id"])

        // MARK: - Direct Messages
        case .createDMConversation:
            path = "/2/dm_conversations"
            method = .post
            bodyParams = parameters

        case .sendDMToConversation:
            guard let dmConversationId = parameters["dm_conversation_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: dm_conversation_id")
            }
            path = "/2/dm_conversations/\(dmConversationId)/messages"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["dm_conversation_id"])

        case .sendDMToParticipant:
            guard let participantId = parameters["participant_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: participant_id")
            }
            path = "/2/dm_conversations/with/\(participantId)/messages"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["participant_id"])

        case .getDMEvents:
            path = "/2/dm_events"
            method = .get
            queryItems = buildQueryItems(from: enrichWithDMFields(parameters))

        case .getConversationDMs:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/dm_conversations/\(id)/dm_events"
            method = .get
            queryItems = buildQueryItems(from: enrichWithDMFields(parameters), excluding: ["id"])

        case .deleteDMEvent:
            guard let dmEventId = parameters["dm_event_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: dm_event_id")
            }
            path = "/2/dm_events/\(dmEventId)"
            method = .delete

        case .getDMEventDetails:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/dm_events/\(id)"
            method = .get
            queryItems = buildQueryItems(from: enrichWithDMFields(parameters), excluding: ["id"])

        // MARK: - Bookmarks
        case .addBookmark:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/bookmarks"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .removeBookmark:
            guard let id = parameters["id"], let tweetId = parameters["tweet_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/bookmarks/\(tweetId)"
            method = .delete

        case .getUserBookmarks:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/bookmarks"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        // MARK: - Trends
        case .getPersonalizedTrends:
            path = "/2/users/personalized_trends"
            method = .get

            // Always include all personalized trend fields
            var enrichedParams = parameters
            enrichedParams["personalized_trend.fields"] = "category,post_count,trend_name,trending_since"
            queryItems = buildQueryItems(from: enrichedParams)

        // MARK: - Community Notes
        case .createNote:
            path = "/2/notes"
            method = .post
            bodyParams = parameters

        case .deleteNote:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/notes/\(id)"
            method = .delete

        case .evaluateNote:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/notes/\(id)/evaluate"
            method = .put
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .getNotesWritten:
            path = "/2/notes/search/notes_written"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .getPostsEligibleForNotes:
            path = "/2/notes/search/posts_eligible_for_notes"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        // MARK: - Media
        case .uploadMedia:
            path = "/2/media/upload"
            method = .post
            bodyParams = parameters

        case .getMediaStatus:
            path = "/2/media/upload"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .initializeChunkedUpload:
            path = "/2/media"
            method = .post
            bodyParams = parameters

        case .appendChunkedUpload:
            path = "/2/media/append"
            method = .post
            bodyParams = parameters

        case .finalizeChunkedUpload:
            path = "/2/media/finalize"
            method = .post
            bodyParams = parameters

        case .createMediaMetadata:
            guard let mediaId = parameters["media_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: media_id")
            }
            path = "/2/media/\(mediaId)/metadata"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["media_id"])

        case .getMediaAnalytics:
            guard let mediaKey = parameters["media_key"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: media_key")
            }
            path = "/2/media/\(mediaKey)"
            method = .get

        // MARK: - News
        case .getNewsById:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/news/\(id)"
            method = .get
            queryItems = buildQueryItems(from: enrichWithNewsFields(parameters), excluding: ["id"])

        case .searchNews:
            path = "/2/news/search"
            method = .get
            queryItems = buildQueryItems(from: enrichWithNewsFields(parameters))

        case .confirmAction, .cancelAction:
            throw XToolCallError.init(code: "999", message: "Not expected to handle confirmation/cancellation of actions in orchestrator.")
        }

        // Build URL
        var urlComponents = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }

        guard let url = urlComponents?.url else {
            throw XToolCallError(code: "INVALID_URL", message: "Failed to construct URL for path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        // Use the appropriate authentication based on endpoint requirements
        if let token = try await getBearerToken(for: tool) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add body if present
        if !bodyParams.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyParams)
        }

        return request
    }
}
