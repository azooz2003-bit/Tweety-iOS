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
    private let storeManager: StoreKitManager
    private let usageTracker: UsageTracker

    init(authService: XAuthService, storeManager: StoreKitManager, usageTracker: UsageTracker) {
        self.authService = authService
        self.storeManager = storeManager
        self.usageTracker = usageTracker
    }

    // MARK: - Authentication

    /// Determines which bearer token to use based on the endpoint requirements
    /// - OAuth 2.0 User Context: For user actions and private data access
    /// - App-only Bearer Token: For public data lookups
    private func getBearerToken(for tool: XTool) async throws -> String? {
        guard let userToken = await authService.getValidAccessToken() else {
            throw XToolCallError(
                code: .authRequired,
                message: "This action requires user authentication. Please log in to your X/Twitter account."
            )
        }
        return userToken
    }

    public func executeTool(_ tool: XTool, parameters: [String: Any], id: String? = nil) async -> XToolCallResult {
        return await executeToolWithRetry(tool, parameters: parameters, id: id, attempt: 1)
    }

    private func executeToolWithRetry(_ tool: XTool, parameters: [String: Any], id: String?, attempt: Int) async -> XToolCallResult {
        // Log if this is a pagination request
        if let paginationToken = parameters["pagination_token"] as? String {
            AppLogger.tools.info("PAGINATION: Agent calling \(tool.name) with pagination_token")
            AppLogger.tools.info("PAGINATION: Pagination token = \(paginationToken)")
            AppLogger.tools.info("PAGINATION: All parameters = \(parameters)")
        }

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
                    error: XToolCallError(code: .invalidResponse, message: "Response is not HTTP"),
                    statusCode: nil
                )
            }

            #if DEBUG
            AppLogger.network.debug("TOOL CALL: Status Code: \(httpResponse.statusCode)")
            AppLogger.logSensitive(AppLogger.network, level: .debug, "TOOL CALL: Response:\n\(AppLogger.prettyJSON(data))")
            #endif

            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                let responseString = String(data: data, encoding: .utf8)
                let enrichedResponse = enrichResponseWithPagination(responseString, toolName: tool.name, originalParameters: parameters)

                do {
                    try await trackXAPIUsage(for: tool, responseData: data)
                } catch {
                    AppLogger.usage.error("X API usage tracking failed: \(error)")
                    let trackingError = XToolCallError(
                        code: .usageTrackingFailed,
                        message: "Usage tracking failed: \(error.localizedDescription)"
                    )
                    return .failure(id: id, toolName: tool.name, error: trackingError, statusCode: nil)
                }

                return .success(id: id, toolName: tool.name, response: enrichedResponse, statusCode: httpResponse.statusCode)
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
                        code: .unauthorized,
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
                        code: .httpError,
                        message: errorMessage,
                        details: ["status_code": "\(httpResponse.statusCode)"]
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
                    code: .requestFailed,
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
    private func enrichWithTweetFields(_ params: [String: Any], limitResults: Bool = false) -> [String: Any] {
        var enriched = params
        enriched["expansions"] = enriched["expansions"] ?? "attachments.poll_ids,attachments.media_keys,author_id,referenced_tweets.id,referenced_tweets.id.author_id,referenced_tweets.id.attachments.media_keys"
        enriched["tweet.fields"] = enriched["tweet.fields"] ?? "text,author_id,created_at,public_metrics,referenced_tweets,entities,conversation_id,in_reply_to_user_id,edit_controls,note_tweet,reply_settings"
        enriched["user.fields"] = enriched["user.fields"] ?? "username,name,verified,verified_type,profile_image_url"
        enriched["media.fields"] = enriched["media.fields"] ?? "url,type,preview_image_url,width,height"
        enriched["poll.fields"] = enriched["poll.fields"] ?? "options,voting_status,end_datetime"

        // Force max_results to 10 for paginated endpoints to keep voice agent context healthy
        if limitResults {
            let currentMax = enriched["max_results"] as? Int ?? 10
            enriched["max_results"] = min(currentMax, 10)
        }

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
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)"
            method = .delete

        case .editTweet:
            guard let previousPostId = parameters["previous_post_id"], let text = parameters["text"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters: previous_post_id and text")
            }
            path = "/2/tweets"
            method = .post
            bodyParams = [
                "edit_options": ["previous_post_id": previousPostId],
                "text": text
            ]

        case .getTweet:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .getTweets:
            path = "/2/tweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters))

        case .getUserTweets:
            guard let userId = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(userId)/tweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters, limitResults: true), excluding: ["id"])

        case .getUserMentions:
            guard let userId = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(userId)/mentions"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters, limitResults: true), excluding: ["id"])

        case .getHomeTimeline:
            guard let userId = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(userId)/timelines/reverse_chronological"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters, limitResults: true), excluding: ["id"])

        case .searchRecentTweets:
            path = "/2/tweets/search/recent"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters, limitResults: true))

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
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)"
            method = .get

            var enrichedParams = parameters

            // Use provided values or essential defaults via nil coalescing (as comma-separated strings)
            enrichedParams["user.fields"] = enrichedParams["user.fields"] ?? "username,name,verified,verified_type,profile_image_url,description,created_at,public_metrics"

            enrichedParams["expansions"] = enrichedParams["expansions"] ?? "pinned_tweet_id"

            enrichedParams["tweet.fields"] = enrichedParams["tweet.fields"] ?? "text,created_at,public_metrics"

            queryItems = buildQueryItems(from: enrichedParams, excluding: ["id"])

        case .getUserByUsername:
            guard let username = parameters["username"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: username") }
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
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/following"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .followUser:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/following"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unfollowUser:
            guard let id = parameters["id"], let targetUserId = parameters["target_user_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/users/\(id)/following/\(targetUserId)"
            method = .delete

        case .getUserFollowers:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/followers"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .getMutedUsers:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/muting"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .muteUser:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/muting"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unmuteUser:
            guard let id = parameters["id"], let targetUserId = parameters["target_user_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/users/\(id)/muting/\(targetUserId)"
            method = .delete

        case .getBlockedUsers:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/blocking"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .blockUserDMs:
            guard let targetUserId = parameters["target_user_id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(targetUserId)/dm/block"
            method = .post

        case .unblockUserDMs:
            guard let targetUserId = parameters["target_user_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/users/\(targetUserId)/dm/unblock"
            method = .post

        // MARK: - Likes
        case .getLikingUsers:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)/liking_users"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .likeTweet:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/likes"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unlikeTweet:
            guard let id = parameters["id"], let tweetId = parameters["tweet_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/users/\(id)/likes/\(tweetId)"
            method = .delete

        case .getUserLikedTweets:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/liked_tweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters, limitResults: true), excluding: ["id"])

        // MARK: - Retweets
        case .getRetweetedBy:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)/retweeted_by"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .retweet:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/retweets"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unretweet:
            guard let id = parameters["id"], let sourceTweetId = parameters["source_tweet_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/users/\(id)/retweets/\(sourceTweetId)"
            method = .delete

        case .getRetweets:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)/retweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .getRepostsOfMe:
            path = "/2/users/reposts_of_me"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters, limitResults: true))

        // MARK: - Lists
        case .createList:
            path = "/2/lists"
            method = .post
            bodyParams = parameters

        case .deleteList:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/lists/\(id)"
            method = .delete

        case .updateList:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/lists/\(id)"
            method = .put
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .getList:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/lists/\(id)"
            method = .get
            queryItems = buildQueryItems(from: enrichWithListFields(parameters), excluding: ["id"])

        case .getListMembers:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/members"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .addListMember:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/members"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .removeListMember:
            guard let id = parameters["id"], let userId = parameters["user_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/lists/\(id)/members/\(userId)"
            method = .delete

        case .getListTweets:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/tweets"
            method = .get
            queryItems = buildQueryItems(from: enrichWithTweetFields(parameters), excluding: ["id"])

        case .getListFollowers:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/followers"
            method = .get
            queryItems = buildQueryItems(from: enrichWithUserFields(parameters), excluding: ["id"])

        case .pinList:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/pinned_lists"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unpinList:
            guard let id = parameters["id"], let listId = parameters["list_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/users/\(id)/pinned_lists/\(listId)"
            method = .delete

        case .getPinnedLists:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/pinned_lists"
            method = .get
            queryItems = buildQueryItems(from: enrichWithListFields(parameters), excluding: ["id"])

        case .getOwnedLists:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/owned_lists"
            method = .get
            queryItems = buildQueryItems(from: enrichWithListFields(parameters), excluding: ["id"])

        case .getFollowedLists:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/followed_lists"
            method = .get
            queryItems = buildQueryItems(from: enrichWithListFields(parameters), excluding: ["id"])

        case .followList:
            guard let id = parameters["id"], let listId = parameters["list_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/users/\(id)/followed_lists/\(listId)"
            method = .post

        case .unfollowList:
            guard let id = parameters["id"], let listId = parameters["list_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/users/\(id)/followed_lists/\(listId)"
            method = .delete

        case .getListMemberships:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
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
                throw XToolCallError(code: .missingParam, message: "Missing required parameter: dm_conversation_id")
            }
            path = "/2/dm_conversations/\(dmConversationId)/messages"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["dm_conversation_id"])

        case .sendDMToParticipant:
            guard let participantId = parameters["participant_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameter: participant_id")
            }
            path = "/2/dm_conversations/with/\(participantId)/messages"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["participant_id"])

        case .getDMEvents:
            path = "/2/dm_events"
            method = .get
            queryItems = buildQueryItems(from: enrichWithDMFields(parameters))

        case .getConversationDMs:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/dm_conversations/\(id)/dm_events"
            method = .get
            queryItems = buildQueryItems(from: enrichWithDMFields(parameters), excluding: ["id"])

        case .getConversationDMsByParticipant:
            guard let participantId = parameters["participant_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameter: participant_id")
            }
            path = "/2/dm_conversations/with/\(participantId)/dm_events"
            method = .get
            queryItems = buildQueryItems(from: enrichWithDMFields(parameters), excluding: ["participant_id"])

        case .deleteDMEvent:
            guard let dmEventId = parameters["dm_event_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameter: dm_event_id")
            }
            path = "/2/dm_events/\(dmEventId)"
            method = .delete

        case .getDMEventDetails:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/dm_events/\(id)"
            method = .get
            queryItems = buildQueryItems(from: enrichWithDMFields(parameters), excluding: ["id"])

        // MARK: - Bookmarks
        case .addBookmark:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/users/\(id)/bookmarks"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .removeBookmark:
            guard let id = parameters["id"], let tweetId = parameters["tweet_id"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameters")
            }
            path = "/2/users/\(id)/bookmarks/\(tweetId)"
            method = .delete

        case .getUserBookmarks:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
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
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/notes/\(id)"
            method = .delete

        case .evaluateNote:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
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
                throw XToolCallError(code: .missingParam, message: "Missing required parameter: media_id")
            }
            path = "/2/media/\(mediaId)/metadata"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["media_id"])

        case .getMediaAnalytics:
            guard let mediaKey = parameters["media_key"] else {
                throw XToolCallError(code: .missingParam, message: "Missing required parameter: media_key")
            }
            path = "/2/media/\(mediaKey)"
            method = .get

        // MARK: - News
        case .getNewsById:
            guard let id = parameters["id"] else { throw XToolCallError(code: .missingParam, message: "Missing required parameter: id") }
            path = "/2/news/\(id)"
            method = .get
            queryItems = buildQueryItems(from: enrichWithNewsFields(parameters), excluding: ["id"])

        case .searchNews:
            path = "/2/news/search"
            method = .get
            queryItems = buildQueryItems(from: enrichWithNewsFields(parameters))

        case .confirmAction, .cancelAction:
            throw XToolCallError(code: .notImplemented, message: "Not expected to handle confirmation/cancellation of actions in orchestrator.")
        }

        var urlComponents = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }

        guard let url = urlComponents?.url else {
            throw XToolCallError(code: .invalidURL, message: "Failed to construct URL for path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let token = try await getBearerToken(for: tool) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if !bodyParams.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyParams)
        }

        return request
    }

    // MARK: - Response Enrichment

    /// Enriches successful API responses with pagination information for the agent
    private func enrichResponseWithPagination(_ responseString: String?, toolName: String, originalParameters: [String: Any]) -> String? {
        guard let responseString = responseString,
              let data = responseString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meta = json["meta"] as? [String: Any],
              let nextToken = meta["next_token"] as? String else {
            return responseString
        }

        // Log pagination token information
        AppLogger.tools.info("PAGINATION: Found next_token for \(toolName)")
        AppLogger.tools.info("PAGINATION: next_token = \(nextToken)")
        AppLogger.tools.info("PAGINATION: Original parameters (before enrichment) = \(originalParameters)")

        // Create enriched response with pagination guidance
        var enrichedJson = json
        var enrichedMeta = meta

        let resultCount = meta["result_count"] as? Int
        let countInfo = resultCount.map { "\($0) results returned. " } ?? ""

        // Format original parameters for display (excluding enriched fields that are auto-added)
        // But INCLUDE max_results since it's critical for pagination
        let relevantParams = originalParameters.filter { key, _ in
            !key.contains(".fields") && key != "expansions"
        }
        let paramsJSON = (try? JSONSerialization.data(withJSONObject: relevantParams, options: [.prettyPrinted, .sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        AppLogger.tools.info("PAGINATION: Relevant parameters for next call = \(paramsJSON)")

        // Create a unique marker to help agent identify which token goes with which request
        let requestSignature = "REQ_\(toolName)_\(String(describing: originalParameters["id"] ?? ""))_\(Date().timeIntervalSince1970)"

        enrichedMeta["pagination_info"] = """
        \(countInfo)More results are available.

        PAGINATION TOKEN FOR THIS RESPONSE: "\(nextToken)"
        REQUEST SIGNATURE: \(requestSignature)

        WARNING: This token ONLY works for continuing THIS SPECIFIC REQUEST.
        - If you see multiple pagination tokens in the conversation, use the MOST RECENT one from the MOST RECENT response
        - Do NOT reuse tokens from earlier responses
        - Each token is unique and expires after use

        IMPORTANT GUIDELINES:
        1. After reading these results to the user, ask if they would like to see more (e.g., "Would you like me to show you more?" or "Should I fetch additional results?").

        2. ONLY fetch additional pages if the user explicitly requests it (e.g., "show me more", "continue", "next", "keep going", "yes show more").

        3. NEVER automatically fetch multiple pages without user confirmation for each page.

        4. If you have already fetched 3 or more pages in this conversation, warn the user that you're retrieving a lot of data and ask if they want to continue.

        EXCEPTION - Batch Fetching for "ALL" Requests:
        If the user explicitly requests ALL results (e.g., "give me ALL my DMs with Allen", "show me EVERY tweet I liked", "get my COMPLETE timeline"), you may automatically fetch multiple pages WITHOUT asking for confirmation each time, BUT:
        - ONLY for finite, scoped queries (specific conversation DMs, specific user's content, user's own bookmarks, etc.)
        - NEVER for unbounded searches (e.g., "all tweets about AI", general searches, trending topics)
        - Maximum 10 pages total - stop after 10 pages and inform the user
        - Inform the user you're fetching multiple pages (e.g., "I'll fetch all your DMs with Allen, this may take a moment...")
        - After completion, summarize total results retrieved (e.g., "I retrieved 87 messages across 4 pages")

        CRITICAL - How to fetch the next page for THIS response (\(requestSignature)):

        You called \(toolName) with these user-specified parameters:
        \(paramsJSON)

        To fetch the next page, call \(toolName) with:
        1. ALL the same parameters shown above
        2. PLUS max_results: \(originalParameters["max_results"] ?? 10) (CRITICAL: must match the first request)
        3. PLUS pagination_token: "\(nextToken)" (USE THIS EXACT TOKEN, NOT ANY OTHER TOKEN FROM THE CONVERSATION)

        EXACT next call parameters:
        \(paramsJSON.dropLast())
          "max_results": \(originalParameters["max_results"] ?? 10),
          "pagination_token": "\(nextToken)"
        }

        CRITICAL RULES:
        - USE THIS TOKEN: "\(nextToken)" (verify the last 5 characters are: \(String(nextToken.suffix(5))))
        - The pagination token is tied to the EXACT query parameters including max_results
        - If you omit max_results or use a different value, you'll get "pagination_token is not recognized" error
        - You MUST include the EXACT SAME max_results value that was used in the first request
        - DO NOT call \(toolName) with just id and pagination_token - that will fail
        - DO NOT use a different pagination token from elsewhere in the conversation
        """

        enrichedJson["meta"] = enrichedMeta

        if let enrichedData = try? JSONSerialization.data(withJSONObject: enrichedJson, options: [.prettyPrinted]),
           let enrichedString = String(data: enrichedData, encoding: .utf8) {
            return enrichedString
        }

        return responseString
    }

    // MARK: - Usage Tracking

    /// Track X API usage based on tool type and response data with server registration
    @MainActor
    private func trackXAPIUsage(for tool: XTool, responseData: Data) async throws {
        // Parse response to count items
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return
        }

        var operation: XAPIOperation?
        var count = 0

        // Categorize tools and determine operation type
        switch tool {
        // Read operations - Posts
        case .searchRecentTweets, .searchAllTweets, .getTweets, .getTweet,
             .getUserLikedTweets, .getUserTweets, .getUserMentions,
             .getHomeTimeline, .getRepostsOfMe:
            if let data = json["data"] as? [[String: Any]] {
                operation = .postRead
                count = data.count
            } else if json["data"] != nil {
                operation = .postRead
                count = 1
            }

        // Read operations - Users
        case .getUserFollowers, .getUserFollowing, .getUserByUsername, .getUserById:
            if let data = json["data"] as? [[String: Any]] {
                operation = .userRead
                count = data.count
            } else if json["data"] != nil {
                operation = .userRead
                count = 1
            }

        // Read operations - DM Events
        case .getDMEvents, .getConversationDMs, .getDMEventDetails:
            if let data = json["data"] as? [[String: Any]] {
                operation = .dmEventRead
                count = data.count
            }

        // Create operations - Content
        case .createTweet, .replyToTweet, .quoteTweet, .deleteTweet, .createPollTweet, .editTweet:
            operation = .contentCreate
            count = 1

        // Create operations - DM Interactions
        case .sendDMToParticipant, .sendDMToConversation, .createDMConversation, .deleteDMEvent:
            operation = .dmInteractionCreate
            count = 1

        // Create operations - User Interactions
        case .likeTweet, .unlikeTweet, .retweet, .unretweet,
             .followUser, .unfollowUser, .blockUserDMs, .unblockUserDMs,
             .muteUser, .unmuteUser, .addBookmark, .removeBookmark:
            operation = .userInteractionCreate
            count = 1

        // Read operations - Additional User queries
        case .getUsersById, .getUsersByUsername, .getAuthenticatedUser,
             .getMutedUsers, .getBlockedUsers, .getLikingUsers, .getRetweetedBy:
            if let data = json["data"] as? [[String: Any]] {
                operation = .userRead
                count = data.count
            } else if json["data"] != nil {
                operation = .userRead
                count = 1
            }

        // Read operations - Tweet counts and metrics
        case .getRecentTweetCounts, .getAllTweetCounts, .getRetweets:
            if let data = json["data"] as? [[String: Any]] {
                operation = .postRead
                count = data.count
            } else if json["data"] != nil {
                operation = .postRead
                count = 1
            }

        // Read operations - Lists
        case .getList, .getListMembers, .getListTweets, .getListFollowers,
             .getPinnedLists, .getOwnedLists, .getFollowedLists, .getListMemberships:
            if let data = json["data"] as? [[String: Any]] {
                operation = .postRead  // Lists are billed similar to reading posts
                count = data.count
            } else if json["data"] != nil {
                operation = .postRead
                count = 1
            }

        // Create operations - List management
        case .createList, .deleteList, .updateList, .addListMember, .removeListMember,
             .pinList, .unpinList, .followList, .unfollowList:
            operation = .userInteractionCreate
            count = 1

        // Read operations - Bookmarks
        case .getUserBookmarks:
            if let data = json["data"] as? [[String: Any]] {
                operation = .postRead
                count = data.count
            } else if json["data"] != nil {
                operation = .postRead
                count = 1
            }

        // Read operations - Trends
        case .getPersonalizedTrends:
            if let data = json["data"] as? [[String: Any]] {
                operation = .postRead
                count = data.count
            } else if json["data"] != nil {
                operation = .postRead
                count = 1
            }

        // Read operations - DM by participant
        case .getConversationDMsByParticipant:
            if let data = json["data"] as? [[String: Any]] {
                operation = .dmEventRead
                count = data.count
            }

        // Create operations - Community Notes
        case .createNote, .deleteNote, .evaluateNote:
            operation = .contentCreate
            count = 1

        // Read operations - Community Notes
        case .getNotesWritten, .getPostsEligibleForNotes:
            if let data = json["data"] as? [[String: Any]] {
                operation = .postRead
                count = data.count
            } else if json["data"] != nil {
                operation = .postRead
                count = 1
            }

        // Media operations - Track as content creates
        case .uploadMedia, .getMediaStatus, .initializeChunkedUpload,
             .appendChunkedUpload, .finalizeChunkedUpload, .createMediaMetadata,
             .getMediaAnalytics:
            operation = .contentCreate
            count = 1

        // Read operations - News
        case .getNewsById, .searchNews:
            if let data = json["data"] as? [[String: Any]] {
                operation = .postRead
                count = data.count
            } else if json["data"] != nil {
                operation = .postRead
                count = 1
            }

        // Tools without usage tracking (user confirmation/cancellation actions)
        case .confirmAction, .cancelAction:
            return
        }

        // Register usage with server if operation was determined
        if let operation = operation {
            let userId = try await authService.requiredUserId
            let result = await usageTracker.trackAndRegisterXAPIUsage(
                operation: operation,
                count: count,
                userId: userId
            )

            switch result {
            case .success(let balance):
                if balance.remaining <= 0 {
                    AppLogger.usage.error("X API usage depleted credits: remaining \(balance.remaining)")
                    throw XToolCallError(
                        code: .insufficientCredits,
                        message: "Insufficient credits remaining. Balance: $\(balance.remaining.rounded(toPlaces: 2))"
                    )
                }
            case .failure(let error):
                AppLogger.usage.error("X API usage registration failed: \(error)")
                throw error
            }
        }
    }
}
