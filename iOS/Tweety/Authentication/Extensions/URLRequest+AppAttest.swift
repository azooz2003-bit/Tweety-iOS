//
//  URLRequest+AppAttest.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/21/25.
//

import Foundation

extension URLRequest {
    mutating func addAppAttestHeaders(appAttestService: AppAttestService, isRetry: Bool = false) async throws {
        guard await appAttestService.isSupported else {
            throw AppAttestError.notSupported
        }

        let (keyId, assertion) = try await appAttestService.generateAssertion(for: self)
        self.setValue(keyId, forHTTPHeaderField: "X-Apple-Attest-Key-Id")
        self.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "X-Apple-Attest-Assertion")
        self.setValue(isRetry ? "true" : "false", forHTTPHeaderField: "X-Apple-Attest-Retry")
    }

    static func handleAttestationExpired(appAttestService: AppAttestService) async {
        await appAttestService.clearAttestation()
    }
}
