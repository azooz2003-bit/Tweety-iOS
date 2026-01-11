//
//  XAIVoiceError.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/14/25.
//

import Foundation

enum XAIVoiceError: Error, Equatable{
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case connectionTimeout
    case notConnected
    case invalidToken

    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .connectionTimeout:
            return "WebSocket connection timed out"
        case .notConnected:
            return "WebSocket is not connected"
        case .invalidToken:
            return "Invalid or expired token"
        }
    }
}
