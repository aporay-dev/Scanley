//
//  SubscriptionManager.swift
//  Scanley
//
//  Created by Claude on 2025-09-23.
//

import Foundation
import StoreKit
import SwiftUI

// MARK: - Subscription Models

enum SubscriptionStatus {
    case free
    case pro
    case trial
}

enum SubscriptionProduct: String, CaseIterable {
    case weekly = "scanley_pro_weekly"
    case annual = "scanley_pro_annual"

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .annual: return "Annual"
        }
    }

    var mockPrice: String {
        switch self {
        case .weekly: return "$1.99"
        case .annual: return "$19.99"
        }
    }

    var savings: String? {
        switch self {
        case .weekly: return nil
        case .annual: return "SAVE 80%"
        }
    }

    var description: String {
        switch self {
        case .weekly: return "Perfect for trying Scanley Pro"
        case .annual: return "Best value - less than $1.67/week"
        }
    }

    func getPrice(from products: [Product]) -> String {
        if let product = products.first(where: { $0.id == self.rawValue }) {
            return product.displayPrice
        }
        return mockPrice // Fallback to mock price if product not found
    }
}

struct SubscriptionState {
    var status: SubscriptionStatus
    var searchCount: Int
    var trialEndDate: Date?
    var activeProduct: SubscriptionProduct?
    var isActive: Bool

    var canSearch: Bool {
        return status != .free || searchCount < 15
    }

    var canAccessAllCategories: Bool {
        return status == .pro || status == .trial
    }

    var canViewFullScreen: Bool {
        return status == .pro || status == .trial
    }

