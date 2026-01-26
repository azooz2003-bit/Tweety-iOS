//
//  VoiceSessionEvents.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import Foundation

struct VoiceAssistantScreenShownEvent: AnalyticsEvent {
    static let name = "voice_assistant_screen_shown"
}

struct VoiceSessionStartButtonPressedEvent: AnalyticsEvent {
    static let name = "voice_session_start_button_pressed"
}

struct VoiceSessionBeganEvent: AnalyticsEvent {
    static let name = "voice_session_began"
    let sessionLaunchTimeMs: Int

    enum CodingKeys: String, CodingKey {
        case sessionLaunchTimeMs = "session_launch_time_ms"
    }
}

struct VoiceSessionStopButtonPressedEvent: AnalyticsEvent {
    static let name = "voice_session_stop_button_pressed"
}

struct VoiceSessionStoppedAbruptlyEvent: AnalyticsEvent {
    static let name = "voice_session_stopped_abruptly"
    let reason: String
}

struct SessionRejectedEvent: AnalyticsEvent {
    static let name = "session_rejected"
    let reason: String
}

struct VoiceModelEvent: AnalyticsEvent {
    static let name = "voice_model_event"
    let eventType: String

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
    }
}

struct UserSessionEvent: AnalyticsEvent {
    static let name = "user_session_event"
    let eventType: String

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
    }
}
