#if DEBUG
import Foundation
import ImmerseServer
import Synchronization

/// Debug builds only: a stand-in for StoreKit and the server's Roll functions, for screen tests of the Rolls sheet with
/// no App Store and no Convex deployment. `-ImmerseDebugRollStore` takes `onSale` (two synthetic packs whose purchases
/// complete), `pending` (each purchase waits for Ask to Buy and is approved two seconds later), `fail` (each purchase
/// fails) or `notOnSale` (nothing on sale). It needs `-ImmerseDebugHosting` and `-ImmerseDebugGroupFilm`, whose
/// stand-in holds the balance. The server's own tests hold the rules (Backend/tests/purchases.test.ts), and the real
/// StoreKit path is held by `RollShopStoreKitTests`. `Scripts/verify-release-excludes-testing-unlock.sh` holds it out of
/// Release.
@MainActor
final class DebugRollStore: RollStore {
    /// Synthetic test packs and prices, not proposed ones (OC-5).
    nonisolated static let packs: [(id: String, rolls: Int, price: String)] = [
        ("debug.rolls.small", 5, "$0.01"),
        ("debug.rolls.large", 25, "$0.02"),
    ]

    private let scenario: String
    private var next: UInt64 = 1
    private var continuation: AsyncStream<RollTransaction>.Continuation?
    private let stream: AsyncStream<RollTransaction>

    static func make(hosting: HostingSession, arguments: [String]) -> DebugRollStore? {
        guard let index = arguments.firstIndex(of: "-ImmerseDebugRollStore"), index + 1 < arguments.count,
              let server = hosting.functions as? DebugHostingServer else { return nil }
        let scenario = arguments[index + 1]
        server.rolls = DebugRollBackend(onSale: scenario != "notOnSale", events: { server.events })
        return DebugRollStore(scenario: scenario)
    }

    init(scenario: String) {
        self.scenario = scenario
        var continuation: AsyncStream<RollTransaction>.Continuation?
        stream = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func products(for ids: [String]) async throws -> [RollProduct] {
        Self.packs.filter { ids.contains($0.id) }.map { RollProduct(id: $0.id, displayPrice: $0.price) }
    }

    func purchase(productID: String, appAccountToken: UUID) async throws -> RollStorePurchase {
        let transaction = RollTransaction(id: next, productID: productID,
                                          signedTransaction: "debug:\(productID):\(appAccountToken.uuidString):\(next)", finish: {})
        next += 1
        switch scenario {
        case "fail":
            throw URLError(.networkConnectionLost)
        case "pending":
            Task { [continuation] in
                try? await Task.sleep(for: .seconds(2))
                continuation?.yield(transaction)
            }
            return .pending
        default:
            return .purchased(transaction)
        }
    }

    func unfinished() async -> [RollTransaction] { [] }
    func updates() -> AsyncStream<RollTransaction> { stream }
    func subscriptionTransaction(productIDs: Set<String>) async -> String? { nil }
}

/// The server's Roll functions held in memory (Debug only): what is on sale, a purchase credited once by its id, and the
/// history.
final class DebugRollBackend: Sendable {
    private let onSale: Bool
    private let events: @Sendable () -> DebugEventBackend?
    private let state = Mutex<(credited: Set<String>, history: [JSONValue])>(([], []))

    init(onSale: Bool, events: @escaping @Sendable () -> DebugEventBackend?) {
        self.onSale = onSale
        self.events = events
        let at = (Date.now.timeIntervalSince1970 * 1000).rounded() - 86_400_000
        state.withLock { $0.history = [["kind": "free", "freeGrant": "everyone", "rolls": 3, "at": .number(at)]] }
    }

    /// Answers a Roll function, or nil when the path is not one.
    func call(_ path: String, _ args: [String: JSONValue], signedIn: Bool) throws(ServerError) -> JSONValue? {
        switch path {
        case "purchases:catalog":
            guard signedIn else { throw .refused(.unauthenticated) }
            let packs: [JSONValue] = onSale
                ? DebugRollStore.packs.map { ["productId": .string($0.id), "rolls": .number(Double($0.rolls))] } : []
            return ["packs": .array(packs), "subscriber": ["offered": false, "credited": .null]]
        case "purchases:shoppingToken":
            guard signedIn else { throw .refused(.unauthenticated) }
            return ["appAccountToken": "00000000-0000-4000-8000-000000000001"]
        case "appStore:creditPurchase":
            let parts = (args["signedTransaction"]?.string ?? "").split(separator: ":").map(String.init)
            guard parts.count == 4, let pack = DebugRollStore.packs.first(where: { $0.id == parts[1] }) else {
                throw .refused(.purchaseRefused)
            }
            let id = parts[3]
            let first = state.withLock { state in
                guard state.credited.insert(id).inserted else { return false }
                state.history.insert(["kind": "purchase", "rolls": .number(Double(pack.rolls)),
                                      "at": .number((Date.now.timeIntervalSince1970 * 1000).rounded())], at: 0)
                return true
            }
            if first { events()?.credit(pack.rolls) }
            return ["state": "credited", "rolls": .number(Double(pack.rolls)), "toCaller": true,
                    "balance": .number(Double(events()?.balance ?? 0))]
        case "appStore:linkSubscription":
            return ["state": "notActive", "balance": .number(Double(events()?.balance ?? 0))]
        case "rolls:history":
            return .array(state.withLock { $0.history })
        default:
            return nil
        }
    }
}
#endif
