//
//  AccessBlockedView.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/11/26.
//

import SwiftUI
import StoreKit

struct AccessBlockedView: View {
    let reason: AccessBlockedReason
    let storeManager: StoreKitManager
    let onPurchase: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(reason.title)
                    .font(.title2.weight(.semibold))
            } icon: {
                Image("SadTweety")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            }
        } description: {
            Text(reason.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } actions: {
            Button(action: onPurchase) {
                Text(reason.actionLabel(for: storeManager))
                    .font(.headline)
                    .foregroundStyle(Color(.systemBackground))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.label))
            .controlSize(.large)
        }
        .padding()
    }
}

#Preview {
    let appAttestService = AppAttestService()
    let creditsService = RemoteCreditsService(appAttestService: appAttestService)
    let authViewModel = AuthViewModel(appAttestService: .init())
    let storeManager = StoreKitManager(creditsService: creditsService, authService: authViewModel.authService)

    AccessBlockedView(
        reason: .insufficientCredits,
        storeManager: storeManager,
        onPurchase: {}
    )
}
