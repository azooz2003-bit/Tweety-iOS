//
//  UIScreen+Ext.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/25/26.
//

import UIKit

// Source - https://stackoverflow.com/a
// Posted by eastriver lee
// Retrieved 2026-01-25, License - CC BY-SA 4.0

extension UIWindow {
    static var current: UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if window.isKeyWindow { return window }
            }
        }
        return nil
    }
}


extension UIScreen {
    static var current: UIScreen? {
        UIWindow.current?.screen
    }
}
