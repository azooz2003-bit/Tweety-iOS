//
//  LoginView.swift
//  GrokMode
//
//  Created by GrokMode Agent on 12/7/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject private var authService = XAuthService.shared
    
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
            if authService.isAuthenticated {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .transition(.scale)
                    
                    Text("Welcome back,")
                        .font(.headline)
                    
                    if let handle = authService.currentUserHandle {
                        Text(handle)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Button(action: {
                        authService.logout()
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
                    authService.login()
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
            Text("Powered by XAI & Linear")
                .font(.caption2)
        }
        .padding()
    }
}

#Preview {
    LoginView()
}
