//
//  TransactionExtensions.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/29/25.
//

import Foundation
import StoreKit
internal import os

extension Date {
    /// Convert Date to milliseconds since epoch as String
    var millisecondsSince1970String: String {
        String(Int(timeIntervalSince1970 * 1000))
    }
}

extension Transaction {
    /// Convert StoreKit Transaction to TransactionSyncRequest
    /// User ID is sent via X-User-Id header instead of in the request body
    func toSyncRequest() -> TransactionSyncRequest {
        TransactionSyncRequest(
            transactionId: String(id),
            originalTransactionId: String(originalID),
            productId: productID,
            purchaseDateMs: purchaseDate.millisecondsSince1970String,
            isTrialPeriod: offer?.type == .introductory ? "true" : "false",
            expirationDateMs: expirationDate?.millisecondsSince1970String,
            revocationDateMs: revocationDate?.millisecondsSince1970String,
            revocationReason: revocationReason.map { "\($0)" },
            ownershipType: String(describing: ownershipType)
        )
    }
}
