//
//  LoginView.swift
//  GrokMode
//
//  Created by Matt Steele on 12/7/25.
//

import SwiftUI

struct LoginView: View {
    @Bindable var authViewModel: AuthViewModel
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Logo / Branding
            VStack(spacing: 15) {
                Image(systemName: "waveform.circle.fill") // Placeholder logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.primary)

                Text("GrokMode")
                    .font(.system(size: 40, weight: .bold, design: .rounded))

                Text("Voice Agent for X")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)

            // Auth State
            if authViewModel.isAuthenticated {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .transition(.scale)

                    Text("Welcome back,")
                        .font(.headline)

                    if let handle = authViewModel.currentUserHandle {
                        Text(handle)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    Button(action: {
                        Task {
                            await authViewModel.logout()
                        }
                    }) {
                        Text("Sign Out")
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(20)
                    }
                }
            } else {
                // Login Button
                Button(action: {
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
                }) {
                    HStack {
                        Image(systemName: "xmark.square.fill") // Placeholder for X logo, usually usage of trademarked logos requires care
                            .font(.title2)
                        Text("Sign in with X")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()

            // Footer
            Text("Powered by XAI")
                .font(.caption2)
        }
        .padding()
        .alert("Login Failed", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}

#Preview {
    @Previewable @State var authViewModel = AuthViewModel()

    LoginView(authViewModel: authViewModel)
}
