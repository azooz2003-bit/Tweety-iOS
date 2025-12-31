//
//  ProductConfiguration.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/28/25.
//

import Foundation

enum ProductConfiguration {
    enum ProductID: String, CaseIterable {
        case plus = "co.azizalbahar.TweetyXVoiceAssistant.plusSub"
        case credits10 = "co.azizalbahar.TweetyXVoiceAssistant.credits.10"

        var creditsAmount: Double {
            switch self {
            case .plus:
                return 8.00
            case .credits10:
                return 10.00
            }
        }

        var isSubscription: Bool {
            switch self {
            case .plus:
                return true
            case .credits10:
                return false
            }
        }
    }

    static let allProductIDs: [String] = ProductID.allCases.map { $0.rawValue }

    static func creditsAmount(for productID: String) -> Double? {
        if let product = ProductID(rawValue: productID) {
            return product.creditsAmount
        }

        // Handle dynamic one-time purchase IDs (com.grokmode.credits.{amount})
        if productID.hasPrefix("com.grokmode.credits."),
           let amountString = productID.components(separatedBy: ".").last,
           let amount = Double(amountString) {
            return amount
        }

        return nil
    }
}
