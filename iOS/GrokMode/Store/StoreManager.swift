//
//  StoreManager.swift
//  GrokMode
//

import StoreKit

enum SubscriptionTier: String, CaseIterable {
    case plus = "com.grokmode.plus"
    case pro = "com.grokmode.pro"

    var displayName: String {
        switch self {
        case .plus: return "Plus"
        case .pro: return "Pro"
        }
    }

    var minutesPerMonth: Int? {
        switch self {
        case .plus: return 100
        case .pro: return nil // Unlimited
        }
    }
}

@MainActor
@Observable
class StoreManager {
    private(set) var products: [Product] = []
    private(set) var purchasedSubscriptions: Set<String> = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private nonisolated(unsafe) var updateListenerTask: Task<Void, Error>?

    var currentTier: SubscriptionTier? {
        if purchasedSubscriptions.contains(SubscriptionTier.pro.rawValue) {
            return .pro
        } else if purchasedSubscriptions.contains(SubscriptionTier.plus.rawValue) {
            return .plus
        }
        return nil
    }

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedSubscriptions()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let productIds = SubscriptionTier.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIds)
            products.sort { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedSubscriptions()
            await transaction.finish()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    func purchase(tier: SubscriptionTier) async throws -> Bool {
        guard let product = products.first(where: { $0.id == tier.rawValue }) else {
            throw StoreError.productNotFound
        }
        return try await purchase(product)
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedSubscriptions()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }

    // MARK: - Transaction Handling

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedSubscriptions()
                    await transaction.finish()
                } catch {
                    // Handle verification failure
                }
            }
        }
    }

    private func updatePurchasedSubscriptions() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    purchased.insert(transaction.productID)
                }
            } catch {
                // Handle verification failure
            }
        }

        purchasedSubscriptions = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Helpers

    func product(for tier: SubscriptionTier) -> Product? {
        products.first { $0.id == tier.rawValue }
    }

    func priceString(for tier: SubscriptionTier) -> String {
        guard let product = product(for: tier) else {
            return tier == .plus ? "$20/month" : "$200/month"
        }
        return product.displayPrice + "/month"
    }

    func isSubscribed(to tier: SubscriptionTier) -> Bool {
        purchasedSubscriptions.contains(tier.rawValue)
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case productNotFound
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .verificationFailed:
            return "Transaction verification failed"
        }
    }
}
