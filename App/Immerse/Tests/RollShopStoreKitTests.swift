import Foundation
import ImmerseServer
import StoreKit
import StoreKitTest
import XCTest
@testable import Immerse

/// Buying Rolls through real StoreKit (v2 PRD V2-FR-60, V2-FR-65, section 9.7), in Apple's local StoreKit test session
/// with the synthetic packs of `Fixtures/LocalRolls.storekit`, against a stand-in for the server's Roll functions: a
/// purchase carries the Account's token, reaches the server once and is finished only after the server holds it; one the
/// server cannot confirm stays unfinished and is credited when the app runs again; Ask to Buy adds nothing until
/// approved; and a failed purchase changes nothing. A refund is not held here: on CI's iOS 26.2 billing simulator, StoreKit's
/// local session did not deliver a finished consumable's refund to `Transaction.updates` within 15 seconds
/// (`Evidence/NativeApp/v2-stage4-rolls-087.md`), and Apple's `REFUND` notification to the server is the PRD's path.
@MainActor
final class RollShopStoreKitTests: XCTestCase {
    private let small = "test.immerse.rolls.small"
    private let large = "test.immerse.rolls.large"

    private func session() async throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LocalRolls", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        let products = try await Product.products(for: [small, large])
        guard Set(products.map(\.id)) == Set([small, large]), products.allSatisfy({ $0.displayName.hasPrefix("Test ") }) else {
            throw NSError(domain: "ImmerseStoreKitTestIsolation", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Local StoreKit fixture is not active. No purchase API may run."])
        }
        return session
    }

    private func shop(_ server: RollStandInServer, signedIn: Bool = true, store: RollStore = StoreKitRollStore()) -> RollShop {
        let defaults = UserDefaults(suiteName: "RollShopStoreKitTests-\(UUID().uuidString)")!
        if signedIn { defaults.set("Maya", forKey: "ImmerseHostDisplayName") }
        let hosting = HostingSession(signIn: RollShopSignIn(session: signedIn), functions: server, defaults: defaults)
        return RollShop(hosting: hosting, functions: server, store: store, subscriptionProductIDs: [],
                        supportAddress: "support@immerse.test")
    }

    private func unfinishedRollPurchases() async -> [UInt64] {
        var ids: [UInt64] = []
        for await result in StoreKit.Transaction.unfinished where result.unsafePayloadValue.productType == .consumable {
            ids.append(result.unsafePayloadValue.id)
        }
        return ids
    }

    private func eventually(_ what: String, timeout: TimeInterval = 15, _ condition: () async -> Bool) async throws {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTFail("Timed out waiting for \(what)")
    }

    private func onSale(_ shop: RollShop) throws -> [RollShop.OnSale] {
        guard case .onSale(let packs) = shop.shelf else { throw XCTSkip("Nothing on sale: \(shop.shelf)") }
        return packs
    }

    func testABoughtPackCarriesTheTokenIsCreditedOnceAndIsFinishedOnlyOnceTheServerHoldsIt() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let server = RollStandInServer()
        let shop = shop(server)
        await shop.refresh()
        let packs = try onSale(shop)
        XCTAssertEqual(packs.map(\.pack.rolls), [5, 25])
        // The price is the App Store's, from the fixture; the app holds none.
        XCTAssertEqual(packs.map(\.price), ["$0.01", "$0.02"])
        XCTAssertEqual(shop.balance, 3)

        await shop.buy(packs[0])
        XCTAssertEqual(server.credited.count, 1)
        XCTAssertEqual(Set(server.tokens), [RollStandInServer.token.uuidString.lowercased()],
                       "The purchase carries the Account's token")
        XCTAssertEqual(shop.balance, 8)
        XCTAssertEqual(shop.notice, RollShop.Notice(kind: .done, text: "5 Rolls added to your balance."))
        let finished = await unfinishedRollPurchases()
        XCTAssertEqual(finished, [], "A purchase the server holds is finished")

