//
//  Shaking+Ext.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/1/26.
//

import Foundation
import UIKit

// Source - https://stackoverflow.com/a
// Posted by markiv
// Retrieved 2026-01-01, License - CC BY-SA 4.0

extension Notification.Name {
    public static let deviceDidShakeNotification = Notification.Name("MyDeviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        NotificationCenter.default.post(name: .deviceDidShakeNotification, object: event)
    }
}

