import Foundation
import StoreKit

public struct SubscriptionConfiguration: Equatable, Sendable {
    public let monthlyProductID: String
    public let yearlyProductID: String
    public var productIDs: Set<String> { [monthlyProductID, yearlyProductID] }

    public init(monthlyProductID: String, yearlyProductID: String) throws {
        guard !monthlyProductID.isEmpty, !yearlyProductID.isEmpty, monthlyProductID != yearlyProductID else {
            throw SubscriptionStoreError.invalidConfiguration
        }
        self.monthlyProductID = monthlyProductID
        self.yearlyProductID = yearlyProductID
    }
}

public enum SubscriptionStoreError: Error, Equatable, Sendable {
    case invalidConfiguration, unavailable, unverifiedTransaction, unexpectedProduct
}

public enum SubscriptionPurchaseOutcome: Equatable, Sendable {
    case purchased, pending, cancelled
}

/// StoreKit owns verification and its local entitlement cache. No app Account,
/// server, manually editable paid flag, or automatic AppStore.sync is used.
public struct StoreKitSubscriptions: Sendable {
    public let configuration: SubscriptionConfiguration?
    public init(configuration: SubscriptionConfiguration?) { self.configuration = configuration }

    public func products() async throws -> [Product] {
        guard let configuration else { throw SubscriptionStoreError.unavailable }
        let products = try await Product.products(for: configuration.productIDs)
        guard products.count == 2,
              let month = products.first(where: { $0.id == configuration.monthlyProductID }),
              let year = products.first(where: { $0.id == configuration.yearlyProductID }),
              month.type == .autoRenewable, year.type == .autoRenewable,
              month.subscription?.subscriptionPeriod.value == 1,
              month.subscription?.subscriptionPeriod.unit == .month,
              year.subscription?.subscriptionPeriod.value == 1,
              year.subscription?.subscriptionPeriod.unit == .year,
              month.subscription?.subscriptionGroupID == year.subscription?.subscriptionGroupID else {
            throw SubscriptionStoreError.unexpectedProduct
        }
        return [month, year]
    }

    public func access() async -> SubscriptionAccess {
        guard let configuration else { return .notPurchased }
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result,
               configuration.productIDs.contains(transaction.productID),
               transaction.productType == .autoRenewable,
               transaction.revocationDate == nil, !transaction.isUpgraded {
                if let expiry = transaction.expirationDate, expiry > Date() { return .active }
                if let status = await transaction.subscriptionStatus,
                   status.state == .inGracePeriod,
                   case let .verified(renewal) = status.renewalInfo,
                   let graceEnd = renewal.gracePeriodExpirationDate, graceEnd > Date() {
                    return .active
                }
            }
        }
        for id in configuration.productIDs {
            if let result = await Transaction.latest(for: id), case .verified = result { return .expired }
        }
        return .notPurchased
    }

    public func purchase(productID: String) async throws -> SubscriptionPurchaseOutcome {
        guard let product = try await products().first(where: { $0.id == productID }) else {
            throw SubscriptionStoreError.unexpectedProduct
        }
        switch try await product.purchase() {
        case let .success(result):
            guard case let .verified(transaction) = result else { throw SubscriptionStoreError.unverifiedTransaction }
            guard transaction.productID == productID else { throw SubscriptionStoreError.unexpectedProduct }
            await transaction.finish()
            return .purchased
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw SubscriptionStoreError.unavailable
        }
    }

    public func restore() async throws -> SubscriptionAccess {
        guard configuration != nil else { throw SubscriptionStoreError.unavailable }
        try await AppStore.sync()
        return await access()
    }

    public func updates() -> AsyncStream<SubscriptionAccess> {
        AsyncStream { continuation in
            let task = Task {
                guard let configuration else { continuation.finish(); return }
                for await result in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    if case let .verified(transaction) = result,
                       configuration.productIDs.contains(transaction.productID) {
                        await transaction.finish()
                        continuation.yield(await access())
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
