//
//  LunixiaStoreManager.swift
//  Lunixia
//

import Foundation
import StoreKit
import Combine

@MainActor
final class LunixiaStoreManager: ObservableObject {

    // MARK: - Product IDs

    enum ProductID {
        static let weekly = "com.lunixia.premium.weekly"
        static let monthly = "com.lunixia.premium.monthly"
        static let yearly = "com.lunixia.premium.yearly"
    }

    static let premiumProductIDs: Set<String> = [
        ProductID.weekly,
        ProductID.monthly,
        ProductID.yearly
    ]

    // MARK: - Published State

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var activePremiumProductID: String? = nil
    @Published private(set) var isPremium: Bool = true
    @Published private(set) var adminPremiumOverrideEnabled: Bool = true
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private var transactionUpdatesTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        // Premium is disabled. Keep the StoreKit startup code available for a
        // future re-enable without allowing it to run in the current app.
        #if false
        transactionUpdatesTask = listenForTransactions()

        adminPremiumOverrideEnabled = UserDefaults.standard.bool(forKey: "lunixia.adminPremiumOverrideEnabled")

        Task {
            await refresh()
        }
        #endif
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    // MARK: - Public API

    func refresh() async {
        #if false
        await loadProducts()
        await updatePurchasedProducts()
        #endif
    }

    func loadProducts() async {
        #if false
        isLoadingProducts = true
        lastErrorMessage = nil
        defer { isLoadingProducts = false }

        do {
            let loadedProducts = try await Product.products(for: Array(Self.premiumProductIDs))

            products = loadedProducts.sorted { lhs, rhs in
                subscriptionSortOrder(lhs.id) < subscriptionSortOrder(rhs.id)
            }
        } catch {
            lastErrorMessage = "Unable to load premium options."
            print("[LunixiaStoreManager] Failed to load products: \(error)")
        }
        #endif
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        #if false
        isPurchasing = true
        lastErrorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try checkVerified(verificationResult)
                await transaction.finish()
                await updatePurchasedProducts()
                return true

            case .userCancelled:
                return false

            case .pending:
                lastErrorMessage = "Purchase is pending approval."
                return false

            @unknown default:
                lastErrorMessage = "Purchase could not be completed."
                return false
            }
        } catch {
            lastErrorMessage = "Purchase failed. Please try again."
            print("[LunixiaStoreManager] Purchase failed: \(error)")
            return false
        }
        #else
        return false
        #endif
    }

    func restorePurchases() async {
        #if false
        lastErrorMessage = nil

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            lastErrorMessage = "Unable to restore purchases."
            print("[LunixiaStoreManager] Restore failed: \(error)")
        }
        #endif
    }

    func updatePurchasedProducts() async {
        #if false
        var activeProductIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                guard Self.premiumProductIDs.contains(transaction.productID) else {
                    continue
                }

                guard transaction.revocationDate == nil else {
                    continue
                }

                if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                    continue
                }

                activeProductIDs.insert(transaction.productID)
            } catch {
                print("[LunixiaStoreManager] Unverified entitlement ignored: \(error)")
            }
        }

        purchasedProductIDs = activeProductIDs
        activePremiumProductID = activeProductIDs.sorted {
            subscriptionSortOrder($0) < subscriptionSortOrder($1)
        }.first
        isPremium = adminPremiumOverrideEnabled || !activeProductIDs.isEmpty
        #else
        isPremium = true
        #endif
    }

    func owns(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
    }

    func product(for productID: String) -> Product? {
        products.first { $0.id == productID }
    }

    func premiumProductTitle(for productID: String) -> String {
        switch productID {
        case ProductID.weekly:
            return "Weekly"
        case ProductID.monthly:
            return "Monthly"
        case ProductID.yearly:
            return "Yearly"
        default:
            return "Premium"
        }
    }

    func toggleAdminPremiumOverride() {
        #if false
        adminPremiumOverrideEnabled.toggle()
        UserDefaults.standard.set(adminPremiumOverrideEnabled, forKey: "lunixia.adminPremiumOverrideEnabled")
        isPremium = adminPremiumOverrideEnabled || !purchasedProductIDs.isEmpty
        #endif
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }

                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    print("[LunixiaStoreManager] Transaction update failed verification: \(error)")
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Sorting

    private func subscriptionSortOrder(_ productID: String) -> Int {
        switch productID {
        case ProductID.weekly:
            return 0
        case ProductID.monthly:
            return 1
        case ProductID.yearly:
            return 2
        default:
            return 99
        }
    }

    // MARK: - Errors

    enum StoreError: Error {
        case failedVerification
    }
}
