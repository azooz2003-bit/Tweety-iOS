//
//  MicPermissionState.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/14/25.
//

import Foundation

enum MicPermissionState {
    case checking
    case granted
    case denied

    var isGranted: Bool {
        if case .granted = self { return true }
        return false
    }

    var statusMessage: String {
        switch self {
        case .checking: return "Checking..."
        case .granted: return "Granted"
        case .denied: return "Denied"
        }
    }
}
