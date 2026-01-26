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

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
    }
}

struct SubscribeButtonPressedFromSettingsEvent: AnalyticsEvent {
    static let name = "subscribe_button_pressed_from_settings"
}

struct SubscribeSucceededFromSettingsEvent: AnalyticsEvent {
    static let name = "subscribe_succeeded_from_settings"
    let productId: String
    let price: Double

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
    }
}

struct CreditsPurchaseButtonPressedFromChatErrorEvent: AnalyticsEvent {
    static let name = "credits_purchase_button_pressed_from_chat_error"
}

struct CreditsPurchaseSucceededFromChatErrorEvent: AnalyticsEvent {
    static let name = "credits_purchase_succeeded_from_chat_error"
    let productId: String
    let price: Double
    let creditsAmount: Double

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
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
    let creditsAmount: Double

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case price
        case creditsAmount = "credits_amount"
    }
}
