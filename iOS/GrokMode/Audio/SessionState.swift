//
//  SessionState.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import SwiftUI
import Foundation
internal import os

struct ToolCallData: Identifiable, Codable {
    let id: String
    let toolName: String
    let parameters: [String: String]
    let timestamp: Date
    let itemId: String? // Conversation item ID for linking context
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
            if let tool = XTool(rawValue: toolName) {
                switch tool {
                case .searchRecentTweets, .getTweets:
                    // X API usually wraps lists in "data"
                    let response = try decoder.decode(XTweetResponse.self, from: data)
                    return .tweets(response.data ?? [])

                case .createTweet, .replyToTweet, .quoteTweet, .createPollTweet:
                    let response = try decoder.decode(XSingleTweetResponse.self, from: data)
                    return .tweets([response.data])

                case .getUserByUsername, .getUserById:
                     struct UserResponse: Codable { let data: XUser }
                     let response = try decoder.decode(UserResponse.self, from: data)
                     return .users([response.data])

                default:
                    break
                }
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

@Observable
class SessionState {
    var toolCalls: [ToolLog] = []
    
    func addCall(id: String, toolName: String, parameters: [String: Any], itemId: String? = nil) {
        var stringParams: [String: String] = [:]
        for (key, value) in parameters {
            stringParams[key] = "\(value)"
        }

        let callData = ToolCallData(
            id: id,
            toolName: toolName,
            parameters: stringParams,
            timestamp: Date.now,
            itemId: itemId
        )

        let log = ToolLog(call: callData, response: nil)

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
