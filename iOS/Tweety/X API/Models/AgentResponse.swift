//
//  AgentResponse.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/25/25.
//

import Foundation

/// Generic wrapper for API responses with agent-specific guidance
/// Keeps the original API payload pure while adding contextual information for the AI agent
struct AgentResponse<Payload: Codable>: Codable, Sendable where Payload: Sendable {
    /// The unmodified API response
    let payload: Payload

    /// Message to the agent about this response (summary, guidance, warnings)
    let response_message: String?

    /// Pagination guidance when more results are available
    let pagination_info: String?

    /// Initialize with just the payload (no enrichment)
    init(payload: Payload) {
        self.payload = payload
        self.response_message = nil
        self.pagination_info = nil
    }

    /// Initialize with payload and optional enrichments
    init(payload: Payload, responseMessage: String? = nil, paginationInfo: String? = nil) {
        self.payload = payload
        self.response_message = responseMessage
        self.pagination_info = paginationInfo
    }
}
