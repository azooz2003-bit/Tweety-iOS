//
//  ConversationItemType.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/14/25.
//

import Foundation

enum ConversationItemType {
    case userSpeech(transcript: String)
    case assistantSpeech(text: String)
    case tweet(EnrichedTweet)
    case tweets([EnrichedTweet])
    case toolCall(name: String, status: ToolCallStatus)
    case systemMessage(String)
}
