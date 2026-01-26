//
//  UIEvents.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import Foundation

struct BatchTweetsViewOpenedEvent: AnalyticsEvent {
    static let name = "batch_tweets_view_opened"
}

struct ToolConfirmationButtonPressedEvent: AnalyticsEvent {
    static let name = "tool_confirmation_button_pressed"
    let action: String
    let toolName: String

    enum CodingKeys: String, CodingKey {
        case action
        case toolName = "tool_name"
    }
}

struct AppLifecycleChangedEvent: AnalyticsEvent {
    static let name = "app_lifecycle_changed"
    let stage: String
}
