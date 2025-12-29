//
//  RemoteCreditsService.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/28/25.
//

import Foundation
internal import os

actor RemoteCreditsService {
    static let shared = RemoteCreditsService()

    private init() {}

    func syncTransactions(_ transactions: [TransactionSyncRequest]) async throws -> TransactionSyncResponse {
        var request = URLRequest(url: Config.transactionSyncURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = ["transactions": transactions]
        request.httpBody = try JSONEncoder().encode(requestBody)

        try await request.addAppAttestHeaders()

        var lastError: Error?
        for attempt in 1...3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CreditsServiceError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    let syncResponse = try JSONDecoder().decode(TransactionSyncResponse.self, from: data)
                    AppLogger.store.info("Transaction sync successful: \(syncResponse.processedCount) processed, \(syncResponse.newCreditsAdded) credits added")
                    return syncResponse
                } else if httpResponse.statusCode == 403 {
                    throw CreditsServiceError.attestationFailed
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw CreditsServiceError.serverError(errorMessage)
                }
            } catch {
                lastError = error
                AppLogger.store.warning("Transaction sync attempt \(attempt) failed: \(error)")

                if attempt < 3 {
                    // Exponential backoff
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                    try await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? CreditsServiceError.networkError(NSError(domain: "RemoteCreditsService", code: -1))
    }

    func trackUsage(userId: String, service: String, usage: UsageDetails) async throws -> UsageTrackResponse {
        var request = URLRequest(url: Config.usageTrackURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = UsageTrackRequest(userId: userId, service: service, usage: usage)
        request.httpBody = try JSONEncoder().encode(requestBody)

        try await request.addAppAttestHeaders()

        // NO retry - fail fast to stop session
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CreditsServiceError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let trackResponse = try JSONDecoder().decode(UsageTrackResponse.self, from: data)
            AppLogger.usage.info("Usage tracked: \(service) cost $\(trackResponse.cost), remaining $\(trackResponse.remaining)")
            return trackResponse
        } else if httpResponse.statusCode == 403 {
            throw CreditsServiceError.attestationFailed
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CreditsServiceError.serverError(errorMessage)
        }
    }

    func getBalance(userId: String) async throws -> CreditBalance {
        var urlComponents = URLComponents(url: Config.balanceURL, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [URLQueryItem(name: "userId", value: userId)]

        guard let url = urlComponents.url else {
            throw CreditsServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        try await request.addAppAttestHeaders()

        var lastError: Error?
        for attempt in 1...2 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw CreditsServiceError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    let balance = try JSONDecoder().decode(CreditBalance.self, from: data)
                    AppLogger.store.info("Balance retrieved: $\(balance.remaining) remaining")
                    return balance
                } else if httpResponse.statusCode == 403 {
                    throw CreditsServiceError.attestationFailed
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw CreditsServiceError.serverError(errorMessage)
                }
            } catch {
                lastError = error
                AppLogger.store.warning("Balance retrieval attempt \(attempt) failed: \(error)")

                if attempt < 2 {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }

        throw lastError ?? CreditsServiceError.networkError(NSError(domain: "RemoteCreditsService", code: -1))
    }
}
