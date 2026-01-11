//
//  AppAttestService.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/21/25.
//

import Foundation
import DeviceCheck
import CryptoKit
import OSLog

enum AppAttestError: Error {
    case notSupported
    case notAttested
    case verificationFailed
    case invalidResponse
}

actor AppAttestService {
    private let service = DCAppAttestService.shared
    private let keychain = KeychainHelper.shared

    var isSupported: Bool {
        service.isSupported
    }

    init() {}

    func getOrCreateAttestedKey() async throws -> String {
        if let existingKeyId = keychain.getString(for: KeychainKeys.appAttestKeyId) {
            return existingKeyId
        }
        return try await attestNewKey()
    }

    private func attestNewKey() async throws -> String {
        guard service.isSupported else {
            AppLogger.auth.error("App Attest not supported on this device")
            throw AppAttestError.notSupported
        }

        let keyId = try await service.generateKey()
        let challenge = try await fetchChallenge()
        let clientDataHash = Data(SHA256.hash(data: challenge))
        let attestation = try await service.attestKey(keyId, clientDataHash: clientDataHash)

        try await verifyAttestation(keyId: keyId, attestation: attestation, challenge: challenge)
        try keychain.save(keyId, for: KeychainKeys.appAttestKeyId)

        return keyId
    }

    func generateAssertion(for request: URLRequest, isRetry: Bool = false) async throws -> (keyId: String, assertion: Data) {
        guard let keyId = keychain.getString(for: KeychainKeys.appAttestKeyId) else {
            let _ = try await attestNewKey()
            return try await generateAssertion(for: request, isRetry: true)
        }

        let clientDataHash = try createClientDataHash(from: request)

        do {
            let assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
            return (keyId, assertion)
        } catch {
            AppLogger.auth.error("Assertion generation failed: \(error.localizedDescription)")
            if !isRetry {
                await clearAttestation()
                return try await generateAssertion(for: request, isRetry: true)
            }
            throw error
        }
    }

    func clearAttestation() async {
        keychain.delete(KeychainKeys.appAttestKeyId)
    }

    #if DEBUG
    static func clearAttestationForDebug() async {
        let service = AppAttestService()
        await service.clearAttestation()
    }
    #endif

    // MARK: - Helpers

    private func fetchChallenge() async throws -> Data {
        let url = Config.baseProxyURL.appending(path: "attest/challenge")
        let (data, response) = try await URLSession.shared.data(from: url)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppAttestError.invalidResponse
        }

        return data
    }

    private func verifyAttestation(keyId: String, attestation: Data, challenge: Data) async throws {
        let url = Config.baseProxyURL.appending(path: "attest/verify")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "keyId": keyId,
            "attestation": attestation.base64EncodedString(),
            "challenge": challenge.base64EncodedString()
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppAttestError.verificationFailed
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            AppLogger.auth.error("Attestation verification failed: \(errorMessage)")
            throw AppAttestError.verificationFailed
        }
    }

    private func createClientDataHash(from request: URLRequest) throws -> Data {
        var data = Data()

        if let url = request.url {
            if let path = url.path.data(using: .utf8) {
                data.append(path)
            }
            if let query = url.query?.data(using: .utf8) {
                data.append(query)
            }
        }

        if let method = request.httpMethod?.data(using: .utf8) {
            data.append(method)
        }

        if let body = request.httpBody {
            data.append(body)
        }

        let hash = Data(SHA256.hash(data: data))
        return hash
    }
}
