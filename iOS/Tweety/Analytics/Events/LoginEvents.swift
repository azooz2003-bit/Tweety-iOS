//
//  LoginEvents.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import Foundation

struct LoginScreenShownEvent: AnalyticsEvent {
    static let name = "login_screen_shown"
}

struct LoginButtonPressedEvent: AnalyticsEvent {
    static let name = "login_button_pressed"
}
