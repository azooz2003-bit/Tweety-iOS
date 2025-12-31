//
//  StoreKitManager.swift
//  GrokMode
//
//  Created by Abdulaziz Albahar on 12/28/25.
//

import Foundation
import StoreKit
internal import os

@Observable
final class StoreKitManager {
    static let shared = StoreKitManager()

    private let creditsService = RemoteCreditsService.shared
    private let appAccountTokenKey = "app_account_token"
    private let iCloudStore = NSUbiquitousKeyValueStore.default

    private var transactionObserverTask: Task<Void, Never>?
    private var restoreTask: Task<Void, Never>?

    var products: [Product] = []
    var activeSubscriptions: [Product] = []
    var creditBalance: CreditBalance?

    private init() {}

    func getOrCreateAppAccountToken() async throws -> UUID {
        // Check iCloud (source of truth - tied to Apple ID)
        if let iCloudUUID = iCloudStore.string(forKey: appAccountTokenKey),
           let uuid = UUID(uuidString: iCloudUUID) {
            AppLogger.store.info("Retrieved appAccountToken from iCloud")
            return uuid
        }

        // Check historical transactions (migration from old purchases)
        for await verificationResult in Transaction.all {
            if case .verified(let transaction) = verificationResult,
               let appAccountToken = transaction.appAccountToken {
                AppLogger.store.info("Found appAccountToken from historical transaction: \(transaction.productID)")
                // Save to iCloud for future use
                iCloudStore.set(appAccountToken.uuidString, forKey: appAccountTokenKey)
                iCloudStore.synchronize()
                return appAccountToken
            }
        }

        // Generate new user_id (first-time user)
        let newUUID = UUID()
        iCloudStore.set(newUUID.uuidString, forKey: appAccountTokenKey)
        iCloudStore.synchronize()
        AppLogger.store.info("Generated new appAccountToken for first-time user")
        return newUUID
    }

    func loadProducts() async throws {
        AppLogger.store.info("Loading products from App Store")

        let loadedProducts = try await Product.products(for: ProductConfiguration.allProductIDs)
        self.products = loadedProducts

        AppLogger.store.info("Loaded \(loadedProducts.count) products")

        await updateActiveSubscriptions()
    }

    func purchase(_ product: Product) async throws -> Transaction {
        AppLogger.store.info("Initiating purchase for product: \(product.id)")

        let appAccountToken = try await getOrCreateAppAccountToken()

        let result = try await product.purchase(options: [
            .appAccountToken(appAccountToken)
        ])

        switch result {
        case .success(let verificationResult):
            guard case .verified(let transaction) = verificationResult else {
                AppLogger.store.error("Transaction verification failed")
                throw StoreError.failedVerification
            }

            AppLogger.store.info("Purchase successful: \(transaction.productID), transactionID: \(transaction.id), originalID: \(transaction.originalID)")

            await handleTransaction(verificationResult)

            return transaction

        case .pending:
            AppLogger.store.warning("Purchase pending approval")
            throw StoreError.pending

        case .userCancelled:
            AppLogger.store.info("User cancelled purchase")
            throw StoreError.userCancelled

        @unknown default:
            throw StoreError.unknown
        }
    }

    func startObservingTransactions() {
        guard transactionObserverTask == nil else { return }

        AppLogger.store.info("Starting transaction observer - will process unfinished transactions and new purchases")

        transactionObserverTask = Task {
            for await verificationResult in Transaction.updates {
                await handleTransaction(verificationResult)
            }
        }
    }

    func stopObservingTransactions() {
        transactionObserverTask?.cancel()
        transactionObserverTask = nil
        AppLogger.store.info("Stopped transaction observer")
    }

    func restoreAllTransactions() async {
        // If a restore is already in progress, wait for it to complete instead of skipping
        // This prevents App Attest counter race conditions while ensuring all callers wait for completion
        if let existingTask = restoreTask {
            AppLogger.store.info("Restore already in progress, waiting for completion...")
            await existingTask.value
            AppLogger.store.info("Existing restore completed")
        }

        let task = Task {
            await performRestore()
            await updateActiveSubscriptions()
        }

        restoreTask = task
        await task.value
        restoreTask = nil
    }

