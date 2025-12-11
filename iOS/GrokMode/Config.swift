//
//  Config.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import Foundation

nonisolated
enum Config {
    static let xApiKey = {
        guard let apiKey = Bundle.main.infoDictionary?["X_API_KEY"] as? String else {
            fatalError()
        }
        return apiKey
    }()
    
    static let xAiApiKey = {
        guard let apiKey = Bundle.main.infoDictionary?["X_AI_API_KEY"] as? String else {
            fatalError()
        }
        return apiKey
    }()

    static let baseXProxyURL = {
        guard let apiKey = Bundle.main.infoDictionary?["BASE_X_PROXY_URL"] as? String else {
            fatalError()
        }
        return apiKey
    }()

    static let baseXAIProxyURL = {
        guard let apiKey = Bundle.main.infoDictionary?["BASE_XAI_PROXY_URL"] as? String else {
            fatalError()
        }
        return apiKey
    }()
}