    var canUseSearchSuggestions: Bool {
        return status == .pro || status == .trial
    }
}

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var subscriptionState = SubscriptionState(
        status: .free,
        searchCount: 0,
        trialEndDate: nil,
        activeProduct: nil,
        isActive: false
    )

    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Development settings
    private let useMockData = false // Set to false when integrating with real StoreKit

    // Persistent storage
    @AppStorage("searchCount") private var storedSearchCount: Int = 0
    @AppStorage("hasProSubscription") private var hasProSubscription: Bool = false
    @AppStorage("trialEndDate") private var trialEndDateString: String = ""
    @AppStorage("activeProductId") private var activeProductId: String = ""

    private let logger = AppLogger.shared

    private init() {
        loadStoredState()
    }

    // MARK: - Initialization

    func initialize() async {
        logger.info("Initializing SubscriptionManager", category: .lifecycle)

        if useMockData {
            await loadMockProducts()
        } else {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    // MARK: - State Management

    private func loadStoredState() {
        subscriptionState.searchCount = storedSearchCount
        subscriptionState.isActive = hasProSubscription

        // Parse trial end date
        if !trialEndDateString.isEmpty,
           let date = ISO8601DateFormatter().date(from: trialEndDateString) {
            subscriptionState.trialEndDate = date
        }

        // Parse active product
        if let product = SubscriptionProduct(rawValue: activeProductId) {
            subscriptionState.activeProduct = product
        }

        // Determine subscription status
        updateSubscriptionStatus()

        logger.debug("Loaded subscription state: \(subscriptionState.status), searches: \(subscriptionState.searchCount)", category: .lifecycle)
    }

    private func updateSubscriptionStatus() {
        if hasProSubscription {
            // Check if we're in trial period
            if let trialEnd = subscriptionState.trialEndDate,
               Date() < trialEnd {
                subscriptionState.status = .trial
            } else {
                subscriptionState.status = .pro
            }
        } else {
            subscriptionState.status = .free
        }

        subscriptionState.isActive = subscriptionState.status != .free
    }

    private func saveState() {
        storedSearchCount = subscriptionState.searchCount
        hasProSubscription = subscriptionState.isActive

        if let trialEnd = subscriptionState.trialEndDate {
            trialEndDateString = ISO8601DateFormatter().string(from: trialEnd)
        }

        if let activeProduct = subscriptionState.activeProduct {
            activeProductId = activeProduct.rawValue
        }
    }

    // MARK: - Mock Data (Development)

    private func loadMockProducts() async {
        logger.info("Loading mock subscription products", category: .lifecycle)
        isLoading = true

        // Simulate loading delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Create mock products - in real implementation, these would be loaded from StoreKit
        products = [] // Mock products would be created here

        isLoading = false
        logger.info("Loaded \(products.count) mock products", category: .lifecycle)
    }

    // MARK: - StoreKit Integration (Production)

    func loadProducts() async {
        guard !useMockData else {
            await loadMockProducts()
            return
        }

        logger.info("Loading StoreKit products", category: .lifecycle)
        isLoading = true
        errorMessage = nil

        do {
            let productIds = SubscriptionProduct.allCases.map { $0.rawValue }
            products = try await Product.products(for: Set(productIds))
            logger.info("Loaded \(products.count) StoreKit products", category: .lifecycle)
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)", category: .lifecycle)
            errorMessage = "Failed to load subscription options"
        }

        isLoading = false
    }

    func purchase(_ product: SubscriptionProduct) async -> Bool {
        if useMockData {
            return await mockPurchase(product)
        }

        // Find the actual Product
        guard let storeProduct = products.first(where: { $0.id == product.rawValue }) else {
            logger.error("Product not found: \(product.rawValue)", category: .lifecycle)
            return false
        }

        logger.info("Starting purchase for product: \(product.rawValue)", category: .lifecycle)
        isLoading = true
        errorMessage = nil

        do {
            let result = try await storeProduct.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await processPurchase(product: product, transaction: transaction)
                    logger.info("Purchase successful: \(product.rawValue)", category: .lifecycle)
                    return true
                case .unverified:
                    logger.error("Purchase verification failed", category: .lifecycle)
                    errorMessage = "Purchase verification failed"
                    return false
                }
            case .userCancelled:
                logger.info("Purchase cancelled by user", category: .lifecycle)
                return false
            case .pending:
                logger.info("Purchase is pending", category: .lifecycle)
                errorMessage = "Purchase is pending approval"
                return false
            @unknown default:
                logger.error("Unknown purchase result", category: .lifecycle)
                return false
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)", category: .lifecycle)
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    private func mockPurchase(_ product: SubscriptionProduct) async -> Bool {
        logger.info("Mock purchasing: \(product.rawValue)", category: .lifecycle)
        isLoading = true

        // Simulate purchase delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Simulate successful purchase
        subscriptionState.status = .trial
        subscriptionState.activeProduct = product
        subscriptionState.trialEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        subscriptionState.isActive = true

        saveState()
        isLoading = false

        logger.info("Mock purchase successful: \(product.rawValue)", category: .lifecycle)
        return true
    }

    private func processPurchase(product: SubscriptionProduct, transaction: StoreKit.Transaction) async {
        subscriptionState.activeProduct = product
        subscriptionState.isActive = true

        // Check if this is a trial period
        // This would need to be determined based on the transaction details
        subscriptionState.status = .pro // or .trial if within trial period

        saveState()
        updateSubscriptionStatus()
    }

    func restorePurchases() async -> Bool {
        if useMockData {
            logger.info("Mock restore purchases", category: .lifecycle)
            return true
        }

        logger.info("Restoring purchases", category: .lifecycle)
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            logger.info("Purchases restored successfully", category: .lifecycle)
            return true
        } catch {
            logger.error("Failed to restore purchases: \(error.localizedDescription)", category: .lifecycle)
            errorMessage = "Failed to restore purchases"
            return false
        }
    }

    func checkSubscriptionStatus() async {
        if useMockData {
            updateSubscriptionStatus()
            return
        }

        logger.info("Checking subscription status", category: .lifecycle)

        for await result in StoreKit.Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if let product = SubscriptionProduct(rawValue: transaction.productID) {
                    await processPurchase(product: product, transaction: transaction)
                }
            case .unverified:
                logger.warning("Unverified transaction found", category: .lifecycle)
            }
        }

        updateSubscriptionStatus()
    }

    // MARK: - Usage Tracking

    func incrementSearchCount() {
        guard subscriptionState.status == .free else { return }

        subscriptionState.searchCount += 1
        saveState()

        logger.debug("Search count incremented to: \(subscriptionState.searchCount)", category: .lifecycle)

        // Log when approaching limit
        if subscriptionState.searchCount >= 10 {
            logger.info("User approaching search limit: \(subscriptionState.searchCount)/15", category: .lifecycle)
        }
    }

    var remainingSearches: Int {
        guard subscriptionState.status == .free else { return Int.max }
        return max(0, 15 - subscriptionState.searchCount)
    }

    var hasReachedSearchLimit: Bool {
        return subscriptionState.status == .free && subscriptionState.searchCount >= 15
    }

    // MARK: - Access Control Helpers

    func canAccessCategory(_ categoryName: String) -> Bool {
        guard subscriptionState.status == .free else { return true }

        let freeCategoryNames = ["Tax", "Receipts", "Invoices & Bills"]
        return freeCategoryNames.contains(categoryName)
    }

    func requiresUpgradeForCategory(_ categoryName: String) -> Bool {
        return !canAccessCategory(categoryName)
    }

    // MARK: - Debug Helpers

    #if DEBUG
    func mockTrialExpired() {
        subscriptionState.trialEndDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        updateSubscriptionStatus()
        saveState()
    }

    func mockResetToFree() {
        subscriptionState = SubscriptionState(
            status: .free,
            searchCount: 0,
            trialEndDate: nil,
            activeProduct: nil,
            isActive: false
        )
        saveState()
    }

    func mockSetSearchCount(_ count: Int) {
        subscriptionState.searchCount = count
        saveState()
    }
    #endif
}

// MARK: - Environment Integration

struct SubscriptionManagerKey: EnvironmentKey {
    @MainActor static var defaultValue: SubscriptionManager {
        SubscriptionManager.shared
    }
}

extension EnvironmentValues {
    var subscriptionManager: SubscriptionManager {
        get { self[SubscriptionManagerKey.self] }
        set { self[SubscriptionManagerKey.self] = newValue }
    }
}