    private func performRestore() async {
        AppLogger.store.info("Starting transaction restore")

        var unfinishedTransactions: [Transaction] = []

        // Collect all unfinished transactions
        for await verificationResult in Transaction.unfinished {
            guard case .verified(let transaction) = verificationResult else {
                continue
            }

            AppLogger.store.info("Found unfinished transaction: \(transaction.productID), ID: \(transaction.id)")
            unfinishedTransactions.append(transaction)
        }

        // Batch sync all unfinished transactions
        if !unfinishedTransactions.isEmpty {
            do {
                try await syncTransactionsBatch(unfinishedTransactions)

                // Finish all transactions after successful sync
                for transaction in unfinishedTransactions {
                    await transaction.finish()
                    AppLogger.store.info("Finished transaction: \(transaction.id)")
                }

                AppLogger.store.info("Restore complete: processed \(unfinishedTransactions.count) unfinished transactions")
            } catch {
                AppLogger.store.error("Failed to sync unfinished transactions: \(error)")
                // Don't finish transactions on error - StoreKit will redeliver
            }
        } else {
            AppLogger.store.info("Restore complete: no unfinished transactions")
        }

        await updateActiveSubscriptions()
    }

    // MARK: - Private Methods

    private func handleTransaction(_ verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else {
            AppLogger.store.warning("Received unverified transaction")
            return
        }

        AppLogger.store.info("Observer handling transaction: \(transaction.productID), ID: \(transaction.id)")

        // Sync with server - only finish if successful
        do {
            try await syncTransaction(transaction)
            await transaction.finish()
            AppLogger.store.info("Transaction synced and finished: \(transaction.id)")
        } catch {
            AppLogger.store.error("Transaction sync failed, will retry: \(error)")
            // Don't finish, let StoreKit redeliver later
        }

        await updateActiveSubscriptions()
    }

    private func syncTransaction(_ transaction: Transaction) async throws {
        // Use batch sync for single transaction (server accepts arrays)
        try await syncTransactionsBatch([transaction])
    }

    /// Sync multiple transactions as a batch
    private func syncTransactionsBatch(_ transactions: [Transaction]) async throws {
        guard !transactions.isEmpty else { return }

        let appAccountToken = try await getOrCreateAppAccountToken()

        let requests = transactions.map { $0.toSyncRequest(appAccountToken: appAccountToken) }

        let response = try await creditsService.syncTransactions(requests)

        self.creditBalance = CreditBalance(
            userId: response.userId,
            spent: response.spent,
            total: response.total,
            remaining: response.remaining
        )
    }

    private func updateActiveSubscriptions() async {
        var activeTransactions: [Transaction] = []

        for await verificationResult in Transaction.currentEntitlements {
            if case .verified(let transaction) = verificationResult {
                activeTransactions.append(transaction)
            }
        }

        // Filter to only the most recent transaction per subscription group
        
        var latestPerGroup: [String: Transaction] = [:]
        for transaction in activeTransactions {
            guard let product = products.first(where: { $0.id == transaction.productID }),
                  let subscriptionGroupID = product.subscription?.subscriptionGroupID else {
                continue
            }

            if let existing = latestPerGroup[subscriptionGroupID] {
                if transaction.purchaseDate > existing.purchaseDate {
                    latestPerGroup[subscriptionGroupID] = transaction
                }
            } else {
                latestPerGroup[subscriptionGroupID] = transaction
            }
        }

        let active = latestPerGroup.values.compactMap { transaction in
            products.first(where: { $0.id == transaction.productID })
        }

        self.activeSubscriptions = active

        AppLogger.store.info("Active subscriptions updated: \(active.count) active")
    }
}

enum StoreError: Error, LocalizedError {
    case failedVerification
    case pending
    case userCancelled
    case unknown

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .pending:
            return "Purchase is pending approval"
        case .userCancelled:
            return "Purchase was cancelled"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
