//
//  PurchaseEvents.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import Foundation

struct SubscribeButtonPressedFromChatErrorEvent: AnalyticsEvent {
    static let name = "subscribe_button_pressed_from_chat_error"
}

struct SubscribeSucceededFromChatErrorEvent: AnalyticsEvent {
    static let name = "subscribe_succeeded_from_chat_error"
    let productId: String
    let price: Double
    let currency: String

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
        case currency
    }
}

struct SubscribeButtonPressedFromSettingsEvent: AnalyticsEvent {
    static let name = "subscribe_button_pressed_from_settings"
}

struct SubscribeSucceededFromSettingsEvent: AnalyticsEvent {
    static let name = "subscribe_succeeded_from_settings"
    let productId: String
    let price: Double
    let currency: String

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
        case currency
    }
}

struct CreditsPurchaseButtonPressedFromChatErrorEvent: AnalyticsEvent {
    static let name = "credits_purchase_button_pressed_from_chat_error"
}

struct CreditsPurchaseSucceededFromChatErrorEvent: AnalyticsEvent {
    static let name = "credits_purchase_succeeded_from_chat_error"
    let productId: String
    let price: Double
    let currency: String
    let creditsAmount: Double

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
        case currency
        case creditsAmount = "credits_amount"
    }
}

struct CreditsPurchaseButtonPressedFromSettingsEvent: AnalyticsEvent {
    static let name = "credits_purchase_button_pressed_from_settings"
}

struct CreditsPurchaseSucceededFromSettingsEvent: AnalyticsEvent {
    static let name = "credits_purchase_succeeded_from_settings"
    let productId: String
    let price: Double
    let currency: String
    let creditsAmount: Double

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
        case currency
        case creditsAmount = "credits_amount"
    }
}

struct SubscribeFailedFromChatErrorEvent: AnalyticsEvent {
    static let name = "subscribe_failed_from_chat_error"
    let productId: String
    let errorReason: String

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case errorReason = "error_reason"
    }
}

struct SubscribeFailedFromSettingsEvent: AnalyticsEvent {
    static let name = "subscribe_failed_from_settings"
    let productId: String
    let errorReason: String

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case errorReason = "error_reason"
    }
}

struct CreditsPurchaseFailedFromChatErrorEvent: AnalyticsEvent {
    static let name = "credits_purchase_failed_from_chat_error"
    let productId: String
    let errorReason: String

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case errorReason = "error_reason"
    }
}

struct CreditsPurchaseFailedFromSettingsEvent: AnalyticsEvent {
    static let name = "credits_purchase_failed_from_settings"
    let productId: String
    let errorReason: String

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case errorReason = "error_reason"
    }
}
