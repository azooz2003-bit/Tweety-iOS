//
//  AccessBlockedReason.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/11/26.
//

import Foundation
import StoreKit

enum AccessBlockedReason: String {
    case noSubscription, insufficientCredits

    var title: String {
        switch self {
        case .noSubscription:
            "No Active Subscription"
        case .insufficientCredits:
            "Insufficient Credits"
        }
    }

    var description: String {
        switch self {
        case .noSubscription:
            "An active subscription is required to use the voice assistant. Subscribe to get started."
        case .insufficientCredits:
            "Your credit balance is insufficient to continue. Purchase more credits to resume your session."
        }
    }

    func actionLabel(for storeManager: StoreKitManager) -> String {
        switch self {
        case .noSubscription:
            if let subscriptionProduct = storeManager.products.first(where: {
                ProductConfiguration.ProductID(rawValue: $0.id)?.isSubscription == true
            }) {
                return "Subscribe for \(subscriptionProduct.displayPrice)"
            }
            return "Subscribe Now"

        case .insufficientCredits:
            if let creditsProduct = storeManager.products.first(where: {
                $0.id == ProductConfiguration.ProductID.credits10.rawValue
            }) {
                return "Purchase Credits for \(creditsProduct.displayPrice)"
            }
            return "Purchase Credits"
        }
    }
}
