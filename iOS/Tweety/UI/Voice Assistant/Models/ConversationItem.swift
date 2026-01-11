//
//  ConversationItem.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/14/25.
//

import Foundation

struct ConversationItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: ConversationItemType
}
