//
//  SettingsView.swift
//  Tweety
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storeVM: StoreViewModel
    @State private var showDeleteAccountAlert = false
    @State private var showSubscriptionSheet = false
    @State private var showConsentAlert = false

    let storeManager: StoreKitManager
    let usageTracker: UsageTracker
    let authViewModel: AuthViewModel
    let consentManager: AIConsentManager
    let onLogout: () async -> Void

    init(authViewModel: AuthViewModel, storeManager: StoreKitManager, creditsService: RemoteCreditsService, usageTracker: UsageTracker, consentManager: AIConsentManager, onLogout: @escaping () async -> Void) {
        self.authViewModel = authViewModel
        self.storeManager = storeManager
        self.usageTracker = usageTracker
        self.consentManager = consentManager
        self.onLogout = onLogout
        self._storeVM = State(initialValue: StoreViewModel(storeManager: storeManager, creditsService: creditsService, authService: authViewModel.authService))
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Balance Header
                Section {
                    BalanceHeaderView(balance: storeVM.creditBalance)
                }

                // MARK: Subscriptions
                if !storeVM.subscriptionProducts.isEmpty {
                    Section("Subscriptions") {
                        ForEach(storeVM.subscriptionProducts.sorted(by: { $0.price < $1.price })) { product in
                            PurchaseProductRow(
                                product: product,
                                isActive: storeVM.activeSubscriptions.contains(where: { $0.id == product.id }),
                                onPurchase: {
                                    showSubscriptionSheet = true
                                    AnalyticsManager.log(.subscribeButtonPressedFromSettings(SubscribeButtonPressedFromSettingsEvent()))
                                }
                            )
                        }
                    }
                }

                // MARK: One-Time Purchases
                if !storeVM.oneTimeProducts.isEmpty {
                    Section("One-Time Purchases") {
                        ForEach(storeVM.oneTimeProducts) { product in
                            PurchaseProductRow(
                                product: product,
                                isActive: false,
                                onPurchase: {
                                    AnalyticsManager.log(.creditsPurchaseButtonPressedFromSettings(CreditsPurchaseButtonPressedFromSettingsEvent()))
                                    do {
                                        try await storeVM.purchase(product)
                                        let currency = product.priceFormatStyle.currencyCode
                                        let creditsAmount = ProductConfiguration.creditsAmount(for: product.id) ?? 0
                                        AnalyticsManager.log(.creditsPurchaseSucceededFromSettings(CreditsPurchaseSucceededFromSettingsEvent(
                                            productId: product.id,
                                            price: Double(truncating: product.price as NSNumber),
                                            currency: currency,
                                            creditsAmount: creditsAmount
                                        )))
                                    } catch {
                                        AnalyticsManager.log(.creditsPurchaseFailedFromSettings(CreditsPurchaseFailedFromSettingsEvent(
                                            productId: product.id,
                                            errorReason: error.localizedDescription
                                        )))
                                    }
                                }
                            )
                        }
                    }
                }

                // MARK: Account Actions
                Section("Account") {
                    if let userHandle = authViewModel.currentUserHandle, let userId = authViewModel.currentUserId {
                        HStack {
                            Text("@\(userHandle)")
                            Spacer()
                            Text(userId)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ProgressView()
                    }

                    Button {
                        Task {
                            await storeVM.restorePurchases()
                        }
                    } label: {
                        HStack {
                            Text("Restore Purchases")
                            Spacer()
                            if storeVM.isPurchasing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(storeVM.isPurchasing)


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

                Section("Preferences") {
                    NavigationLink("Actions - Confirmation Required") {
                        ConfirmationActionPreferencesView()
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("AI Data Sharing")
                                .font(.subheadline)
                            Spacer()
                            if consentManager.hasGivenConsent {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Consented")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Not Consented")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let consentDate = consentManager.consentDate {
                            Text("Consented on \(consentDate.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if consentManager.hasGivenConsent {
                        Button(role: .destructive) {
                            consentManager.revokeConsent()
                        } label: {
                            Text("Revoke AI Data Sharing Consent")
                        }
                    } else {
                        Button {
                            showConsentAlert = true
                        } label: {
                            Text("Provide AI Data Sharing Consent")
                        }
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Tweety shares voice audio, X account information, and usage data with third-party AI services (OpenAI or xAI) to power voice interactions.")
                }

                // MARK: Legal
                Section("Legal") {
                    Link(destination: URL(string: "https://tweetyvoice.app/privacypolicy/")!) {
                        HStack {
                            Text("Privacy Policy")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        HStack {
                            Text("Terms of Use")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.forward")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Logout & Delete
                Section {
                    HStack(spacing: 0) {
                        // This is to fix a "bug" where the separator is clipped
                        Text("").frame(maxWidth: 0)

                        Button {
                            Task {
                                await onLogout()
                                dismiss()
                            }
                        } label: {
                            Text("Log Out")
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                        }
                    }


                    VStack {
                        Button {
                            showDeleteAccountAlert = true
                        } label: {
                            Text("Delete Tweety Account")
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity)

                        Text("This will only delete your Tweety account, your X account's data will not be affected.")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
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
            .alert("Error", isPresented: $storeVM.showError) {
                Button("OK") {}
            } message: {
                Text(storeVM.errorMessage)
            }
            .alert("Error", isPresented: Binding(
                get: { authViewModel.error != nil },
                set: { if !$0 { authViewModel.error = nil } }
            )) {
                Button("OK") {
                    authViewModel.error = nil
                }
            } message: {
                Text(authViewModel.error?.localizedDescription ?? "An unknown error occurred")
            }
            .alert("Delete account?", isPresented: $showDeleteAccountAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        await authViewModel.deleteAccount()
                    }
                }
            }
            .aiConsentAlert(isPresented: $showConsentAlert, consentManager: consentManager)
            .overlay {
                if storeVM.isPurchasing || authViewModel.isDeletingAccount {
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

                await storeVM.loadProductsAndBalance()
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionStoreView(productIDs: storeVM.subscriptionProducts.map { $0.id })
                    .onInAppPurchaseCompletion { product, result in
                        if case .success(.success(_)) = result {
                            let currency = product.priceFormatStyle.currencyCode
                            AnalyticsManager.log(.subscribeSucceededFromSettings(SubscribeSucceededFromSettingsEvent(
                                productId: product.id,
                                price: Double(truncating: product.price as NSNumber),
                                currency: currency
                            )))
                        } else if case .failure(let error) = result {
                            AnalyticsManager.log(.subscribeFailedFromSettings(SubscribeFailedFromSettingsEvent(
                                productId: product.id,
                                errorReason: error.localizedDescription
                            )))
                        }
                    }
            }
        }
    }
}

#Preview {
    let appAttestService = AppAttestService()
    let creditsService = RemoteCreditsService(appAttestService: appAttestService)
    let authViewModel = AuthViewModel(appAttestService: .init())
    authViewModel.currentUserHandle = "@a_albahar"
    authViewModel.currentUserId = "test"

    return SettingsView(
        authViewModel: authViewModel,
        storeManager: StoreKitManager(creditsService: creditsService, authService: authViewModel.authService),
        creditsService: creditsService,
        usageTracker: UsageTracker(creditsService: creditsService),
        consentManager: AIConsentManager(),
        onLogout: {}
    )
}
