//
//  AIConsentManager.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 2/5/26.
//

import Foundation

@Observable
class AIConsentManager {
    private enum UserDefaultsKey {
        static let hasGivenConsent = "com.tweety.aiConsent.hasGiven"
        static let consentDate = "com.tweety.aiConsent.date"
        static let consentVersion = "com.tweety.aiConsent.version"
        static let hasShownAlert = "com.tweety.aiConsent.hasShownAlert"
    }

    private static let currentConsentVersion = 1

    private(set) var hasGivenConsent: Bool
    private(set) var consentDate: Date?
    private(set) var hasShownAlert: Bool

    init() {
        let storedVersion = UserDefaults.standard.object(forKey: UserDefaultsKey.consentVersion) as? Int
        let isValidVersion = storedVersion.map { $0 >= Self.currentConsentVersion } ?? false
        self.hasGivenConsent = isValidVersion && UserDefaults.standard.bool(forKey: UserDefaultsKey.hasGivenConsent)
        self.consentDate = UserDefaults.standard.object(forKey: UserDefaultsKey.consentDate) as? Date
        self.hasShownAlert = UserDefaults.standard.bool(forKey: UserDefaultsKey.hasShownAlert)
    }

    func markAlertShown() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasShownAlert)
        hasShownAlert = true
    }

    func giveConsent() {
        let now = Date()
        UserDefaults.standard.set(true, forKey: UserDefaultsKey.hasGivenConsent)
        UserDefaults.standard.set(now, forKey: UserDefaultsKey.consentDate)
        UserDefaults.standard.set(Self.currentConsentVersion, forKey: UserDefaultsKey.consentVersion)
        hasGivenConsent = true
        consentDate = now
    }

    func revokeConsent() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.hasGivenConsent)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.consentDate)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.consentVersion)
        hasGivenConsent = false
        consentDate = nil
    }

    static let sharedDataTypes = "Voice Audio, X Account Information, X Account Data Access, Usage Information"
}