        // A second shop, as after a relaunch, reports nothing more and credits nothing more.
        let relaunched = self.shop(server)
        await relaunched.refresh()
        XCTAssertEqual(server.credited.count, 1)
        XCTAssertEqual(relaunched.balance, 8)
    }

    func testAPurchaseTheServerCannotConfirmStaysUnfinishedAndIsCreditedWhenTheAppRunsAgain() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let server = RollStandInServer()
        let shop = shop(server)
        await shop.refresh()
        let packs = try onSale(shop)
        server.unreachable = true
        await shop.buy(packs[1])
        XCTAssertEqual(shop.notice, RollShop.Notice(kind: .info, text: RollShopCopy.safeWithApple))
        XCTAssertEqual(server.credited.count, 0)
        let waiting = await unfinishedRollPurchases()
        XCTAssertEqual(waiting.count, 1, "Kept unfinished until the server holds it")

        server.unreachable = false
        let relaunched = self.shop(server)
        try await eventually("the unfinished purchase to be credited") { server.credited.count == 1 }
        try await eventually("the purchase to be finished") { await self.unfinishedRollPurchases().isEmpty }
        await relaunched.refresh()
        XCTAssertEqual(relaunched.balance, 28)
        XCTAssertEqual(server.credited.count, 1)
    }

    func testAskToBuyAddsNothingUntilApprovedAndNothingWhenDeclined() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let server = RollStandInServer()
        let shop = shop(server)
        await shop.refresh()
        let packs = try onSale(shop)

        await shop.buy(packs[0])
        XCTAssertTrue(shop.awaitingApproval)
        XCTAssertEqual(shop.notice?.text, RollShopCopy.pending)
        XCTAssertEqual(server.reported.count, 0)
        let declined = try XCTUnwrap(session.allTransactions().last)
        try session.declineAskToBuyTransaction(identifier: declined.identifier)

        await shop.buy(packs[1])
        XCTAssertEqual(server.reported.count, 0)
        let approved = try XCTUnwrap(session.allTransactions().last { $0.identifier != declined.identifier })
        try session.approveAskToBuyTransaction(identifier: approved.identifier)
        try await eventually("the approved purchase to be credited") { server.credited.count == 1 }
        XCTAssertEqual(server.credited.values.first, 25)
        try await eventually("the shop to show the balance") { shop.balance == 28 }
        XCTAssertFalse(shop.awaitingApproval)
    }

    func testAFailedPurchaseChangesNothing() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let server = RollStandInServer()
        let shop = shop(server)
        await shop.refresh()
        let packs = try onSale(shop)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        await shop.buy(packs[0])
        XCTAssertEqual(shop.notice, RollShop.Notice(kind: .problem, text: RollShopCopy.didNotFinish))
        XCTAssertEqual(server.reported.count, 0)
        XCTAssertEqual(shop.balance, 3)
        try await session.setSimulatedError(nil, forAPI: .purchase)
    }
}

/// The parts of buying StoreKit's test session cannot show: a cancelled purchase, a signed-out buyer, and a purchase the
/// server refuses, which stays unfinished.
@MainActor
final class RollShopTests: XCTestCase {
    private func shop(_ server: RollStandInServer, store: ScriptedRollStore, signedIn: Bool = true) -> RollShop {
        let defaults = UserDefaults(suiteName: "RollShopTests-\(UUID().uuidString)")!
        if signedIn { defaults.set("Maya", forKey: "ImmerseHostDisplayName") }
        let hosting = HostingSession(signIn: RollShopSignIn(session: signedIn), functions: server, defaults: defaults)
        return RollShop(hosting: hosting, functions: server, store: store, subscriptionProductIDs: ["test.immerse.monthly"],
                        supportAddress: "support@immerse.test")
    }

    private let sale = RollShop.OnSale(pack: RollPack(productId: "test.immerse.rolls.small", rolls: 5), price: "$0.01")

    func testACancelledPurchaseChangesNothingAndSaysNothing() async {
        let server = RollStandInServer()
        let store = ScriptedRollStore(result: .cancelled)
        let shop = shop(server, store: store)
        await shop.buy(sale)
        XCTAssertNil(shop.notice)
        XCTAssertEqual(server.reported.count, 0)
    }

    func testASignedOutBuyerIsAskedToSignInAndNothingIsBought() async {
        let server = RollStandInServer()
        let store = ScriptedRollStore(result: .cancelled)
        let shop = shop(server, store: store, signedIn: false)
        await shop.buy(sale)
        XCTAssertEqual(shop.notice?.text, "Sign in to buy Rolls.")
        XCTAssertEqual(store.purchases, 0)
    }

