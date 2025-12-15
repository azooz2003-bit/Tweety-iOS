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
        XTool.supportedTools
    }

    static func getToolDefinitions() -> [ConversationEvent.ToolDefinition] {
        tools.map { tool in
            ConversationEvent.ToolDefinition(
                type: "function",
                name: tool.rawValue,
                description: tool.description,
                parameters: tool.jsonSchema
            )
        }
    }
}
