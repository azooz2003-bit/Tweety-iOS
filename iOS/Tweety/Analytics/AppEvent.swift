//
//  AppEvent.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import Foundation

enum AppEvent {
    case loginScreenShown(LoginScreenShownEvent)
    case loginButtonPressed(LoginButtonPressedEvent)

    case voiceAssistantScreenShown(VoiceAssistantScreenShownEvent)
    case voiceSessionStartButtonPressed(VoiceSessionStartButtonPressedEvent)
    case voiceSessionBegan(VoiceSessionBeganEvent)
    case voiceSessionStopButtonPressed(VoiceSessionStopButtonPressedEvent)
    case voiceSessionStoppedAbruptly(VoiceSessionStoppedAbruptlyEvent)
    case sessionRejected(SessionRejectedEvent)
    case voiceModelEvent(VoiceModelEvent)
    case userSessionEvent(UserSessionEvent)

    case subscribeButtonPressedFromChatError(SubscribeButtonPressedFromChatErrorEvent)
    case subscribeSucceededFromChatError(SubscribeSucceededFromChatErrorEvent)
    case subscribeButtonPressedFromSettings(SubscribeButtonPressedFromSettingsEvent)
    case subscribeSucceededFromSettings(SubscribeSucceededFromSettingsEvent)
    case creditsPurchaseButtonPressedFromChatError(CreditsPurchaseButtonPressedFromChatErrorEvent)
    case creditsPurchaseSucceededFromChatError(CreditsPurchaseSucceededFromChatErrorEvent)
    case creditsPurchaseButtonPressedFromSettings(CreditsPurchaseButtonPressedFromSettingsEvent)
    case creditsPurchaseSucceededFromSettings(CreditsPurchaseSucceededFromSettingsEvent)

    case batchTweetsViewOpened(BatchTweetsViewOpenedEvent)
    case toolConfirmationButtonPressed(ToolConfirmationButtonPressedEvent)
    case appLifecycleChanged(AppLifecycleChangedEvent)

    var event: any AnalyticsEvent {
        switch self {
        case .loginScreenShown(let e): return e
        case .loginButtonPressed(let e): return e
        case .voiceAssistantScreenShown(let e): return e
        case .voiceSessionStartButtonPressed(let e): return e
        case .voiceSessionBegan(let e): return e
        case .voiceSessionStopButtonPressed(let e): return e
        case .voiceSessionStoppedAbruptly(let e): return e
        case .sessionRejected(let e): return e
        case .voiceModelEvent(let e): return e
        case .userSessionEvent(let e): return e
        case .subscribeButtonPressedFromChatError(let e): return e
        case .subscribeSucceededFromChatError(let e): return e
        case .subscribeButtonPressedFromSettings(let e): return e
        case .subscribeSucceededFromSettings(let e): return e
        case .creditsPurchaseButtonPressedFromChatError(let e): return e
        case .creditsPurchaseSucceededFromChatError(let e): return e
        case .creditsPurchaseButtonPressedFromSettings(let e): return e
        case .creditsPurchaseSucceededFromSettings(let e): return e
        case .batchTweetsViewOpened(let e): return e
        case .toolConfirmationButtonPressed(let e): return e
        case .appLifecycleChanged(let e): return e
        }
    }
}
