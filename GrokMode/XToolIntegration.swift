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
    static let demoTools: [XTool] = [
        .searchRecentTweets,
        .createTweet, // For quoting/replying
        .getUserByUsername
    ]
    
    static func getToolDefinitions() -> [VoiceMessage.ToolDefinition] {
        var definitions: [VoiceMessage.ToolDefinition] = []
        
        // Add real X tools
        for tool in demoTools {
            if let schema = try? toolJSONSchema(for: tool) {
                definitions.append(VoiceMessage.ToolDefinition(
                    type: "function",
                    name: tool.rawValue,
                    description: tool.description,
                    parameters: schema
                ))
            }
        }
        
        // Add Mock Linear Tool
        let linearSchema = """
        {
          "type": "object",
          "properties": {
            "title": {
              "type": "string",
              "description": "Title of the ticket"
            },
            "description": {
              "type": "string",
              "description": "Description of the bug or issue"
            },
            "priority": {
              "type": "string",
              "enum": ["high", "medium", "low"]
            }
          },
          "required": ["title", "description"]
        }
        """
        
        definitions.append(VoiceMessage.ToolDefinition(
            type: "function",
            name: "create_linear_ticket",
            description: "Create a new ticket in Linear for engineering to track a bug or task.",
            parameters: linearSchema
        ))
        
        return definitions
    }
    
    // Helper to convert internal JSONSchema to the string format OpenAI/XAIVoice expects
    private static func toolJSONSchema(for tool: XTool) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(tool.jsonSchema)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
