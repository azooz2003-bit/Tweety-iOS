//
//  StoreViewModel.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 12/28/25.
//

import Foundation
import StoreKit
internal import os

@Observable
final class StoreViewModel {
    var products: [Product] {
        storeManager.products
    }
    var activeSubscriptions: [Product] {
        storeManager.activeSubscriptions
    }
    var creditBalance: CreditBalance? {
        get { storeManager.creditBalance }
        set { storeManager.creditBalance = newValue }
    }
    var isPurchasing = false
    var showError = false
    var errorMessage = ""

    private let storeManager: StoreKitManager
    private let creditsService: RemoteCreditsService
    private let authService: XAuthService

    init(storeManager: StoreKitManager, creditsService: RemoteCreditsService, authService: XAuthService) {
        self.storeManager = storeManager
        self.creditsService = creditsService
        self.authService = authService
    }

    var subscriptionProducts: [Product] {
        products.filter { $0.type == .autoRenewable }
    }

    var oneTimeProducts: [Product] {
        products.filter { $0.type == .consumable }
    }

    func loadProductsAndBalance() async {
        do {
            try await storeManager.loadProducts()

            let userId = try await authService.requiredUserId
            self.creditBalance = try await creditsService.getBalance(userId: userId)
        } catch {
            self.errorMessage = "Failed to load products: \(error.localizedDescription)"
            self.showError = true
            AppLogger.store.error("StoreViewModel loadData failed: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            _ = try await storeManager.purchase(product)

            let userId = try await authService.requiredUserId
            self.creditBalance = try await creditsService.getBalance(userId: userId)
        } catch StoreError.userCancelled {
            AppLogger.store.info("User cancelled purchase")
        } catch {
            self.errorMessage = "Purchase failed: \(error.localizedDescription)"
            self.showError = true
            AppLogger.store.error("Purchase failed: \(error)")
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            await storeManager.restoreAllTransactions()

            let userId = try await authService.requiredUserId
            self.creditBalance = try await creditsService.getBalance(userId: userId)

            AppLogger.store.info("Restore purchases completed - balance and subscriptions refreshed")
        } catch {
            self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            self.showError = true
            AppLogger.store.error("Restore purchases failed: \(error)")
        }
    }
}
