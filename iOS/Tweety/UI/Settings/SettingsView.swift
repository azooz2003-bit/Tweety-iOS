//
//  SettingsView.swift
//  Tweety
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: StoreViewModel

    let storeManager: StoreKitManager
    let usageTracker: UsageTracker
    let authViewModel: AuthViewModel
    let onLogout: () async -> Void

    init(authViewModel: AuthViewModel, storeManager: StoreKitManager, creditsService: RemoteCreditsService, usageTracker: UsageTracker, onLogout: @escaping () async -> Void) {
        self.authViewModel = authViewModel
        self.storeManager = storeManager
        self.usageTracker = usageTracker
        self.onLogout = onLogout
        self._viewModel = State(initialValue: StoreViewModel(storeManager: storeManager, creditsService: creditsService, authService: authViewModel.authService))
    }

    var body: some View {
        NavigationStack {
            List {
                // Balance Header
                Section {
                    BalanceHeaderView(balance: viewModel.creditBalance)
                }

                // Subscriptions
                if !viewModel.subscriptionProducts.isEmpty {
                    Section("Subscriptions") {
                        ForEach(viewModel.subscriptionProducts.sorted(by: { $0.price < $1.price })) { product in
                            PurchaseProductRow(
                                product: product,
                                isActive: viewModel.activeSubscriptions.contains(where: { $0.id == product.id }),
                                onPurchase: {
                                    await viewModel.purchase(product)
                                }
                            )
                        }
                    }
                }

                // One-Time Purchases
                if !viewModel.oneTimeProducts.isEmpty {
                    Section("One-Time Purchases") {
                        ForEach(viewModel.oneTimeProducts) { product in
                            PurchaseProductRow(
                                product: product,
                                isActive: false,
                                onPurchase: {
                                    await viewModel.purchase(product)
                                }
                            )
                        }
                    }
                }

                // Account Actions
                Section("Account") {
                    Button {
                        Task {
                            await viewModel.restorePurchases()
                        }
                    } label: {
                        HStack {
                            Text("Restore Purchases")
                            Spacer()
                            if viewModel.isPurchasing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isPurchasing)

                    #if DEBUG
                    NavigationLink("Usage Dashboard") {
                        UsageDashboardView(tracker: usageTracker)
                    }

                    Button {
                        Task {
                            await authViewModel.testRefreshToken()
                        }
                    } label: {
                        Label("Test Refresh Token", systemImage: "arrow.clockwise")
                    }
                    #endif
                }

                // Logout
                Section {
                    Button {
                        Task {
                            await onLogout()
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .overlay {
                if viewModel.isPurchasing {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView()
                            .controlSize(.large)
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .task {
                await storeManager.restoreAllTransactions()

                await viewModel.loadProductsAndBalance()
            }
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
