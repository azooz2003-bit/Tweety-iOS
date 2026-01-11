//
//  PurchaseProductRow.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/28/25.
//

import SwiftUI
import StoreKit

struct PurchaseProductRow: View {
    let product: Product
    var isActive: Bool = false
    let onPurchase: () async -> Void

    @State private var isPurchasing = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)

                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isActive {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                }
            }

            Spacer()

            Button {
                Task {
                    isPurchasing = true
                    await onPurchase()
                    isPurchasing = false
                }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                } else {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }
            .background(Color.black)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .disabled(isPurchasing || isActive)
        }
    }
}

#Preview {
    let appAttestService = AppAttestService()
    let creditsService = RemoteCreditsService(appAttestService: appAttestService)
    let authViewModel = AuthViewModel(appAttestService: .init())
    SettingsView(
        authViewModel: authViewModel,
        storeManager: StoreKitManager(creditsService: creditsService, authService: authViewModel.authService),
        creditsService: creditsService,
        usageTracker: UsageTracker(creditsService: creditsService),
        onLogout: {}
    )
}
