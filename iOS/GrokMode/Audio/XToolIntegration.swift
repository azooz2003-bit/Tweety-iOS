//
//  XToolIntegration.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import Foundation
import JSONSchema

struct XToolIntegration {
    
    // Tools allowed for the CEO Demo scenario
    static var tools: [XTool] {
        XTool.supportedTools
    }

    static func getToolDefinitions() -> [VoiceMessage.ToolDefinition] {
        var definitions: [VoiceMessage.ToolDefinition] = []

        // Add all X tools
        for tool in tools {
            if let schema = try? toolJSONSchema(for: tool) {
                definitions.append(VoiceMessage.ToolDefinition(
                    type: "function",
                    name: tool.rawValue,
                    description: tool.description,
                    parameters: schema
                ))
            }
        }
        
        return definitions
    }
    
    // Helper to convert internal JSONSchema to the JSONValue format OpenAI/XAIVoice expects
    private static func toolJSONSchema(for tool: XTool) throws -> VoiceMessage.JSONValue {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(tool.jsonSchema)
        
        // Decode into generic JSONValue
        let decoder = JSONDecoder()
        return try decoder.decode(VoiceMessage.JSONValue.self, from: data)
    }
}
