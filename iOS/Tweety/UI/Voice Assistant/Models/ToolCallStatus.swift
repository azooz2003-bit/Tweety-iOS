//
//  ToolCallStatus.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/14/25.
//

import Foundation

enum ToolCallStatus {
    case pending
    case approved
    case rejected
    case executed(success: Bool)
}
