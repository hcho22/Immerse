import Foundation
@testable import ImmerseServer
import XCTest

/// The app's side of buying Rolls (v2 PRD V2-FR-60 to V2-FR-65): what the server's answers mean to the app, and which
/// of them let the app finish a StoreKit transaction.
final class RollServerTests: XCTestCase {
    func testTheCatalogComesFromTheServerWithNoPrice() async throws {
        let functions = FakeFunctions { _, path, _ in
            XCTAssertEqual(path, "purchases:catalog")
            return [
                "packs": [["productId": "test.rolls.small", "rolls": 5], ["productId": "test.rolls.large", "rolls": 25]],
                "subscriber": ["offered": true, "credited": .null],
            ]
        }
        let catalog = try await RollServer(functions: functions).catalog()
        XCTAssertEqual(catalog, RollCatalog(packs: [RollPack(productId: "test.rolls.small", rolls: 5),
                                                   RollPack(productId: "test.rolls.large", rolls: 25)],
                                            subscriberOffered: true, subscriberRollsCredited: nil))
        let none = try await RollServer(functions: FakeFunctions { _, _, _ in
            ["packs": [], "subscriber": ["offered": false, "credited": 20]]
        }).catalog()
        XCTAssertEqual(none, RollCatalog(packs: [], subscriberOffered: false, subscriberRollsCredited: 20))
    }

    func testTheShoppingTokenIsTheServersUUID() async throws {
        let functions = FakeFunctions { kind, path, _ in
            XCTAssertEqual(kind, .mutation)
            XCTAssertEqual(path, "purchases:shoppingToken")
            return ["appAccountToken": "0f1e2d3c-4b5a-4987-a654-3210fedcba98"]
        }
        let token = try await RollServer(functions: functions).shoppingToken()
        XCTAssertEqual(token.uuidString.lowercased(), "0f1e2d3c-4b5a-4987-a654-3210fedcba98")
    }

    func testAPurchaseIsSettledOnlyOnceTheServerHoldsItForGood() async throws {
        let replies: [JSONValue] = [
            ["state": "credited", "rolls": 5, "toCaller": true, "balance": 8],
            ["state": "credited", "rolls": 5, "toCaller": false, "balance": 3],
            ["state": "refunded", "rolls": 5, "toCaller": true, "balance": 3],
            ["state": "unassigned", "balance": .null],
            ["state": "notOnSale", "balance": 3],
        ]
        let expected: [(PurchaseCredit, Int?, Bool)] = [
            (.credited(rolls: 5, toThisAccount: true), 8, true),
            (.credited(rolls: 5, toThisAccount: false), 3, true),
            (.refunded(rolls: 5), 3, true),
            (.unassigned, nil, false),
            (.notOnSale, 3, false),
        ]
        for (reply, (credit, balance, settled)) in zip(replies, expected) {
            let functions = FakeFunctions { kind, path, args in
                XCTAssertEqual(kind, .action)
                XCTAssertEqual(path, "appStore:creditPurchase")
                XCTAssertEqual(args["signedTransaction"], "header.payload.signature")
                return reply
            }
            let answer = try await RollServer(functions: functions).creditPurchase(signedTransaction: "header.payload.signature")
            XCTAssertEqual(answer.credit, credit)
            XCTAssertEqual(answer.balance, balance)
            XCTAssertEqual(answer.credit.settled, settled)
        }
    }

    func testRefusalsAreNamed() async {
        for code in ["purchasesUnavailable", "purchaseRefused", "storeUnavailable", "subscriberRollsNotOffered"] {
            XCTAssertNotEqual(RefusalCode(code), .other(code))
        }
        let functions = FakeFunctions { _, _, _ throws(ServerError) in throw .refused(.storeUnavailable) }
        do {
            _ = try await RollServer(functions: functions).creditPurchase(signedTransaction: "x")
            XCTFail("Expected a refusal")
        } catch {
            XCTAssertEqual(error, .refused(.storeUnavailable))
        }
    }

    func testTheSubscriberLinkAndTheHistoryDecode() async throws {
        let states: [(JSONValue, SubscriberLink)] = [
            (["state": "credited", "rolls": 20, "balance": 23], .credited(rolls: 20)),
            (["state": "alreadyCredited", "rolls": 20, "balance": 23], .alreadyCredited(rolls: 20)),
            (["state": "linkedElsewhere", "balance": 3], .linkedElsewhere),
            (["state": "accountAlreadyCredited", "balance": 3], .accountAlreadyCredited),
            (["state": "notActive", "balance": 3], .notActive),
        ]
        for (reply, link) in states {
            let answer = try await RollServer(functions: FakeFunctions { _, path, _ in
                XCTAssertEqual(path, "appStore:linkSubscription")
                return reply
            }).linkSubscription(signedTransaction: "jws")
            XCTAssertEqual(answer.link, link)
        }
        let history = try await RollServer(functions: FakeFunctions { _, _, _ in
            [
                ["kind": "free", "freeGrant": "subscriber", "rolls": 20, "at": 2_000],
                ["kind": "setAside", "rolls": -3, "at": 1_000, "eventTitle": "Ana & Leo"],
                ["kind": "refundReversed", "rolls": 5, "at": 500],
            ]
        }).history()
        XCTAssertEqual(history, [
            BalanceEntry(kind: .free, subscriber: true, rolls: 20, at: Date(timeIntervalSince1970: 2), eventTitle: nil),
            BalanceEntry(kind: .setAside, subscriber: false, rolls: -3, at: Date(timeIntervalSince1970: 1), eventTitle: "Ana & Leo"),
            BalanceEntry(kind: .refundReversed, subscriber: false, rolls: 5, at: Date(timeIntervalSince1970: 0.5), eventTitle: nil),
        ])
    }
}
