//
//  XToolIntegration.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import Foundation
import JSONSchema

struct XToolIntegration {
    
    static var tools: [XTool] {
        var all = XTool.allCases
        all.removeAll(where: { $0 == .searchAllTweets})
        return all
    }

    static func getToolDefinitions() -> [VoiceToolDefinition] {
        tools.map { tool in
            // Convert JSONSchema to dictionary for VoiceToolDefinition
            let parametersDict: [String: Any]
            do {
                let encoder = JSONEncoder()
                let data = try encoder.encode(tool.jsonSchema)
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    parametersDict = dict
                } else {
                    // Fallback to valid minimal schema
                    parametersDict = ["type": "object", "properties": [:]]
                }
            } catch {
                // Fallback to valid minimal schema
                parametersDict = ["type": "object", "properties": [:]]
            }

            return VoiceToolDefinition(
                type: "function",
                name: tool.rawValue,
                description: tool.description,
                parameters: parametersDict
            )
        }
    }
}
