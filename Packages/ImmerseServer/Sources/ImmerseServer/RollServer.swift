import Foundation

/// A pack of Rolls on sale (v2 PRD V2-FR-60): its App Store product and how many Rolls it adds. Both come from the
/// server's configuration, never from the app, and its price comes from the App Store (V2-FR-64).
public struct RollPack: Equatable, Sendable, Decodable {
    public let productId: String
    public let rolls: Int

    public init(productId: String, rolls: Int) {
        self.productId = productId
        self.rolls = rolls
    }
}

/// What the signed-in Host can buy, and where they stand with the subscriber's free Rolls (`purchases:catalog`).
public struct RollCatalog: Equatable, Sendable {
    /// The packs on sale. Empty while the server sells none, as before the pricing decision (OC-5).
    public let packs: [RollPack]
    /// Whether the server gives a subscriber's free Rolls at all.
    public let subscriberOffered: Bool
    /// The subscriber Rolls this Account has had, once ever (V2-FR-62), or nil when it has had none.
    public let subscriberRollsCredited: Int?

    public init(packs: [RollPack], subscriberOffered: Bool, subscriberRollsCredited: Int?) {
        self.packs = packs
        self.subscriberOffered = subscriberOffered
        self.subscriberRollsCredited = subscriberRollsCredited
    }
}

/// What the server made of a Roll purchase the app reported (`appStore:creditPurchase`).
public enum PurchaseCredit: Equatable, Sendable {
    /// Its Rolls are in an Account's balance: this one's, or the Account that bought it when that is another.
    case credited(rolls: Int, toThisAccount: Bool)
    /// Apple refunded it, so its Rolls are not in the balance (V2-FR-65).
    case refunded(rolls: Int)
    /// No Account to credit yet; a report while signed in credits it.
    case unassigned
    /// A product of this app that is no Roll pack on sale; the server keeps it and credits it once the packs name it.
    case notOnSale

    /// Whether the app can finish the StoreKit transaction: the server holds the purchase for good.
    public var settled: Bool {
        switch self {
        case .credited, .refunded: true
        case .unassigned, .notOnSale: false
        }
    }
}

/// What the server made of the subscription the app sent (`appStore:linkSubscription`, V2-FR-63).
public enum SubscriberLink: Equatable, Sendable {
    /// Linked to this Account now, and its subscriber Rolls credited once.
    case credited(rolls: Int)
    /// This Account already holds the link, and had its Rolls when it was made.
    case alreadyCredited(rolls: Int)
    /// Another Account holds the subscription's link; it is never named.
    case linkedElsewhere
    /// This Account already had a subscriber's Rolls through another subscription.
    case accountAlreadyCredited
    /// Apple says the subscription is not active now.
    case notActive
}

/// One line of the balance history (V2-FR-28): each set-aside, return, purchase, refund, reversal and free credit.
public struct BalanceEntry: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        case purchase, free, setAside, `return`, refund, refundReversed
    }

    public var id: String { "\(at.timeIntervalSince1970)-\(kind.rawValue)-\(rolls)-\(eventTitle ?? "")" }
    public let kind: Kind
    /// For a free credit: a subscriber's, rather than everyone's.
    public let subscriber: Bool
    /// Rolls added (positive) or taken (negative).
    public let rolls: Int
    public let at: Date
    public let eventTitle: String?

    public init(kind: Kind, subscriber: Bool, rolls: Int, at: Date, eventTitle: String?) {
        self.kind = kind
        self.subscriber = subscriber
        self.rolls = rolls
        self.at = at
        self.eventTitle = eventTitle
    }
}

/// Buying Rolls and the subscriber's free Rolls, on the server (v2 PRD V2-FR-60 to V2-FR-65, section 9.7).
public struct RollServer: Sendable {
    private let functions: any ServerFunctions

    public init(functions: any ServerFunctions) {
        self.functions = functions
    }

