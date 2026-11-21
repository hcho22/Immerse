import EntitlementCore
import FilmDomain
import StoreKit
import SwiftUI

/// The Subscription (A05): the five Cameras on a small dial, All Cameras, the plans as circles with the yearly one in
/// cream, Restore Purchases, and what happens to Films after expiry.
struct SubscriptionView: View {
    @Environment(JournalModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                #if DEBUG
                if model.testingUnlock.enabled {
                    OrbitNote(kind: .custom("hammer", outlined: false)) { TestingUnlockNotice() }
                }
                #endif
                CameraOrbit().padding(.top, 8)
                Text("All Cameras").orbitFont(.display).multilineTextAlignment(.center).padding(.top, 6)
                    .accessibilityAddTraits(.isHeader)
                Text("Unlimited new personal Films. Monthly or yearly, one all-inclusive subscription.")
                    .orbitFont(.body).foregroundStyle(Orbit.body).multilineTextAlignment(.center).frame(maxWidth: 320)
                status
                if model.billing.configured {
                    plans
                    Button { Task { await model.billing.restore() } } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                            .labelStyle(SubscriptionLabelStyle())
                    }
                    .buttonStyle(OrbitPillStyle())
                    .disabled(model.billing.busy)
                } else {
                    Text("Subscriptions are not available in this build.").orbitFont(.body).foregroundStyle(Orbit.body)
                        .multilineTextAlignment(.center)
                }
                if model.billing.busy { ProgressView().tint(.white) }
                if let message = model.billing.message {
                    Text(message).orbitFont(.body).foregroundStyle(Orbit.body).multilineTextAlignment(.center)
                }
                Text("Existing Films remain capture-completable, developable, editable, viewable and exportable after expiration. Deleting Films or the app does not cancel a subscription.")
                    .orbitFont(.footnote).foregroundStyle(Orbit.label).multilineTextAlignment(.center).padding(.top, 20)
                Link("Manage Apple Subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(.orbit(size: 14, weight: .bold, relativeTo: .callout)).underline().foregroundStyle(.white)
                    .frame(minHeight: 44)
            }
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Orbit.gutter).padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .orbitSheetGround(screen: true)
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Subscription").orbitFont(.label).foregroundStyle(Orbit.label).accessibilityHidden(true)
            }
        }
        .task { await model.billing.loadProducts() }
    }

    @ViewBuilder private var status: some View {
        if model.billing.access == .active {
            chip("Subscription active", symbol: "checkmark.circle")
        } else if model.billing.access == .expired {
            Text("Subscription expired. Your existing Films remain usable.").orbitFont(.body).foregroundStyle(Orbit.body)
                .multilineTextAlignment(.center)
        } else if case .consumed = model.trialState {
            chip("This iPhone's Trial is used", symbol: "ticket")
        }
    }

    private func chip(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .labelStyle(SubscriptionLabelStyle())
            .font(.orbit(size: 13, weight: .semibold, relativeTo: .footnote)).foregroundStyle(Orbit.body)
            .padding(.horizontal, 14).frame(minHeight: 32)
            .background(Orbit.surface, in: Capsule())
    }

    @ViewBuilder private var plans: some View {
        let products = model.billing.products
        if products.isEmpty {
            Button { Task { await model.billing.loadProducts() } } label: {
                Label("Reload Plans", systemImage: "arrow.clockwise").labelStyle(SubscriptionLabelStyle())
            }
            .buttonStyle(OrbitPillStyle())
            .disabled(model.billing.busy)
        } else {
            HStack(spacing: 14) {
                ForEach(products) { product in
                    let yearly = product.subscription?.subscriptionPeriod.unit == .year
                    Button { Task { await model.billing.purchase(product) } } label: {
                        VStack(spacing: 4) {
                            Text(yearly ? "Yearly" : "Monthly").orbitFont(.label)
                                .foregroundStyle(yearly ? Color.black : Orbit.label)
                            Text(product.displayPrice).orbitFont(.heading, weight: .extraBold)
                        }
                    }
                    .buttonStyle(PlanStyle(yearly: yearly))
                    .disabled(model.billing.busy)
                    .accessibilityLabel("\(yearly ? "Yearly" : "Monthly"), \(product.displayPrice)")
                }
            }
            .padding(.top, 4)
        }
    }
}

/// The five Cameras on a small orbit (A05).
private struct CameraOrbit: View {
    var body: some View {
        ZStack {
            OrbitDashedRing(lineWidth: 1, dash: [2, 6], color: Orbit.hairline).frame(width: 156, height: 156)
            ForEach(Array(CameraCatalog.all.enumerated()), id: \.offset) { index, camera in
                let angle = Double(index) / Double(CameraCatalog.all.count) * 2 * .pi
                camera.shortNameText.font(.orbit(size: camera.shortName.count > 8 ? 10 : 11, weight: .bold, relativeTo: .caption2))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(width: 62, height: 62)
                    .background(Orbit.button, in: Circle())
                    .offset(x: 78 * sin(angle), y: -78 * cos(angle))
            }
        }
        .frame(width: 230, height: 200)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityHidden(true)
    }
}

/// A plan as a 160-point circle (A05): the monthly one grey with a hairline, the yearly one cream.
private struct PlanStyle: ButtonStyle {
    let yearly: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(yearly ? Color.black : Color.white)
            .multilineTextAlignment(.center)
            .modifier(CircleFit(minimum: 160))
            .background {
                if yearly { Circle().fill(!isEnabled ? Orbit.creamDisabled : configuration.isPressed ? Orbit.creamPressed : Orbit.cream) }
                else { Circle().fill(configuration.isPressed ? Orbit.pressed : Orbit.surface).overlay(Circle().strokeBorder(Orbit.hairline)) }
            }
            .contentShape(Circle())
    }
}

private struct SubscriptionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) { configuration.icon.accessibilityHidden(true); configuration.title }
    }
}