    func testAPurchaseTheServerRefusesStaysUnfinishedAndNamesSupport() async {
        let server = RollStandInServer()
        server.refuseAll = true
        let finished = FinishRecord()
        let store = ScriptedRollStore(result: .purchased(RollTransaction(
            id: 7, productID: sale.pack.productId, signedTransaction: "e30.e30.sig", finish: { finished.mark() })))
        let shop = shop(server, store: store)
        await shop.buy(sale)
        XCTAssertFalse(finished.marked)
        XCTAssertEqual(shop.notice?.kind, .problem)
        XCTAssertTrue(shop.notice?.text.contains("support@immerse.test") == true)
    }

    func testAnActiveSubscriptionIsSentOnceForItsFreeRolls() async {
        let server = RollStandInServer()
        server.subscriberOffered = true
        let store = ScriptedRollStore(result: .cancelled)
        store.subscription = "subscription.jws.sig"
        let shop = shop(server, store: store)
        await shop.refresh()
        XCTAssertEqual(server.links, 1)
        XCTAssertEqual(shop.subscriberRolls, 20)
        XCTAssertEqual(shop.notice?.text, RollShopCopy.subscriberCredited(20))
        await shop.refresh()
        XCTAssertEqual(server.links, 1, "Not sent again once its Rolls are credited")
    }

    func testAnotherAccountSignedInOfflineSeesNothingOfTheFirstAccountsRolls() async {
        let server = RollStandInServer()
        server.subscriberOffered = true
        let store = ScriptedRollStore(result: .cancelled)
        store.subscription = "subscription.jws.sig"
        let defaults = UserDefaults(suiteName: "RollShopTests-\(UUID().uuidString)")!
        defaults.set("Maya", forKey: "ImmerseHostDisplayName")
        let signIn = RollShopSignIn(session: true)
        let hosting = HostingSession(signIn: signIn, functions: server, defaults: defaults)
        let shop = RollShop(hosting: hosting, functions: server, store: store, subscriptionProductIDs: ["test.immerse.monthly"],
                            supportAddress: "support@immerse.test")
        await shop.refresh()
        XCTAssertEqual(shop.balance, 23)
        XCTAssertEqual(shop.subscriberRolls, 20)
        XCTAssertNotNil(shop.notice)

        await hosting.signOut()
        XCTAssertNil(shop.balance, "Nobody is signed in")
        XCTAssertNil(shop.subscriberRolls)
        XCTAssertFalse(shop.subscriberOffered)
        XCTAssertNil(shop.notice)

        // Another Account, with the same display name, signs in while Immerse's server cannot be reached for Rolls.
        signIn.hasSession = true
        server.offline = true
        await hosting.refresh()
        XCTAssertEqual(hosting.phase, .signedIn(displayName: "Maya"))
        await shop.refresh()
        XCTAssertNil(shop.balance)
        XCTAssertEqual(shop.history, [])
        XCTAssertNil(shop.subscriberRolls)
        XCTAssertNil(shop.notice)
        XCTAssertEqual(server.links, 1, "The subscription is not sent for the new Account before its catalog is read")
    }
}

private final class FinishRecord: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    var marked: Bool { lock.withLock { done } }
    func mark() { lock.withLock { done = true } }
}

@MainActor
private final class ScriptedRollStore: RollStore {
    let result: RollStorePurchase
    var purchases = 0
    var subscription: String?
    init(result: RollStorePurchase) { self.result = result }
    func products(for ids: [String]) async throws -> [RollProduct] { ids.map { RollProduct(id: $0, displayPrice: "$0.01") } }
    func purchase(productID: String, appAccountToken: UUID) async throws -> RollStorePurchase {
        purchases += 1
        return result
    }
    func unfinished() async -> [RollTransaction] { [] }
    func updates() -> AsyncStream<RollTransaction> { AsyncStream { _ in } }
    func subscriptionTransaction(productIDs: Set<String>) async -> String? { subscription }
}

@MainActor
private final class RollShopSignIn: HostSignIn {
    var hasSession: Bool
    init(session: Bool) { hasSession = session }
    var sessionIsKnown: Bool { true }
    var suggestedDisplayName: String? { "Maya" }
    func sessionToken() async -> String? { hasSession ? "t" : nil }
    func signInWithApple(identityToken: String, givenName: String?, familyName: String?) async throws {}
    func signInWithGoogle() async throws {}
    func sendEmailCode(to address: String) async throws {}
    func verifyEmailCode(_ code: String) async throws {}
    func signOut() async throws { hasSession = false }
}

