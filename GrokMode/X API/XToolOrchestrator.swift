//
//  XToolOrchestrator.swift
//  XTools
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import Foundation
import Authentication

nonisolated
enum HTTPMethod: String {
    case get = "GET", post = "POST", delete = "DELETE", put = "PUT"
}

actor XToolOrchestrator {
    private var baseURL: String { Config.baseXURL }
    private let authService: XAuthService

    init(authService: XAuthService) {
        self.authService = authService
    }

    // MARK: - Authentication

    /// Determines which bearer token to use based on the endpoint requirements
    /// - OAuth 2.0 User Context: For user actions and private data access
    /// - App-only Bearer Token: For public data lookups
    private func getBearerToken(for tool: XTool) async throws -> String {
        if requiresUserContext(tool) {
            // Use user OAuth token for endpoints that require user context
            guard let userToken = await authService.getValidAccessToken() else {
                throw XToolCallError(
                    code: "AUTH_REQUIRED",
                    message: "This action requires user authentication. Please log in to your X/Twitter account."
                )
            }
            return userToken
        } else {
            // Use app-only bearer token for public endpoints
            return Config.xApiKey
        }
    }

    /// Determines if a tool requires OAuth 2.0 User Context authentication
    private func requiresUserContext(_ tool: XTool) -> Bool {
        switch tool {
        // MARK: Posts/Tweets - Write Operations
        case .createTweet, .deleteTweet:
            return true

        // MARK: Likes
        case .likeTweet, .unlikeTweet:
            return true

        // MARK: Retweets - Write Operations
        case .retweet, .unretweet:
            return true

        // MARK: Users - Manage Operations
        case .followUser, .unfollowUser,
             .muteUser, .unmuteUser,
             .blockUser, .unblockUser,
             .blockUserDMs, .unblockUserDMs:
            return true

        // MARK: Users - Private Data Lookups
        case .getAuthenticatedUser,
             .getMutedUsers,
             .getBlockedUsers:
            return true

        // MARK: Lists - Write Operations
        case .createList, .deleteList, .updateList,
             .addListMember, .removeListMember,
             .pinList, .unpinList:
            return true

        // MARK: Direct Messages - All Operations (private data)
        case .createDMConversation,
             .sendDMToConversation,
             .sendDMToParticipant,
             .getDMEvents,
             .getConversationDMs,
             .deleteDMEvent,
             .getDMEventDetails:
            return true

        // MARK: Bookmarks - All Operations (private data)
        case .addBookmark, .removeBookmark, .getUserBookmarks:
            return true

        // MARK: Community Notes - Write Operations
        case .createNote, .deleteNote, .evaluateNote:
            return true

        // MARK: Public Read Operations - Use Bearer Token
        // Posts/Tweets Lookups
        case .getTweet, .getTweets,
             .searchRecentTweets, .searchAllTweets,
             .getRecentTweetCounts, .getAllTweetCounts:
            return false

        // Likes/Retweets Lookups
        case .getLikingUsers, .getUserLikedTweets,
             .getRetweetedBy, .getRetweets:
            return false

        // Users - Public Lookups
        case .getUserById, .getUserByUsername,
             .getUsersById, .getUsersByUsername,
             .getUserFollowing, .getUserFollowers:
            return false

        // Lists - Read Operations
        case .getList, .getListMembers,
             .getListTweets, .getListFollowers:
            return false

        // Spaces - All Lookups
        case .getSpace, .getSpaces,
             .getSpacesByCreator, .getSpaceTweets,
             .searchSpaces, .getSpaceBuyers:
            return false

        // Community Notes - Lookups
        case .getNotesWritten, .getPostsEligibleForNotes:
            return false

        // MARK: Streaming - Conservative: use user context
        case .streamFilteredTweets, .manageStreamRules,
             .getStreamRules, .getStreamRuleCounts,
             .streamSample, .streamSample10:
            return true

        // MARK: Compliance - Conservative: use user context
        case .createComplianceJob, .getComplianceJob, .listComplianceJobs:
            return true

        // MARK: Media - Conservative: use user context
        case .uploadMedia, .getMediaStatus,
             .initializeChunkedUpload, .appendChunkedUpload,
             .finalizeChunkedUpload, .createMediaMetadata,
             .getMediaAnalytics:
            return true

        // MARK: Trends - Conservative: use bearer token for public data
        case .getTrendsByWoeid, .getPersonalizedTrends:
            return false

        // MARK: Integrations
        case .createLinearTicket:
            return false // Linear doesn't use X auth
        }
    }

    public func executeTool(_ tool: XTool, parameters: [String: Any], id: String? = nil) async -> XToolCallResult {
        return await executeToolWithRetry(tool, parameters: parameters, id: id, attempt: 1)
    }

    private func executeToolWithRetry(_ tool: XTool, parameters: [String: Any], id: String?, attempt: Int) async -> XToolCallResult {
        do {
            let request = try await buildRequest(for: tool, parameters: parameters)

            print("TOOL CALL: Executing \(tool.name) (attempt \(attempt))")
            print("TOOL CALL: URL: \(request.url?.absoluteString ?? "nil")")
            print("TOOL CALL: Method: \(request.httpMethod ?? "nil")")
            if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                print("TOOL CALL: Body: \(bodyString)")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                 print("TOOL CALL: Invalid Response")
                return .failure(
                    id: id,
                    toolName: tool.name,
                    error: XToolCallError(code: "INVALID_RESPONSE", message: "Response is not HTTP"),
                    statusCode: nil
                )
            }

            print("TOOL CALL: Status Code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("TOOL CALL: Response: \(responseString)")
            }

            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                let responseString = String(data: data, encoding: .utf8)
                return .success(id: id, toolName: tool.name, response: responseString, statusCode: httpResponse.statusCode)
            } else if httpResponse.statusCode == 401 && attempt == 1 && requiresUserContext(tool) {
                // 401 on first attempt - token might have been revoked or invalid
                // Force logout and return clear error
                print("TOOL CALL: 401 Unauthorized - User needs to authenticate")
                await authService.logout()
                return .failure(
                    id: id,
                    toolName: tool.name,
                    error: XToolCallError(
                        code: "AUTH_REQUIRED",
                        message: "Authentication required. Please log in to your X/Twitter account to perform this action."
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

    internal func buildRequest(for tool: XTool, parameters: [String: Any]) async throws -> URLRequest {
        var path: String
        var method: HTTPMethod
        var queryItems: [URLQueryItem] = []
        var bodyParams: [String: Any] = [:]

        switch tool {
        // MARK: - Posts/Tweets
            
        case .createLinearTicket:
             // This tool is handled via LinearAPIService, not the X API orchestrator.
             // Throwing an error here ensures we don't accidentally try to send Linear requests to X.
             throw XToolCallError(code: "INVALID_TOOL_HANDLER", message: "create_linear_ticket should be handled by LinearAPIService")
        case .createTweet:
            path = "/2/tweets"
            method = .post

            var enrichedParams = parameters
            if let _ = enrichedParams["quote_tweet_id"], enrichedParams["reply_settings"] == nil {
                enrichedParams["reply_settings"] = "following"
            }
            bodyParams = enrichedParams

        case .deleteTweet:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)"
            method = .delete

        case .getTweet:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        case .getTweets:
            path = "/2/tweets"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .searchRecentTweets:
            path = "/2/tweets/search/recent"
            method = .get

            // ALWAYS include ALL available fields for complete tweet data
            var enrichedParams = parameters

            // All expansions
            enrichedParams["expansions"] = "attachments.poll_ids,attachments.media_keys,author_id,edit_history_tweet_ids,entities.mentions.username,geo.place_id,in_reply_to_user_id,referenced_tweets.id,referenced_tweets.id.author_id"

            // All tweet fields
            enrichedParams["tweet.fields"] = "attachments,author_id,context_annotations,conversation_id,created_at,edit_controls,entities,geo,id,in_reply_to_user_id,lang,public_metrics,possibly_sensitive,referenced_tweets,reply_settings,source,text,withheld"

            // All user fields
            enrichedParams["user.fields"] = "created_at,description,entities,id,location,name,pinned_tweet_id,profile_image_url,protected,public_metrics,url,username,verified,verified_type,withheld"

            // All media fields
            enrichedParams["media.fields"] = "duration_ms,height,media_key,preview_image_url,type,url,width,public_metrics,alt_text,variants"

            // Poll fields
            enrichedParams["poll.fields"] = "duration_minutes,end_datetime,id,options,voting_status"

            // Place fields
            enrichedParams["place.fields"] = "contained_within,country,country_code,full_name,geo,id,name,place_type"

            queryItems = buildQueryItems(from: enrichedParams)

        case .searchAllTweets:
            path = "/2/tweets/search/all"
            method = .get

            // ALWAYS include ALL available fields for complete tweet data
            var enrichedParams = parameters

            // All expansions
            enrichedParams["expansions"] = "attachments.poll_ids,attachments.media_keys,author_id,edit_history_tweet_ids,entities.mentions.username,geo.place_id,in_reply_to_user_id,referenced_tweets.id,referenced_tweets.id.author_id"

            // All tweet fields
            enrichedParams["tweet.fields"] = "attachments,author_id,context_annotations,conversation_id,created_at,edit_controls,entities,geo,id,in_reply_to_user_id,lang,public_metrics,possibly_sensitive,referenced_tweets,reply_settings,source,text,withheld"

            // All user fields
            enrichedParams["user.fields"] = "created_at,description,entities,id,location,name,pinned_tweet_id,profile_image_url,protected,public_metrics,url,username,verified,verified_type,withheld"

            // All media fields
            enrichedParams["media.fields"] = "duration_ms,height,media_key,preview_image_url,type,url,width,public_metrics,alt_text,variants"

            // Poll fields
            enrichedParams["poll.fields"] = "duration_minutes,end_datetime,id,options,voting_status"

            // Place fields
            enrichedParams["place.fields"] = "contained_within,country,country_code,full_name,geo,id,name,place_type"

            queryItems = buildQueryItems(from: enrichedParams)

        case .getRecentTweetCounts:
            path = "/2/tweets/counts/recent"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .getAllTweetCounts:
            path = "/2/tweets/counts/all"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        // MARK: - Streaming
        case .streamFilteredTweets:
            path = "/2/tweets/search/stream"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .manageStreamRules:
            path = "/2/tweets/search/stream/rules"
            method = .post
            bodyParams = parameters

        case .getStreamRules:
            path = "/2/tweets/search/stream/rules"
            method = .get

        case .getStreamRuleCounts:
            path = "/2/tweets/search/stream/rules/counts"
            method = .get

        case .streamSample:
            path = "/2/tweets/sample/stream"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .streamSample10:
            path = "/2/tweets/sample10/stream"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        // MARK: - Users
        case .getUserById:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        case .getUserByUsername:
            guard let username = parameters["username"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: username") }
            path = "/2/users/by/username/\(username)"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["username"])

        case .getUsersById:
            path = "/2/users"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .getUsersByUsername:
            path = "/2/users/by"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .getAuthenticatedUser:
            path = "/2/users/me"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .getUserFollowing:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/following"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

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
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        case .getMutedUsers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/muting"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

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
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        case .blockUser:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/blocking"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unblockUser:
            guard let id = parameters["id"], let targetUserId = parameters["target_user_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/blocking/\(targetUserId)"
            method = .delete

        case .blockUserDMs:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/users/\(id)/dm_blocklist"
            method = .post
            bodyParams = filterParams(parameters, excluding: ["id"])

        case .unblockUserDMs:
            guard let id = parameters["id"], let targetUserId = parameters["target_user_id"] else {
                throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameters")
            }
            path = "/2/users/\(id)/dm_blocklist/\(targetUserId)"
            method = .delete

        // MARK: - Likes
        case .getLikingUsers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)/liking_users"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

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
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        // MARK: - Retweets
        case .getRetweetedBy:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/tweets/\(id)/retweeted_by"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

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
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

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
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        case .getListMembers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/members"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

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
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        case .getListFollowers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/lists/\(id)/followers"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

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
            queryItems = buildQueryItems(from: parameters)

        case .getConversationDMs:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/dm_conversations/\(id)/dm_events"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

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
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

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
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        // MARK: - Spaces
        case .getSpace:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/spaces/\(id)"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        case .getSpaces:
            path = "/2/spaces"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .getSpacesByCreator:
            path = "/2/spaces/by/creator_ids"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .getSpaceTweets:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/spaces/\(id)/tweets"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        case .searchSpaces:
            path = "/2/spaces/search"
            method = .get
            queryItems = buildQueryItems(from: parameters)

        case .getSpaceBuyers:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/spaces/\(id)/buyers"
            method = .get
            queryItems = buildQueryItems(from: parameters, excluding: ["id"])

        // MARK: - Trends
        case .getTrendsByWoeid:
            guard let woeid = parameters["woeid"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: woeid") }
            path = "/2/trends/by/woeid/\(woeid)"
            method = .get

        case .getPersonalizedTrends:
            path = "/2/trends/personalized"
            method = .get

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

        // MARK: - Compliance
        case .createComplianceJob:
            path = "/2/compliance/jobs"
            method = .post
            bodyParams = parameters

        case .getComplianceJob:
            guard let id = parameters["id"] else { throw XToolCallError(code: "MISSING_PARAM", message: "Missing required parameter: id") }
            path = "/2/compliance/jobs/\(id)"
            method = .get

        case .listComplianceJobs:
            path = "/2/compliance/jobs"
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
        }

        // Build URL
        var urlComponents = URLComponents(string: baseURL + path)
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }

        guard let url = urlComponents?.url else {
            throw XToolCallError(code: "INVALID_URL", message: "Failed to construct URL for path: \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        // Use the appropriate authentication based on endpoint requirements
        let token = try await getBearerToken(for: tool)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add body if present
        if !bodyParams.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyParams)
        }

        return request
    }
}
