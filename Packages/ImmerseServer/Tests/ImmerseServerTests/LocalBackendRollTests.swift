import Foundation
import ImmerseServer
import XCTest

/// The iPhone's own client buying Rolls on Convex's local backend, with Apple's side stood in for: the catalog, the
/// purchase token, a Roll purchase's signed transaction reported twice and credited once, and the subscription linked for
/// its free Rolls. The backend's end-to-end run (`Backend/local-backend/stage4.test.ts`) makes the signed transactions
/// and runs this with them; on its own, with none given, it is skipped.
final class LocalBackendRollTests: XCTestCase {
    func testThePhonesClientBuysRollsAndLinksTheSubscription() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["IMMERSE_LOCAL_CONVEX_URL"].flatMap(URL.init(string:)),
              let session = environment["IMMERSE_LOCAL_SESSION_TOKEN"],
              let expectedToken = environment["IMMERSE_LOCAL_APP_ACCOUNT_TOKEN"],
              let purchase = environment["IMMERSE_LOCAL_SIGNED_PURCHASE"],
              let subscription = environment["IMMERSE_LOCAL_SIGNED_SUBSCRIPTION"]
        else { throw XCTSkip("Run by Backend/local-backend/stage4.test.ts, which starts the local stand-ins") }
        let functions = ConvexHTTPClient(deploymentURL: url) { session }
        let rolls = RollServer(functions: functions)

        let catalog = try await rolls.catalog()
        XCTAssertEqual(catalog.packs.map(\.rolls), [5, 25])
        XCTAssertTrue(catalog.subscriberOffered)
        XCTAssertNil(catalog.subscriberRollsCredited)
        let token = try await rolls.shoppingToken()
        XCTAssertEqual(token.uuidString.lowercased(), expectedToken)

        let before = try await EventServer(functions: functions).balance()
        let first = try await rolls.creditPurchase(signedTransaction: purchase)
        XCTAssertEqual(first.credit, .credited(rolls: 5, toThisAccount: true))
        XCTAssertEqual(first.balance, before + 5)
        // Reported again, as after a reply the app never received: once.
        let again = try await rolls.creditPurchase(signedTransaction: purchase)
        XCTAssertEqual(again.balance, before + 5)

        let link = try await rolls.linkSubscription(signedTransaction: subscription)
        XCTAssertEqual(link.link, .credited(rolls: 20))
        XCTAssertEqual(link.balance, before + 25)
        let history = try await rolls.history()
        XCTAssertEqual(history.map(\.kind).prefix(2).sorted { $0.rawValue < $1.rawValue }, [.free, .purchase])
        XCTAssertTrue(history.contains { $0.kind == .free && $0.subscriber && $0.rolls == 20 })

        // A refused transaction is named as such, so the app can finish it.
        do {
            _ = try await rolls.creditPurchase(signedTransaction: "not.a.jws")
            XCTFail("A malformed transaction was accepted")
        } catch {
            XCTAssertEqual(error, .refused(.purchaseRefused))
        }
    }
}
