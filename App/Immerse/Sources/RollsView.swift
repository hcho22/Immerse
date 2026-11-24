import ImmerseServer
import SwiftUI

/// The Rolls sheet (v2 PRD V2-FR-60 to V2-FR-65): the balance, the packs on sale with the App Store's price, a purchase
/// waiting for approval, and the balance history. Reached from Load Film, the Host's event page and Settings; a
/// signed-out person is asked to sign in first (`GroupFilmGate`).
struct RollsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GroupFilmGate(title: "Rolls") { RollsView() }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") { dismiss() }
                            .buttonStyle(OrbitCircleButtonStyle(selected: true))
                            .accessibilityIdentifier("rolls-done")
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        }
        .orbitSheet(screen: true)
    }
}

/// A "Buy Rolls" button that raises the Rolls sheet, where the app sells Rolls.
struct BuyRollsButton: View {
    @Environment(\.rollShop) private var rollShop
    @State private var showing = false

    var body: some View {
        if rollShop != nil {
            Button("Buy Rolls") { showing = true }
                .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44, fullWidth: true))
                .accessibilityIdentifier("buy-rolls")
                .sheet(isPresented: $showing) { RollsSheet() }
        }
    }
}

struct RollsView: View {
    @Environment(\.rollShop) private var rollShop

    var body: some View {
        ScrollView {
            if let shop = rollShop {
                VStack(alignment: .leading, spacing: 20) {
                    balance(shop)
                    if let rolls = shop.subscriberRolls {
                        OrbitNote(.info, RollShopCopy.subscriberCredited(rolls), identifier: "rolls-subscriber")
                    }
                    OrbitSectionLabel("Buy Rolls").padding(.leading, 4)
                    shelf(shop)
                    if shop.awaitingApproval {
                        OrbitNote(.info, RollShopCopy.pending, identifier: "rolls-pending")
                    }
                    if let notice = shop.notice, notice.text != RollShopCopy.pending || !shop.awaitingApproval {
                        OrbitNote(Self.kind(of: notice), notice.text, identifier: "rolls-notice")
                    }
                    Text("One Roll is one guest's set of exposures. Each event takes Rolls from your balance, and a Roll is used only when a guest takes it.")
                        .orbitFont(.footnote).foregroundStyle(Orbit.label).fixedSize(horizontal: false, vertical: true)
                    if !shop.history.isEmpty {
                        OrbitSectionLabel("History").padding(.leading, 4)
                        VStack(spacing: 8) {
                            ForEach(shop.history) { entry in historyRow(entry) }
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Orbit.gutter).padding(.vertical, 16)
                .disabled(shop.buying)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .orbitSheetGround(screen: true)
        .task { await rollShop?.refresh() }
        .refreshable { await rollShop?.refresh() }
    }

    private static func kind(of notice: RollShop.Notice) -> OrbitNote<Text>.Kind {
        switch notice.kind {
        case .done: .custom("checkmark.circle", outlined: false)
        case .info: .info
        case .problem: .error
        }
    }

    private func balance(_ shop: RollShop) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(shop.balance.map { "\($0)" } ?? "–").orbitFont(.numeral)
                .accessibilityLabel(shop.balance.map { "\($0) \($0 == 1 ? "Roll" : "Rolls") in your balance" } ?? "Balance loading")
                .accessibilityIdentifier("rolls-balance")
            Text("\(shop.balance == 1 ? "Roll" : "Rolls") in your balance").orbitFont(.headline)
                .accessibilityHidden(true)
            Text(RollShopCopy.keeping).orbitFont(.footnote).foregroundStyle(Orbit.label)
                .fixedSize(horizontal: false, vertical: true)
            if let balance = shop.balance, balance < 0 {
                OrbitNote(.error, RollShopCopy.belowZero, identifier: "rolls-below-zero").padding(.top, 6)
            }
        }
    }

    @ViewBuilder private func shelf(_ shop: RollShop) -> some View {
        switch shop.shelf {
        case .loading:
            ProgressView().frame(maxWidth: .infinity)
        case .notOnSale:
            OrbitNote(.info, RollShopCopy.notOnSale, identifier: "rolls-not-on-sale")
        case .couldNotLoad:
            OrbitNote(.error, RollShopCopy.couldNotLoad, identifier: "rolls-could-not-load")
        case .onSale(let packs):
            VStack(spacing: 10) {
                ForEach(packs) { sale in
                    Button { Task { await shop.buy(sale) } } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(sale.pack.rolls) \(sale.pack.rolls == 1 ? "Roll" : "Rolls")").orbitFont(.headline)
                                Text(sale.pack.rolls == 1 ? "For one guest" : "For \(sale.pack.rolls) guests")
                                    .orbitFont(.footnote).foregroundStyle(Orbit.label)
                            }
                            Spacer(minLength: 12)
                            Text(sale.price).orbitFont(.headline)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .orbitRow()
                    .accessibilityLabel("Buy \(sale.pack.rolls) \(sale.pack.rolls == 1 ? "Roll" : "Rolls") for \(sale.price)")
                    .accessibilityIdentifier("rolls-pack-\(sale.pack.productId)")
                }
                if shop.buying { ProgressView().frame(maxWidth: .infinity) }
            }
        }
    }

    private func historyRow(_ entry: BalanceEntry) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(RollShopCopy.history(entry)).orbitFont(.body, weight: .semibold)
                Text(GroupFilmsCopy.time(entry.at)).orbitFont(.footnote).foregroundStyle(Orbit.label)
            }
            Spacer(minLength: 12)
            Text(entry.rolls > 0 ? "+\(entry.rolls)" : "\(entry.rolls)").orbitFont(.headline).monospacedDigit()
        }
        .orbitRow()
        .accessibilityElement(children: .combine)
    }
}
