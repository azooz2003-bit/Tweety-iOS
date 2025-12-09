//
//  XToolCallResult.swift
//  XTools
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import Foundation

nonisolated
struct XToolCallError: Codable, Error {
    let code: String
    let message: String
    let details: [String: String]?

    init(code: String, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

nonisolated
struct XToolCallResult: Codable {
    let id: String?
    let toolName: String
    let success: Bool
    let response: String?  // JSON string - ready for LLM
    let error: XToolCallError?
    let statusCode: Int?

    init(id: String? = nil, toolName: String, success: Bool, response: String? = nil, error: XToolCallError? = nil, statusCode: Int? = nil) {
        self.id = id
        self.toolName = toolName
        self.success = success
        self.response = response
        self.error = error
        self.statusCode = statusCode
    }

    static func success(id: String? = nil, toolName: String, response: String?, statusCode: Int) -> XToolCallResult {
        XToolCallResult(id: id, toolName: toolName, success: true, response: response, error: nil, statusCode: statusCode)
    }

    static func failure(id: String? = nil, toolName: String, error: XToolCallError, statusCode: Int?) -> XToolCallResult {
        XToolCallResult(id: id, toolName: toolName, success: false, response: nil, error: error, statusCode: statusCode)
    }
}
