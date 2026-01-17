//
//  XPaginationMeta.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/24/25.
//

import Foundation

/// Pagination metadata returned by X API v2 endpoints
struct XPaginationMeta: Codable, Sendable {
    let next_token: String?
    let previous_token: String?
    let result_count: Int?

    /// Check if more results are available
    var hasMore: Bool {
        next_token != nil
    }

    /// Format pagination info for display to the agent
    func formatForAgent(toolName: String) -> String? {
        guard let nextToken = next_token else { return nil }

        let countInfo = result_count.map { "Showing \($0) results. " } ?? ""
        return "\(countInfo)More results available - call \(toolName) again with pagination_token='\(nextToken)' to see the next page."
    }
}