    public func catalog() async throws(ServerError) -> RollCatalog {
        let reply = try await functions.call(.query, "purchases:catalog", [:])
        guard case .array(let entries)? = reply["packs"] else { throw .failed("The Rolls on sale could not be read") }
        var packs: [RollPack] = []
        for entry in entries {
            guard let id = entry["productId"]?.string, let rolls = entry["rolls"]?.number else {
                throw .failed("The Rolls on sale could not be read")
            }
            packs.append(RollPack(productId: id, rolls: Int(rolls)))
        }
        let subscriber = reply["subscriber"]
        return RollCatalog(packs: packs, subscriberOffered: subscriber?["offered"]?.bool ?? false,
                           subscriberRollsCredited: subscriber?["credited"]?.number.map { Int($0) })
    }

    /// The token the app sets on a Roll purchase, so Apple's transaction names this Account (section 9.7).
    public func shoppingToken() async throws(ServerError) -> UUID {
        let reply = try await functions.call(.mutation, "purchases:shoppingToken", [:])
        guard let text = reply["appAccountToken"]?.string, let token = UUID(uuidString: text) else {
            throw .failed("The purchase token could not be read")
        }
        return token
    }

    /// Reports a Roll purchase's signed transaction. The server confirms it with Apple and credits it once, however often
    /// it is reported. Returns what it made of it and this Account's balance after it, when signed in.
    public func creditPurchase(signedTransaction: String) async throws(ServerError) -> (credit: PurchaseCredit, balance: Int?) {
        let reply = try await functions.call(.action, "appStore:creditPurchase", ["signedTransaction": .string(signedTransaction)])
        let rolls = reply["rolls"]?.number.map { Int($0) } ?? 0
        let credit: PurchaseCredit
        switch reply["state"]?.string {
        case "credited": credit = .credited(rolls: rolls, toThisAccount: reply["toCaller"]?.bool ?? false)
        case "refunded": credit = .refunded(rolls: rolls)
        case "unassigned": credit = .unassigned
        case "notOnSale": credit = .notOnSale
        default: throw .failed("The purchase's credit could not be read")
        }
        return (credit, reply["balance"]?.number.map { Int($0) })
    }

    /// Sends the v1 subscription's signed transaction, so the server confirms it with Apple and credits this Account its
    /// subscriber Rolls, once ever (V2-FR-63).
    public func linkSubscription(signedTransaction: String) async throws(ServerError) -> (link: SubscriberLink, balance: Int) {
        let reply = try await functions.call(.action, "appStore:linkSubscription", ["signedTransaction": .string(signedTransaction)])
        let rolls = reply["rolls"]?.number.map { Int($0) } ?? 0
        let link: SubscriberLink
        switch reply["state"]?.string {
        case "credited": link = .credited(rolls: rolls)
        case "alreadyCredited": link = .alreadyCredited(rolls: rolls)
        case "linkedElsewhere": link = .linkedElsewhere
        case "accountAlreadyCredited": link = .accountAlreadyCredited
        case "notActive": link = .notActive
        default: throw .failed("The subscription's link could not be read")
        }
        guard let balance = reply["balance"]?.number else { throw .failed("The balance could not be read") }
        return (link, Int(balance))
    }

    /// The balance history, newest first (V2-FR-28).
    public func history() async throws(ServerError) -> [BalanceEntry] {
        guard case .array(let rows) = try await functions.call(.query, "rolls:history", [:]) else {
            throw .failed("The balance history could not be read")
        }
        var entries: [BalanceEntry] = []
        for row in rows {
            guard let kind = row["kind"]?.string.flatMap(BalanceEntry.Kind.init(rawValue:)), let rolls = row["rolls"]?.number,
                  let at = row["at"]?.number else { throw .failed("The balance history could not be read") }
            entries.append(BalanceEntry(kind: kind, subscriber: row["freeGrant"]?.string == "subscriber", rolls: Int(rolls),
                                        at: Date(timeIntervalSince1970: at / 1000), eventTitle: row["eventTitle"]?.string))
        }
        return entries
    }
}