/// The server's Roll functions in memory, crediting each reported transaction once by its id, as the server does. It reads
/// the signed transaction's payload without checking its signature, which the server's own tests hold
/// (Backend/tests/purchases.test.ts); StoreKit's local test session signs with a certificate of its own.
final class RollStandInServer: ServerFunctions, @unchecked Sendable {
    static let token = UUID(uuidString: "0F1E2D3C-4B5A-4987-A654-3210FEDCBA98")!
    private let lock = NSLock()
    private var state = (balance: 3, credited: [String: Int](), reported: [String](), tokens: [String](), links: 0,
                         unreachable: false, offline: false, refuseAll: false, subscriberOffered: false, subscriberRolls: Int?.none)

    var balance: Int { lock.withLock { state.balance } }
    var credited: [String: Int] { lock.withLock { state.credited } }
    var reported: [String] { lock.withLock { state.reported } }
    var tokens: [String] { lock.withLock { state.tokens } }
    var links: Int { lock.withLock { state.links } }
    var unreachable: Bool {
        get { lock.withLock { state.unreachable } }
        set { lock.withLock { state.unreachable = newValue } }
    }
    /// Only the Account answers; every Roll function is unreachable.
    var offline: Bool {
        get { lock.withLock { state.offline } }
        set { lock.withLock { state.offline = newValue } }
    }
    var refuseAll: Bool {
        get { lock.withLock { state.refuseAll } }
        set { lock.withLock { state.refuseAll = newValue } }
    }
    var subscriberOffered: Bool {
        get { lock.withLock { state.subscriberOffered } }
        set { lock.withLock { state.subscriberOffered = newValue } }
    }

    private static let packs = ["test.immerse.rolls.small": 5, "test.immerse.rolls.large": 25]

    func call(_ kind: FunctionKind, _ path: String, _ args: [String: JSONValue]) async throws(ServerError) -> JSONValue {
        let result: Result<JSONValue, ServerError> = lock.withLock { Result { () throws(ServerError) -> JSONValue in try answer(path, args) } }
        return try result.get()
    }

    /// Answers one call; the lock is held.
    private func answer(_ path: String, _ args: [String: JSONValue]) throws(ServerError) -> JSONValue {
        if path == "accounts:me" {
            return ["state": "signedIn", "account": ["displayName": "Maya", "ageConfirmedAt": 1, "createdAt": 1]]
        }
        if state.offline { throw .unreachable }
        switch path {
        case "purchases:catalog":
            return ["packs": [["productId": "test.immerse.rolls.small", "rolls": 5], ["productId": "test.immerse.rolls.large", "rolls": 25]],
                    "subscriber": ["offered": .bool(state.subscriberOffered),
                                   "credited": state.subscriberRolls.map { .number(Double($0)) } ?? .null]]
        case "purchases:shoppingToken":
            return ["appAccountToken": .string(Self.token.uuidString.lowercased())]
        case "rolls:balance":
            return ["rolls": .number(Double(state.balance))]
        case "rolls:history":
            return []
        case "appStore:linkSubscription":
            state.links += 1
            state.subscriberRolls = 20
            state.balance += 20
            return ["state": "credited", "rolls": 20, "balance": .number(Double(state.balance))]
        case "appStore:creditPurchase":
            if state.unreachable { throw .unreachable }
            if state.refuseAll { throw .refused(.purchaseRefused) }
            let signed = args["signedTransaction"]?.string ?? ""
            state.reported.append(signed)
            let segments = signed.split(separator: ".")
            guard segments.count == 3, let payload = Self.decode(String(segments[1])),
                  let id = payload["transactionId"] as? String ?? (payload["transactionId"] as? NSNumber)?.stringValue,
                  let product = payload["productId"] as? String, let rolls = Self.packs[product] else {
                throw .refused(.purchaseRefused)
            }
            if let token = payload["appAccountToken"] as? String { state.tokens.append(token.lowercased()) }
            let revoked = payload["revocationDate"] != nil
            if revoked {
                if state.credited.removeValue(forKey: id) != nil { state.balance -= rolls }
                return ["state": "refunded", "rolls": .number(Double(rolls)), "toCaller": true,
                        "balance": .number(Double(state.balance))]
            }
            if state.credited[id] == nil {
                state.credited[id] = rolls
                state.balance += rolls
            }
            return ["state": "credited", "rolls": .number(Double(rolls)), "toCaller": true,
                    "balance": .number(Double(state.balance))]
        default:
            throw .failed("The stand-in has no \(path)")
        }
    }

    private static func decode(_ segment: String) -> [String: Any]? {
        var base64 = segment.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
