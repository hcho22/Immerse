import EntitlementCore
import FilmDomain
import FilmPersistence
import NativeAdapters
import StoreKit
import StoreKitTest
import XCTest
@testable import Immerse

@MainActor
final class StoreKitSubscriptionTests: XCTestCase {
    private let month = "test.immerse.monthly"
    private let year = "test.immerse.yearly"

    private func session() async throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "LocalSubscriptions", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        let products = try await Product.products(for: [month, year])
        guard Set(products.map(\.id)) == Set([month, year]),
              products.allSatisfy({ $0.displayName.hasPrefix("Test ") }) else {
            throw NSError(domain: "ImmerseStoreKitTestIsolation", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Local StoreKit fixture is not active. No purchase, restore or entitlement API may run."])
        }
        return session
    }

    private func configuration() throws -> SubscriptionConfiguration {
        try SubscriptionConfiguration(monthlyProductID: month, yearlyProductID: year)
    }

    private func store() throws -> StoreKitSubscriptions {
        StoreKitSubscriptions(configuration: try configuration())
    }

    /// The production Journal billed through this fixture, with in-memory Trial receipts and a granted camera.
    private func journal() async throws -> (URL, JournalModel) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StoreKitJournal-\(UUID())")
        let model = try JournalModel(root: root, trialStore: KeychainDeviceTrialStore(calls: HeldReceiptCalls()),
                                     cameraAuthorizer: SyntheticCamera(granted: true), subscriptions: try configuration())
        await model.recoverAtLaunch()
        return (root, model)
    }

    /// Saves one photo into an existing Film through the production capture commit.
    private func saveCapture(into film: Film, _ model: JournalModel) async throws {
        let staging = try model.repository.captureStagingDirectory(filmID: film.id)
        _ = try CapturedMediaFiles(directory: staging).savePhoto(syntheticPhoto(), id: UUID())
        try await model.recoverCapture(film.id)
    }

    func testRealLocalPurchaseReopenRestoreAndExpirationPreserveExistingFilm() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let (root, model) = try await journal()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try store()
        let products = try await store.products()
        XCTAssertEqual(products.map(\.id), [month, year])
        XCTAssertEqual(products[0].displayPrice, "$0.01")
        let initial = await store.access()
        XCTAssertEqual(initial, .notPurchased)
        let outcome = try await store.purchase(productID: month)
        XCTAssertEqual(outcome, .purchased)
        let reopened = try self.store()
        let cached = await reopened.access()
        XCTAssertEqual(cached, .active)
        let restored = try await reopened.restore()
        XCTAssertEqual(restored, .active)
        let paid = try await model.load(camera: CameraCatalog.disposable1990s, title: "Synthetic paid roll", orientation: .portrait)
        XCTAssertEqual(model.billing.access, .active)
        XCTAssertEqual(try model.repository.filmAccess(filmID: paid.id), .subscription)
        let untouched = try await model.trial.state()
        XCTAssertEqual(untouched, .unused)
        let expiryDelivered = expectation(description: "StoreKit delivers verified fixture expiry")
        let expiryListener = Task {
            for await result in Transaction.updates {
                if case let .verified(transaction) = result, transaction.productID == month,
                   let date = transaction.expirationDate, date <= Date() {
                    expiryDelivered.fulfill()
                    return
                }
            }
        }
        defer { expiryListener.cancel() }
        await Task.yield()
        try session.expireSubscription(productIdentifier: month)
        let fixture = try XCTUnwrap(session.allTransactions().first)
        XCTAssertEqual(fixture.productIdentifier, month)
        XCTAssertFalse(fixture.autoRenewingEnabled)
        XCTAssertLessThanOrEqual(try XCTUnwrap(fixture.expirationDate), Date())
        // StoreKitTest mutates its fixture before StoreKit delivers the new signed
        // transaction. Assert that delivery, then exercise the production paths.
        await fulfillment(of: [expiryDelivered], timeout: 10)
        let expired = await reopened.access()
        XCTAssertEqual(expired, .expired)
        await model.billing.refresh()
        XCTAssertEqual(model.billing.access, .expired)
        try await saveCapture(into: paid, model)
        XCTAssertEqual(model.film(paid.id)?.savedCaptureCount, 1, "Expiry keeps the existing Film's rights")
        // PRD section 18 open question 7 is pending the captain. Under the provisional default,
        // production gives this lapsed subscriber, who never used the Trial, the Trial Film.
        let lapsed = try await model.load(camera: CameraCatalog.instant1970s, title: "Synthetic lapsed pack", orientation: .portrait)
        guard case .trial = try model.repository.filmAccess(filmID: lapsed.id) else {
            return XCTFail("The provisional default loads the lapsed subscriber's Film on the unused Trial")
        }
        let started = try await model.trial.state()
        XCTAssertEqual(started, .emptyFilmInProgress(filmID: lapsed.id))
    }

    func testPendingApprovalAndTransactionUpdate() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let store = try store()
        let updates = store.updates()
        let received = expectation(description: "verified entitlement update")
        let listener = Task {
            for await access in updates where access == .active { received.fulfill(); return }
        }
        defer { listener.cancel() }
        let outcome = try await store.purchase(productID: year)
        XCTAssertEqual(outcome, .pending)
        let waiting = await store.access()
        XCTAssertEqual(waiting, .notPurchased)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        await fulfillment(of: [received], timeout: 10)
        let approved = await store.access()
        XCTAssertEqual(approved, .active)
    }

    func testProductFailureRestoreFailureAndUnconfiguredDoNotGrantAccess() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let store = try store()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        do { _ = try await store.products(); XCTFail("Product failure must surface") } catch {}
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        do { _ = try await store.restore(); XCTFail("Restore failure must surface") } catch {}
        let access = await store.access()
        XCTAssertEqual(access, .notPurchased)
        let unavailable = StoreKitSubscriptions(configuration: nil)
        do { _ = try await unavailable.purchase(productID: month); XCTFail("Unconfigured must not purchase") }
        catch { XCTAssertEqual(error as? SubscriptionStoreError, .unavailable) }
    }

    func testRefundRemovesCurrentAppleEntitlementWithoutRemovingFilmRights() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let (root, model) = try await journal()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try store()
        _ = try await store.purchase(productID: month)
        let paid = try await model.load(camera: CameraCatalog.mediumFormat6x6, title: "Synthetic paid roll", orientation: .portrait)
        XCTAssertEqual(try model.repository.filmAccess(filmID: paid.id), .subscription)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        let revocationDelivered = expectation(description: "StoreKit delivers verified fixture revocation")
        let revocationListener = Task {
            for await result in Transaction.updates {
                if case let .verified(delivered) = result, delivered.productID == month,
                   delivered.id == UInt64(transaction.identifier), delivered.revocationDate != nil {
                    revocationDelivered.fulfill()
                    return
                }
            }
        }
        defer { revocationListener.cancel() }
        await Task.yield()
        try session.refundTransaction(identifier: transaction.identifier)
        XCTAssertNotNil(try XCTUnwrap(session.allTransactions().first).cancelDate)
        await fulfillment(of: [revocationDelivered], timeout: 10)
        let access = await store.access()
        XCTAssertNotEqual(access, .active)
        await model.billing.refresh()
        XCTAssertEqual(model.billing.access, access)
        // This asserts Apple's revocation is not a new paid grant. Product policy
        // about refunds remains DEC-02; existing Film rights are never destroyed.
        try await saveCapture(into: paid, model)
        XCTAssertEqual(model.film(paid.id)?.savedCaptureCount, 1)
    }
}
