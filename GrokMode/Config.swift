//
//  Config.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import Foundation

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
    
    static let linearApiKey = {
        guard let apiKey = Bundle.main.infoDictionary?["LINEAR_API_KEY"] as? String else {
            fatalError()
        }
        return apiKey
    }()
    static let baseXURL = "https://api.x.com"
}
