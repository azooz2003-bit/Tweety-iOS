//
//  URLRequest+AppAttest.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/21/25.
//

import Foundation

extension URLRequest {
    mutating func addAppAttestHeaders(isRetry: Bool = false) async throws {
        let appAttestService = AppAttestService.shared

        guard await appAttestService.isSupported else {
            throw AppAttestError.notSupported
        }

        let (keyId, assertion) = try await appAttestService.generateAssertion(for: self)
        self.setValue(keyId, forHTTPHeaderField: "X-Apple-Attest-Key-Id")
        self.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-Apple-Attest-Assertion")
        self.setValue(isRetry ? "true" : "false", forHTTPHeaderField: "X-Apple-Attest-Retry")
    }

    static func handleAttestationExpired() async {
        await AppAttestService.shared.clearAttestation()
    }
}
