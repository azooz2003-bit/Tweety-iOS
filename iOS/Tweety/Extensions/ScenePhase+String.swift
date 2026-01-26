//
//  ScenePhase+String.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import SwiftUI

extension ScenePhase {
    var stringValue: String {
        switch self {
        case .background: return "background"
        case .active: return "active"
        case .inactive: return "inactive"
        @unknown default: return "unknown"
        }
    }
}
