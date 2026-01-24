//
//  Config.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/7/25.
//

import Foundation

nonisolated
enum Config {
    static let baseProxyURL = {
        guard let url = Bundle.main.infoDictionary?["BASE_PROXY_URL"] as? String else {
            fatalError()
        }
        return URL(string: url)!
    }()

    static let baseXProxyURL = {
        guard let url = Bundle.main.infoDictionary?["BASE_X_PROXY_URL"] as? String else {
            fatalError()
        }
        return URL(string: url)!
    }()

    static let baseXAIProxyURL = {
        guard let url = Bundle.main.infoDictionary?["BASE_XAI_PROXY_URL"] as? String else {
            fatalError()
        }
        return URL(string: url)!
    }()

    static let baseOpenAIProxyURL = {
        guard let url = Bundle.main.infoDictionary?["BASE_OPENAI_PROXY_URL"] as? String else {
            fatalError()
        }
        return URL(string: url)!
    }()

    static let baseXAIURL = URL(string: "https://api.x.ai/")!
    static let baseOpenAIURL = URL(string: "https://api.openai.com/")!
    static let baseXURL = URL(string: "https://api.x.com/")!

    static let bundleId = {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            fatalError("Bundle identifier not found")
        }
        return bundleId
    }()

    static let teamId = {
        guard let teamId = Bundle.main.infoDictionary?["TEAM_ID"] as? String else {
            fatalError("TEAM_ID not found in Info.plist")
        }
        return teamId
    }()

    static let appId: String = {
        return "\(teamId).\(bundleId)"
    }()

    static let creditsBaseURL = baseProxyURL.appending(path: "credits")
    static let transactionSyncURL = creditsBaseURL.appending(path: "transactions/sync")
    static let usageTrackURL = creditsBaseURL.appending(path: "usage/track")
    static let balanceURL = creditsBaseURL.appending(path: "balance")
    static let freeAccessURL = creditsBaseURL.appending(path: "has-free-access")
}
