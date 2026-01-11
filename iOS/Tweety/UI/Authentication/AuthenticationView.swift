//
//  AuthenticationView.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/5/26.
//

import SwiftUI

struct AuthenticationView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            Spacer()
                .frame(height: 60)
            ZStack {
                ForEach(0..<16) {
                    Circle()
                        .frame(width: CGFloat(20*$0))
                        .opacity(1 - (Double($0)/15.0))
                }

                Image(.plainTweety)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
            }

            TypingTextView(textToType: "Hey, it's\nTweety!\nShall we?", indicesToPauseAt: [3, 18])
                .foregroundStyle(Color(.label))
                .font(.system(size: 60, weight: .medium, design: .serif))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            loginButton
        }
        .safeAreaPadding(.bottom, 40)
    }

    var loginButton: some View {
        Button {
            Task {
                do {
                    try await authViewModel.login()
                } catch AuthError.loginCancelled {
                    // User cancelled - no error needed
                } catch let error as AuthError {
                    errorMessage = error.localizedDescription
                    showError = true
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } label: {
            HStack {
                Text("Login with")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Image(.colorReversedX)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: 20)
            }
            .foregroundStyle(Color(.background))
            .frame(maxWidth: .infinity, maxHeight: 50)
            .background(Color(.label))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 22)
        }
    }
}

#Preview {
    @Previewable @State var authViewModel = {
        let appAttestService = AppAttestService()
        return AuthViewModel(appAttestService: appAttestService)
    }()

    AuthenticationView(authViewModel: authViewModel)
}
