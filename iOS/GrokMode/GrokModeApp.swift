//
//  GrokModeApp.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/6/25.
//

import SwiftUI

@main
struct GrokModeApp: App {
    @State var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(authViewModel: authViewModel)
        }
    }
}
