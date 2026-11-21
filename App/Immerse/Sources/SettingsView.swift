import NativeAdapters
import SwiftUI

/// Settings (A04): Privacy as three circles with the app's privacy paragraph and the way to iPhone Settings, then the
/// Films rows, Trial, Subscription, Storage and backup and Saving to Photos, each opening in place to its full words.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(JournalModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    #if DEBUG
                    OrbitSectionLabel("Debug testing").padding(.leading, 4).padding(.top, 8)
                    TestingUnlockSection(unlock: model.testingUnlock)
                    DevelopedPreviewSection(previews: model.developedPreviews)
                    #endif
                    OrbitSectionLabel("Privacy").padding(.leading, 4).padding(.top, 8)
                    privacy
                    OrbitSectionLabel("Films").padding(.leading, 4).padding(.top, 8)
                    SettingsDetailRow(title: "Trial", summary: "One complete Film per iPhone") {
                        if let error = model.trialError { Text("Trial status unavailable: \(error)").foregroundStyle(.white) }
                        Text("One complete Film per iPhone, with any Camera. The first successfully saved capture consumes it. Deleting a used Film or the app does not restore the Trial.")
                        Text("The Trial record stays on this iPhone. Films restored to another iPhone keep their remaining capture rights and do not use that iPhone's Trial.")
                    }
                    NavigationLink { SubscriptionView() } label: {
                        HStack {
                            Text("Subscription").orbitFont(.body, weight: .semibold).foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Orbit.label)
                        }
                        .orbitRow()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    SettingsDetailRow(title: "Storage and backup", summary: "iOS device backups") { Text(PrivacyCopy.backup) }
                    SettingsDetailRow(title: "Saving to Photos", summary: "Only what you choose") {
                        Text("Exports are optional. Photos receives only the revealed media you choose. A developed export is a flattened result, not a restorable Film or edit history.")
                    }
                    if let error = model.catalogError { OrbitNote(.error, error) }
                    Text("Immerse 1.0").orbitFont(.footnote).foregroundStyle(Orbit.smallest)
                        .frame(maxWidth: .infinity).padding(.top, 20)
                }
                .padding(.horizontal, Orbit.gutter).padding(.bottom, 24)
            }
            .orbitSheetGround(screen: true)
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.buttonStyle(OrbitPillStyle(kind: .white, inBar: true))
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .orbitSheet(screen: true)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                PermissionCircle(name: "Camera", symbol: "camera", state: PermissionCopy.label(AVFoundationCaptureAuthorizer().authorizationStatus()))
                PermissionCircle(name: "Photos (add only)", symbol: "photo",
                                 state: PermissionCopy.label(PhotoKitAuthorizer().authorizationStatus(for: .addOnly)))
                PermissionCircle(name: "Microphone", symbol: "mic",
                                 state: PermissionCopy.label(AVFoundationCaptureAuthorizer().microphoneAuthorizationStatus()),
                                 detail: "Movie clips only · ")
            }
            Text("No Accounts, sign-in, analytics or Immerse server. Your Films stay under your control. The microphone records only sound with Super 8 and 16mm movie clips; clips stay in their Film on this iPhone.")
                .orbitFont(.footnote).foregroundStyle(Orbit.label).padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } label: {
                Label("Open iPhone Settings", systemImage: "gearshape").labelStyle(.titleOnly)
            }
            .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 56, fullWidth: true))
        }
    }
}

/// A permission as a circle (A04): white when allowed, dashed before it is asked, dark when off.
private struct PermissionCircle: View {
    let name: String
    let symbol: String
    let state: String
    var detail = ""

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: state == "Off" || state == "Restricted" ? symbol + ".slash" : symbol)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(state == "Allowed" ? Color.black : state == "Not asked yet" ? Color.white : Orbit.smallest)
                .frame(width: 72, height: 72)
                .background {
                    switch state {
                    case "Allowed": Circle().fill(Color.white)
                    case "Not asked yet": OrbitDashedRing(lineWidth: 1, dash: [3, 3])
                    default: Circle().fill(Orbit.sunken).overlay(Circle().strokeBorder(Orbit.pressed, lineWidth: 1))
                    }
                }
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                Text(name).font(.orbit(size: 13, weight: .semibold, relativeTo: .footnote)).foregroundStyle(.white)
                Text(detail + state).font(.orbit(.footnote)).foregroundStyle(Orbit.label)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(name), \(detail)\(state)")
            .accessibilityAddTraits(.isStaticText)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A Films row (A04): its title and a short summary, opening in place to its full words.
private struct SettingsDetailRow<Detail: View>: View {
    let title: String
    let summary: String
    @ViewBuilder let detail: Detail
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 12) {
                    Text(title).orbitFont(.body, weight: .semibold).foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Text(summary).orbitFont(.footnote).foregroundStyle(Orbit.label).multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold)).foregroundStyle(Orbit.label)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(summary)
            .accessibilityHint(open ? "Hides the details" : "Shows the details")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("settings-\(title)")
            if open {
                VStack(alignment: .leading, spacing: 8) { detail }
                    .orbitFont(.footnote).foregroundStyle(Orbit.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)
            }
        }
        .orbitRow()
    }
}

/// A switch on its own row, with its note under it, for the Debug build's testing switches.
struct OrbitSwitchRow: View {
    let title: String
    @Binding var isOn: Bool
    let identifier: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isOn) {
                Text(title).orbitFont(.body, weight: .semibold).foregroundStyle(.white)
            }
            .tint(Orbit.label)
            .accessibilityIdentifier(identifier)
            .orbitRow()
            Text(note).orbitFont(.footnote).foregroundStyle(Orbit.label).padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
