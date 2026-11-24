import EntitlementCore
import Foundation
import ImmerseServer
import Observation
import StoreKit
import SwiftUI

extension EnvironmentValues {
    /// Buying Rolls, where the app has a server; nil everywhere else, the mini-app included, which sells nothing.
    @Entry var rollShop: RollShop? = nil
}

/// A Roll purchase's transaction as the app holds it: its signed form for the server, and the way to finish it.
struct RollTransaction: Sendable {
    let id: UInt64
    let productID: String
    /// The transaction as the App Store signed it (JWS), which the server verifies and confirms with Apple.
    let signedTransaction: String
    let finish: @Sendable () async -> Void
}

/// A Roll pack's App Store product: its price as the App Store shows it in the person's storefront.
struct RollProduct: Equatable, Sendable {
    let id: String
    let displayPrice: String
}

enum RollStorePurchase: Sendable {
    case purchased(RollTransaction)
    case pending
    case cancelled
}

/// StoreKit, behind the few calls the shop makes, so Debug screen tests can stand in for it (`DebugRollStore`).
@MainActor
protocol RollStore: AnyObject {
    func products(for ids: [String]) async throws -> [RollProduct]
    func purchase(productID: String, appAccountToken: UUID) async throws -> RollStorePurchase
    /// Roll purchases StoreKit holds that the app has not finished, such as one whose report never reached the server.
    func unfinished() async -> [RollTransaction]
    /// Roll purchases completed outside a purchase call: an Ask to Buy approved later, a refund, another device's.
    func updates() -> AsyncStream<RollTransaction>
    /// The v1 subscription's current signed transaction on this iPhone, when it is active.
    func subscriptionTransaction(productIDs: Set<String>) async -> String?
}

/// The real store: StoreKit 2 (section 9.7). Only consumables are Roll purchases; the subscription's own transactions are
/// left to `SubscriptionController`, as before.
@MainActor
final class StoreKitRollStore: RollStore {
    struct Unverified: Error {}

    func products(for ids: [String]) async throws -> [RollProduct] {
        try await Product.products(for: ids).filter { $0.type == .consumable }.map { RollProduct(id: $0.id, displayPrice: $0.displayPrice) }
    }

    func purchase(productID: String, appAccountToken: UUID) async throws -> RollStorePurchase {
        guard let product = try await Product.products(for: [productID]).first, product.type == .consumable else {
            throw StoreKitError.notAvailableInStorefront
        }
        switch try await product.purchase(options: [.appAccountToken(appAccountToken)]) {
        case .success(let result): return .purchased(Self.rollTransaction(result))
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: return .cancelled
        }
    }

    func unfinished() async -> [RollTransaction] {
        var found: [RollTransaction] = []
        for await result in StoreKit.Transaction.unfinished where result.unsafePayloadValue.productType == .consumable {
            found.append(Self.rollTransaction(result))
        }
        return found
    }

