#if DEBUG
import EntitlementCore
import Foundation
import Observation
import SwiftUI

/// Debug-only manual testing unlock: while enabled, Load Film treats the subscription as active,
/// so every Camera loads a subscription Film and this iPhone's Trial record is never read for
/// eligibility or written. StoreKit verification and `SubscriptionController.access` are unchanged.
/// The whole type is compiled out of Release, which therefore has no unlock path or copy;
/// `Scripts/verify-release-excludes-testing-unlock.sh` checks the Release binary.
@MainActor @Observable
final class TestingUnlock {
    static let defaultsKey = "ImmerseDebugTestingUnlock"
    static let label = "Testing unlock - Debug build"

    private let defaults: UserDefaults?

    var enabled: Bool {
        didSet { defaults?.set(enabled, forKey: Self.defaultsKey) }
    }

    /// Reads the persisted switch, which starts on in a Debug build. Without defaults the
    /// switch is in memory only and starts off, as directly constructed Journals in tests expect.
    init(defaults: UserDefaults?) {
        self.defaults = defaults
        // `bool(forKey:)` also reads a `-ImmerseDebugTestingUnlock NO` launch argument, as UI tests pass.
        enabled = defaults.map { $0.object(forKey: Self.defaultsKey) == nil || $0.bool(forKey: Self.defaultsKey) } ?? false
    }

    /// What loading a Film uses: the verified StoreKit access, or an active subscription while unlocked.
    func loadAccess(_ verified: SubscriptionAccess) -> SubscriptionAccess {
        enabled ? .active : verified
    }
}

/// Shown on the load and plan screens while the unlock is on, so testing and screenshots are
/// never mistaken for a real subscription.
struct TestingUnlockNotice: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(TestingUnlock.label)
                Text("Every Camera loads without a subscription or this iPhone's Trial. Turn off Testing unlock in Settings to test the Trial and plans.")
                    .font(.footnote).fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: "hammer")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("testing-unlock-notice")
    }
}

/// The Debug-only switch in Settings.
struct TestingUnlockSection: View {
    @Bindable var unlock: TestingUnlock

    var body: some View {
        Section {
            Toggle(TestingUnlock.label, isOn: $unlock.enabled)
                .accessibilityIdentifier("testing-unlock-switch")
        } header: {
            Text("Debug testing")
        } footer: {
            Text("Debug builds only. While on, every Camera loads as a subscription Film and this iPhone's Trial is not used. Turn off to test the Trial, locked and plan screens. Films loaded while on stay usable.")
        }
    }
}
#endif
