//
//  TweetyAccountService.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/24/26.
//

import Foundation
internal import os

actor TweetyAccountService {
    enum AccountServiceError: Error, LocalizedError {
        case invalidResponse
        case serverError(String)
        case attestationFailed

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let message):
                return "Server error: \(message)"
            case .attestationFailed:
                return "Device attestation failed"
            }
        }
    }

    private let appAttestService: AppAttestService

    init(appAttestService: AppAttestService) {
        self.appAttestService = appAttestService
    }

    func deleteAccount(userId: String) async throws {
        var request = URLRequest(url: Config.accountDeletionURL)
        request.httpMethod = "DELETE"
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")

        try await request.addAppAttestHeaders(appAttestService: appAttestService)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AccountServiceError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            AppLogger.store.info("Account deleted successfully for user \(userId)")
        } else if httpResponse.statusCode == 403 {
            throw AccountServiceError.attestationFailed
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AccountServiceError.serverError(errorMessage)
        }
    }
}
