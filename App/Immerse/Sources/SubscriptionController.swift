import EntitlementCore
import Observation
import StoreKit

@MainActor @Observable
final class SubscriptionController {
    let store: StoreKitSubscriptions
    private(set) var access = SubscriptionAccess.notPurchased
    private(set) var products: [Product] = []
    private(set) var busy = false
    var message: String?
    private var listener: Task<Void, Never>?
    var configured: Bool { store.configuration != nil }

    init(configuration: SubscriptionConfiguration? = SubscriptionController.bundleConfiguration()) {
        store = StoreKitSubscriptions(configuration: configuration)
        let stream = store.updates()
        listener = Task { [weak self] in
            for await access in stream {
                guard !Task.isCancelled, let self else { return }
                self.access = access
            }
        }
    }

    isolated deinit { listener?.cancel() }

    func refresh() async { access = await store.access() }

    func loadProducts() async {
        guard configured else { return }
        busy = true
        defer { busy = false }
        do { products = try await store.products(); message = nil }
        catch { message = "Plans could not load. Try again when connected. Existing Films remain usable." }
        await refresh()
    }

    func purchase(_ product: Product) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            switch try await store.purchase(productID: product.id) {
            case .purchased: await refresh(); message = access == .active ? "Subscription active" : "Purchase is being verified."
            case .pending: message = "Purchase pending approval. Existing Films remain usable."
            case .cancelled: message = "Purchase cancelled."
            }
        } catch { message = "Purchase did not finish. \(error.localizedDescription)" }
    }

    func restore() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            access = try await store.restore()
            message = access == .active ? "Subscription restored" : "No active subscription was found for this Apple ID."
        } catch { message = "Restore did not finish. Your Films are unchanged. \(error.localizedDescription)" }
    }

    static func bundleConfiguration() -> SubscriptionConfiguration? {
        guard let month = Bundle.main.object(forInfoDictionaryKey: "ImmerseMonthlyProductID") as? String,
              let year = Bundle.main.object(forInfoDictionaryKey: "ImmerseYearlyProductID") as? String else { return nil }
        return try? SubscriptionConfiguration(monthlyProductID: month, yearlyProductID: year)
    }
}