    func updates() -> AsyncStream<RollTransaction> {
        AsyncStream { continuation in
            let task = Task {
                for await result in StoreKit.Transaction.updates where result.unsafePayloadValue.productType == .consumable {
                    continuation.yield(Self.rollTransaction(result))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func subscriptionTransaction(productIDs: Set<String>) async -> String? {
        for await result in StoreKit.Transaction.currentEntitlements {
            let transaction = result.unsafePayloadValue
            if case .verified = result, productIDs.contains(transaction.productID), transaction.productType == .autoRenewable,
               transaction.revocationDate == nil {
                return result.jwsRepresentation
            }
        }
        return nil
    }

    /// Whatever StoreKit's own check says, the server verifies the signed transaction itself, so an unverified one is
    /// still reported: the server refuses what Apple did not sign.
    private static func rollTransaction(_ result: VerificationResult<StoreKit.Transaction>) -> RollTransaction {
        let transaction = result.unsafePayloadValue
        return RollTransaction(id: transaction.id, productID: transaction.productID, signedTransaction: result.jwsRepresentation,
                               finish: { await transaction.finish() })
    }
}

/// Buying Rolls and the balance (v2 PRD V2-FR-60 to V2-FR-65, section 9.7), in the full app only.
///
/// What is on sale and how many Rolls each pack adds come from the server; the price comes from the App Store; the app
/// holds no number of the pricing decision (V2-FR-64). A purchase carries the Account's token, its signed transaction
/// goes to the server, and the app finishes it only once the server holds it for good, so a purchase whose report is
/// lost is reported again from StoreKit's unfinished transactions the next time the app runs. A purchase waiting for
/// Ask to Buy adds nothing until Apple completes it; the server learns of it then from Apple, and the app from StoreKit.
@MainActor @Observable
final class RollShop {
    struct OnSale: Identifiable, Equatable {
        let pack: RollPack
        let price: String
        var id: String { pack.productId }
    }

    enum Shelf: Equatable {
        case loading
        /// The server sells no Rolls yet (before the pricing decision, OC-5), or the App Store has none of its packs.
        case notOnSale
        /// What is on sale could not be read: no network, or the App Store did not answer.
        case couldNotLoad
        case onSale([OnSale])
    }

    struct Notice: Equatable {
        enum Kind { case done, info, problem }
        let kind: Kind
        let text: String
    }

    private(set) var shelf: Shelf = .loading
    private(set) var balance: Int?
    private(set) var history: [BalanceEntry] = []
    /// The subscriber Rolls this Account has had, once ever (V2-FR-62).
    private(set) var subscriberRolls: Int?
    private(set) var subscriberOffered = false
    /// A purchase is under way: the App Store's sheet, or its report to the server.
    private(set) var buying = false
    /// A purchase waits for Ask to Buy approval (V2-FR-65).
    private(set) var awaitingApproval = false
    var notice: Notice?

    let hosting: HostingSession
    private let server: RollServer
    private let store: RollStore
    private let subscriptionProductIDs: Set<String>
    private let supportAddress: String?
    /// Told when the balance may have changed, so the Group Films' screens read it again.
    @ObservationIgnored var balanceChanged: (@MainActor () async -> Void)?
    @ObservationIgnored private var reporting: Set<UInt64> = []
    // Written once in init and only cancelled in deinit; see SubscriptionController for why it is not isolated.
    @ObservationIgnored private nonisolated(unsafe) var listener: Task<Void, Never>?

    init(hosting: HostingSession, functions: any ServerFunctions, store: RollStore, subscriptionProductIDs: Set<String>,
         supportAddress: String?) {
        self.hosting = hosting
        self.server = RollServer(functions: functions)
        self.store = store
        self.subscriptionProductIDs = subscriptionProductIDs
        self.supportAddress = supportAddress
        let stream = store.updates()
        listener = Task { [weak self] in
            for await transaction in stream {
                guard !Task.isCancelled, let self else { return }
                await self.report(transaction, fromPurchase: false)
            }
        }
        Task { [weak self] in await self?.reportUnfinished() }
    }

    deinit { listener?.cancel() }

    /// Reads what is on sale, the balance and its history, reports any purchase still waiting for the server, and sends
    /// an active subscription to the server once, for its free Rolls.
    func refresh() async {
        guard hosting.isSignedIn else { return }
        await reportUnfinished()
        do {
            let catalog = try await server.catalog()
            subscriberOffered = catalog.subscriberOffered
            subscriberRolls = catalog.subscriberRollsCredited
            if catalog.packs.isEmpty {
                shelf = .notOnSale
            } else {
                let products = try await store.products(for: catalog.packs.map(\.productId))
                let onSale = catalog.packs.compactMap { pack in
                    products.first { $0.id == pack.productId }.map { OnSale(pack: pack, price: $0.displayPrice) }
                }
                shelf = onSale.isEmpty ? .notOnSale : .onSale(onSale.sorted { $0.pack.rolls < $1.pack.rolls })
            }
        } catch {
            if shelf == .loading { shelf = .couldNotLoad }
        }
        await linkSubscriptionIfNeeded()
        await readBalance()
    }

    private func readBalance() async {
        if let balance = try? await EventServer(functions: hosting.functions).balance() { self.balance = balance }
        if let history = try? await server.history() { self.history = history }
        await balanceChanged?()
    }

    /// Buys a pack (V2-FR-60). A signed-out person is asked to sign in first; the Rolls screen shows sign-in instead.
    func buy(_ sale: OnSale) async {
        guard !buying else { return }
        guard hosting.isSignedIn else {
            notice = Notice(kind: .info, text: "Sign in to buy Rolls.")
            return
        }
        buying = true
        notice = nil
        defer { buying = false }
        let token: UUID
        do {
            token = try await server.shoppingToken()
        } catch {
            notice = Notice(kind: .problem, text: GroupFilmsCopy.words(for: error))
            return
        }
        do {
            switch try await store.purchase(productID: sale.pack.productId, appAccountToken: token) {
            case .purchased(let transaction):
                awaitingApproval = false
                await report(transaction, fromPurchase: true)
            case .pending:
                awaitingApproval = true
                notice = Notice(kind: .info, text: RollShopCopy.pending)
            case .cancelled:
                break
            }
        } catch {
            notice = Notice(kind: .problem, text: RollShopCopy.didNotFinish)
        }
    }

    private func reportUnfinished() async {
        for transaction in await store.unfinished() { await report(transaction, fromPurchase: false) }
    }

    /// Sends a purchase to the server and finishes it only once the server holds it for good (V2-FR-60, V2-FR-65).
    private func report(_ transaction: RollTransaction, fromPurchase: Bool) async {
        guard reporting.insert(transaction.id).inserted else { return }
        defer { reporting.remove(transaction.id) }
        do {
            let answer = try await server.creditPurchase(signedTransaction: transaction.signedTransaction)
            if answer.credit.settled { await transaction.finish() }
            if let balance = answer.balance { self.balance = balance }
            switch answer.credit {
            case .credited(let rolls, let toThisAccount):
                awaitingApproval = false
                if fromPurchase || toThisAccount {
                    notice = Notice(kind: toThisAccount ? .done : .info,
                                    text: toThisAccount ? RollShopCopy.added(rolls) : RollShopCopy.otherAccount)
                }
            case .refunded:
                if fromPurchase { notice = Notice(kind: .info, text: RollShopCopy.refunded) }
            case .unassigned:
                if fromPurchase { notice = Notice(kind: .info, text: RollShopCopy.signInToAdd) }
            case .notOnSale:
                if fromPurchase { notice = Notice(kind: .info, text: RollShopCopy.safeWithApple) }
            }
            await readBalance()
        } catch .refused(.purchaseRefused) {
            // Kept unfinished: the purchase stays with Apple, and support can look into it.
            if fromPurchase { notice = Notice(kind: .problem, text: RollShopCopy.notConfirmed(support: supportAddress)) }
        } catch {
            // Unreachable, or Apple could not confirm it yet: kept unfinished and reported again later.
            if fromPurchase { notice = Notice(kind: .info, text: RollShopCopy.safeWithApple) }
        }
    }

    /// Sends the v1 subscription to the server once, so it confirms it with Apple and credits the subscriber's free Rolls
    /// (V2-FR-63). Only while signed in, only where the server offers them and this Account has not had them.
    func linkSubscriptionIfNeeded() async {
        guard hosting.isSignedIn, subscriberOffered, subscriberRolls == nil, !subscriptionProductIDs.isEmpty,
              let signed = await store.subscriptionTransaction(productIDs: subscriptionProductIDs) else { return }
        guard let answer = try? await server.linkSubscription(signedTransaction: signed) else { return }
        balance = answer.balance
        switch answer.link {
        case .credited(let rolls):
            subscriberRolls = rolls
            notice = Notice(kind: .done, text: RollShopCopy.subscriberCredited(rolls))
        case .alreadyCredited(let rolls):
            subscriberRolls = rolls
        case .linkedElsewhere:
            notice = Notice(kind: .info, text: RollShopCopy.linkedElsewhere(support: supportAddress))
        case .accountAlreadyCredited, .notActive:
            break
        }
    }
}

/// What the Rolls screen says (V2-FR-60 to V2-FR-65, section 7), in one place.
enum RollShopCopy {
    static func added(_ rolls: Int) -> String { "\(rolls) \(rolls == 1 ? "Roll" : "Rolls") added to your balance." }
    static let otherAccount = "This purchase was made while another Immerse Account was signed in, so its Rolls are in that Account's balance."
    static let refunded = "Apple refunded this purchase, so its Rolls are not in your balance."
    static let pending = "Waiting for approval. The Rolls are added to your balance once the purchase is approved."
    static let didNotFinish = "The purchase did not finish. Your balance is unchanged; try again."
    static let safeWithApple = "Your purchase is safe with Apple. Its Rolls are added to your balance once Immerse's server confirms it, which needs a connection."
    static let signInToAdd = "Your purchase is safe with Apple. Sign in to add its Rolls to your balance."
    static func notConfirmed(support: String?) -> String {
        "Immerse's server could not confirm this purchase with Apple. It stays safe with Apple; contact support\(support.map { " at \($0)" } ?? "") and Immerse will look into it."
    }
    static func subscriberCredited(_ rolls: Int) -> String { "Your subscription brought \(rolls) free Rolls." }
    static func linkedElsewhere(support: String?) -> String {
        "This subscription's free Rolls went to another Immerse Account. Support\(support.map { " at \($0)" } ?? "") can move them."
    }
    static let notOnSale = "Rolls are not on sale yet."
    static let couldNotLoad = "Rolls on sale could not load. Check the connection and try again."
    static let belowZero = "A refund took your balance below zero. Rolls can be set aside again once it is above zero."
    static let keeping = "Rolls never expire. They stay with your Account, on every iPhone you sign in on, and Rolls nobody takes come back after an event."

    /// When a history entry happened, as a line of its own in the person's time zone and locale: "Today at 8:57 AM",
    /// "Yesterday at 8:57 AM", "Nov 22, 2026 at 8:57 AM".
    static func historyTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    static func history(_ entry: BalanceEntry) -> String {
        switch entry.kind {
        case .purchase: "Bought"
        case .free: entry.subscriber ? "Free Rolls for subscribers" : "Free Rolls"
        case .setAside: entry.eventTitle.map { "Set aside for \($0)" } ?? "Set aside for an event"
        case .return: entry.eventTitle.map { "Came back from \($0)" } ?? "Came back from an event"
        case .refund: "Refunded by Apple"
        case .refundReversed: "Refund reversed by Apple"
        }
    }
}
