//
//  SessionState.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import SwiftUI
import Foundation
internal import os

// MARK: - Models

struct ToolCallData: Identifiable, Codable {
    let id: String
    let toolName: String
    let parameters: [String: String]
    let timestamp: Date
}

struct XTweet: Codable, Identifiable, Sendable {
    let id: String
    let text: String
    let author_id: String?
    let created_at: String?
    let attachments: Attachments?
    let public_metrics: PublicMetrics?

    struct Attachments: Codable, Sendable {
        let media_keys: [String]?
    }

    struct PublicMetrics: Codable, Sendable {
        let retweet_count: Int?
        let reply_count: Int?
        let like_count: Int?
        let quote_count: Int?
        let impression_count: Int?  // Views
        let bookmark_count: Int?
    }
}

struct XUser: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let username: String
    let profile_image_url: String?
}

struct XMedia: Codable, Identifiable, Sendable {
    let media_key: String
    let type: String  // "photo", "video", "animated_gif"
    let url: String?  // Image URL for photos
    let preview_image_url: String?  // For videos/gifs
    let width: Int?
    let height: Int?

    var id: String { media_key }

    // Get the best URL to display (prefer url for photos, preview for videos)
    nonisolated var displayUrl: String? {
        url ?? preview_image_url
    }
}

enum ToolResponseContent: Codable {
    case tweets([XTweet])
    case users([XUser])
    case success(message: String)
    case failure(message: String)
    case raw(String)
    
    // Helper to decode from common formats
    static func from(jsonString: String, toolName: String) -> ToolResponseContent {
        let decoder = JSONDecoder()
        let data = jsonString.data(using: .utf8) ?? Data()
        
        // Try precise decoding based on tool name
        do {
            switch toolName {
            case "search_recent_tweets", "get_tweets":
                // X API usually wraps lists in "data"
                struct TweetResponse: Codable { let data: [XTweet] }
                let response = try decoder.decode(TweetResponse.self, from: data)
                return .tweets(response.data)
                
            case "create_tweet":
                struct CreateTweetResponse: Codable { let data: XTweet }
                let response = try decoder.decode(CreateTweetResponse.self, from: data)
                return .tweets([response.data])
                
            case "get_user_by_username", "get_user_by_id":
                 struct UserResponse: Codable { let data: XUser }
                 let response = try decoder.decode(UserResponse.self, from: data)
                 return .users([response.data])

            default:
                break
            }
        } catch {
            #if DEBUG
            AppLogger.tools.debug("Failed to decode specific response for \(toolName): \(error.localizedDescription)")
            #endif
        }

        // Fallback or generic success check not needed as we default to raw
        return .raw(jsonString)
    }
}

struct ToolResponseData: Codable {
    let success: Bool
    let content: ToolResponseContent
    let timestamp: Date
}

struct ToolLog: Identifiable, Codable {
    var id: String { call.id }
    let call: ToolCallData
    var response: ToolResponseData?
}

// MARK: - State

@Observable
class SessionState {
    var toolCalls: [ToolLog] = []
    
    func addCall(id: String, toolName: String, parameters: [String: Any]) {
        // Convert [String: Any] to [String: String] for storage, checking types
        var stringParams: [String: String] = [:]
        for (key, value) in parameters {
            stringParams[key] = "\(value)"
        }
        
        let callData = ToolCallData(
            id: id,
            toolName: toolName,
            parameters: stringParams,
            timestamp: Date.now
        )
        
        let log = ToolLog(call: callData, response: nil)
        
        // Append to start or end? Usually end makes sense for logs.
        DispatchQueue.main.async {
            self.toolCalls.append(log)
        }
    }
    
    func updateResponse(id: String, responseString: String, success: Bool) {
        guard let index = toolCalls.firstIndex(where: { $0.id == id }) else { return }
        
        // Determine content type based on tool name
        let toolName = toolCalls[index].call.toolName
        let content: ToolResponseContent
        
        if success {
            content = ToolResponseContent.from(jsonString: responseString, toolName: toolName)
        } else {
            content = .failure(message: responseString)
        }
        
        let responseData = ToolResponseData(
            success: success,
            content: content,
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            self.toolCalls[index].response = responseData
        }
    }
}
