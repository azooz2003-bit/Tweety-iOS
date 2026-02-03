//
//  AuthPresentationProvider.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 2/2/26.
//

@preconcurrency import AuthenticationServices

final class AuthPresentationProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
