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

@Observable
class StoreManager {
    private(set) var products: [Product] = []
    private(set) var currentTier: SubscriptionTier?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private nonisolated(unsafe) var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateCurrentTier()
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
            print("Requesting products: \(productIds)")
            products = try await Product.products(for: productIds)
            print("Loaded products: \(products.map { "\($0.id): \($0.displayPrice)" })")
            products.sort { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        print("in func purchasing \(product)")
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCurrentTier()
            await transaction.finish()
            print("Purchase successful! Product: \(transaction.productID), currentTier: \(String(describing: currentTier))")
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
        // Load products if not already loaded
        
        print("purchasing \(tier.rawValue)")
        if products.isEmpty {
            await loadProducts()
        }

        guard let product = products.first(where: { $0.id == tier.rawValue }) else {
            print("Available products: \(products.map { $0.id })")
            print("Looking for: \(tier.rawValue)")
            throw StoreError.productNotFound
        }
        
        print("product: \(product)")
        return try await purchase(product)
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateCurrentTier()
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
                    await self.updateCurrentTier()
                    await transaction.finish()
                } catch {
                    // Handle verification failure
                }
            }
        }
    }

    private func updateCurrentTier() async {
        var foundTier: SubscriptionTier?

        print("Checking current entitlements...")
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                print("Found entitlement: \(transaction.productID), revoked: \(transaction.revocationDate != nil)")
                if transaction.revocationDate == nil,
                   let tier = SubscriptionTier(rawValue: transaction.productID) {
                    // Pro takes priority over Plus
                    if tier == .pro || foundTier == nil {
                        foundTier = tier
                    }
                }
            } catch {
                print("Verification failed for entitlement")
            }
        }

        print("Setting currentTier to: \(String(describing: foundTier))")
        currentTier = foundTier
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
            return tier == .plus ? "$19.99/month" : "$199.99/month"
        }
        return product.displayPrice + "/month"
    }

    func isSubscribed(to tier: SubscriptionTier) -> Bool {
        currentTier == tier
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
