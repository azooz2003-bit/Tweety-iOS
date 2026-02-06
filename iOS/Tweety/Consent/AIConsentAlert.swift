//
//  AIConsentAlert.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 2/5/26.
//

import SwiftUI

struct AIConsentAlert: ViewModifier {
    @Binding var isPresented: Bool
    let consentManager: AIConsentManager

    func body(content: Content) -> some View {
        content
            .alert("AI Data Sharing Consent", isPresented: $isPresented) {
                Button("I Agree") {
                    consentManager.giveConsent()
                }
                .keyboardShortcut(.defaultAction)
                Button("View Privacy Policy") {
                    if let url = URL(string: "https://tweetyvoice.app/privacypolicy/") {
                        UIApplication.shared.open(url)
                    }
                    isPresented = true
                }
                Button("Decline", role: .cancel) {}
            } message: {
                Text("Tweety will share the following data with OpenAI and xAI: \(AIConsentManager.sharedDataTypes). This data is transmitted to third-party AI services to power voice interactions.")
            }
    }
}

extension View {
    func aiConsentAlert(isPresented: Binding<Bool>, consentManager: AIConsentManager) -> some View {
        modifier(AIConsentAlert(isPresented: isPresented, consentManager: consentManager))
    }
}
