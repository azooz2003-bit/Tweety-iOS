//
//  CreditModels.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/28/25.
//

import Foundation

nonisolated
struct CreditBalance: Codable {
    let userId: String
    let spent: Double
    let total: Double
    let remaining: Double

    enum CodingKeys: String, CodingKey {
        case userId
        case spent
        case total
        case remaining
    }
}

nonisolated
struct FreeAccessResponse: Decodable {
    let success: Bool
    let userId: String
    let hasFreeAccess: Bool
}

nonisolated
struct TransactionSyncRequest: Codable {
    let transactionId: String
    let originalTransactionId: String
    let productId: String
    let purchaseDateMs: String
    let isTrialPeriod: String
    let expirationDateMs: String?
    let revocationDateMs: String?
    let revocationReason: String?
    let ownershipType: String?

    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case originalTransactionId = "original_transaction_id"
        case productId = "product_id"
        case purchaseDateMs = "purchase_date_ms"
        case isTrialPeriod = "is_trial_period"
        case expirationDateMs = "expiration_date_ms"
        case revocationDateMs = "revocation_date_ms"
        case revocationReason = "revocation_reason"
        case ownershipType = "ownership_type"
    }
}

nonisolated
struct TransactionSyncResponse: Codable {
    let success: Bool
    let userId: String
    let processedCount: Int
    let skippedCount: Int
    let newCreditsAdded: Double
    let spent: Double
    let total: Double
    let remaining: Double

    enum CodingKeys: String, CodingKey {
        case success
        case userId
        case processedCount
        case skippedCount
        case newCreditsAdded
        case spent
        case total
        case remaining
    }
}

nonisolated
struct UsageTrackRequestBody: Codable {
    let service: String
    let usage: UsageDetails
}

nonisolated
enum UsageDetails: Codable {
    case openAI(OpenAIUsageDetails)
    case grokVoice(GrokVoiceUsageDetails)
    case xAPI(XAPIUsageDetails)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .openAI(let details):
            try container.encode(details)
        case .grokVoice(let details):
            try container.encode(details)
        case .xAPI(let details):
            try container.encode(details)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let openAI = try? container.decode(OpenAIUsageDetails.self) {
            self = .openAI(openAI)
        } else if let grokVoice = try? container.decode(GrokVoiceUsageDetails.self) {
            self = .grokVoice(grokVoice)
        } else if let xAPI = try? container.decode(XAPIUsageDetails.self) {
            self = .xAPI(xAPI)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode UsageDetails"
            )
        }
    }
}

nonisolated
struct OpenAIUsageDetails: Codable {
    let audioInputTokens: Int
    let audioOutputTokens: Int
    let textInputTokens: Int
    let textOutputTokens: Int
    let cachedTextInputTokens: Int
}

nonisolated
struct GrokVoiceUsageDetails: Codable {
    let minutes: Double
}

nonisolated
struct XAPIUsageDetails: Codable {
    let postsRead: Int?
    let usersRead: Int?
    let dmEventsRead: Int?
    let contentCreates: Int?
    let dmInteractionCreates: Int?
    let userInteractionCreates: Int?
}

nonisolated
struct UsageTrackResponse: Codable {
    let success: Bool
    let cost: Double
    let spent: Double
    let total: Double
    let remaining: Double
    let exceeded: Bool
}

nonisolated
enum CreditsServiceError: Error, LocalizedError {
    case invalidResponse
    case serverError(String)
    case networkError(Error)
    case attestationFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .attestationFailed:
            return "Device attestation failed"
        }
    }
}
