import EntitlementCore
import SwiftUI

struct SubscriptionView: View {
    @Environment(JournalModel.self) private var model

    var body: some View {
        Form {
            Section {
                Text("All Cameras").font(.system(.title2, design: .serif))
                Text("Unlimited new personal Films. Monthly or yearly, one all-inclusive subscription.")
                if model.billing.access == .active {
                    Label("Subscription active", systemImage: "checkmark.circle")
                } else if model.billing.access == .expired {
                    Text("Subscription expired. Your existing Films remain usable.")
                }
            }
            if model.billing.configured {
                Section("Plans") {
                    ForEach(model.billing.products) { product in
                        Button {
                            Task { await model.billing.purchase(product) }
                        } label: {
                            HStack {
                                Text(product.subscription?.subscriptionPeriod.unit == .year ? "Yearly" : "Monthly")
                                Spacer()
                                Text(product.displayPrice)
                            }
                        }.disabled(model.billing.busy)
                    }
                    if model.billing.products.isEmpty {
                        Button("Reload Plans", systemImage: "arrow.clockwise") { Task { await model.billing.loadProducts() } }
                            .disabled(model.billing.busy)
                    }
                }
                Section {
                    Button("Restore Purchases", systemImage: "arrow.clockwise") { Task { await model.billing.restore() } }
                        .disabled(model.billing.busy)
                }
            } else {
                Section { Text("Subscriptions are not available in this build.") }
            }
            if model.billing.busy { ProgressView() }
            if let message = model.billing.message { Section { Text(message) } }
            Section {
                Text("Existing Films remain capture-completable, developable, editable, viewable and exportable after expiration. Deleting Films or the app does not cancel a subscription.")
                Link("Manage Apple Subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
            }
        }
        .navigationTitle("Subscription")
        .task { await model.billing.loadProducts() }
    }
}
