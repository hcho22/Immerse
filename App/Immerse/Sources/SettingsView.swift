import NativeAdapters
import SwiftUI

/// Settings (A04): Privacy as three circles with the app's privacy paragraph and the way to iPhone Settings, then the
/// Films rows, Trial, Subscription, Storage and backup and Saving to Photos, each opening in place to its full words.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(JournalModel.self) private var model
    @Environment(\.hosting) private var hosting
    @Environment(\.groupFilms) private var groupFilms
    @Environment(\.rollShop) private var rollShop

    var body: some View {
        NavigationStack {
            GeometryReader { screen in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    #if DEBUG
                    OrbitSectionLabel("Debug testing").padding(.leading, 4).padding(.top, 8)
                    TestingUnlockSection(unlock: model.testingUnlock)
                    DevelopedPreviewSection(previews: model.developedPreviews)
                    if let hosting, hosting.phase != .signedOut {
                        NavigationLink { ServerChecksView(hosting: hosting) } label: {
                            HStack {
                                Text("Server checks").orbitFont(.body, weight: .semibold).foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Orbit.label)
                            }
                            .orbitRow()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("server-checks")
                    }
                    #endif
                    if let hosting { AccountSettingsSection(hosting: hosting) }
                    if let groupFilms { GroupFilmsSettingsSection(groupFilms: groupFilms) }
                    OrbitSectionLabel("Privacy").padding(.leading, 4).padding(.top, 8)
                    privacy
                    OrbitSectionLabel("Films").padding(.leading, 4).padding(.top, 8)
                    if let error = model.trialError { OrbitNote(.error, "Trial status unavailable: \(error)") }
                    SettingsDetailRow(title: "Trial") {
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
                    SettingsDetailRow(title: "Storage and backup") { Text(PrivacyCopy.backup) }
                    SettingsDetailRow(title: "Saving to Photos") {
                        Text("Exports are optional. Photos receives only the revealed media you choose. A developed export is a flattened result, not a restorable Film or edit history.")
                    }
                    if let error = model.catalogError { OrbitNote(.error, error) }
                    Text("Immerse 1.0").orbitFont(.footnote).foregroundStyle(Orbit.smallest)
                        .frame(maxWidth: .infinity).padding(.top, 20)
                }
                .padding(.horizontal, Orbit.gutter).padding(.bottom, 24)
                .padding(.leading, screen.safeAreaInsets.leading).padding(.trailing, screen.safeAreaInsets.trailing)
            }
            }
            // The scroll view reaches the screen's edges in landscape, as a list does, with its content inside the safe
            // area, so a drag beside the Dynamic Island scrolls it.
            .ignoresSafeArea(.container, edges: .horizontal)
            .orbitSheetGround(screen: true)
            // Here rather than in the Account section, which is absent while signed out: a session Clerk restores after
            // launch still shows its Account when Settings opens.
            .task {
                await hosting?.refresh()
                await rollShop?.refresh()
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(dynamicTypeSize.isAccessibilitySize ? .large : .inlineLarge)
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
            Text(hosting == nil ? PrivacyCopy.settingsV1 : PrivacyCopy.settingsWithServer)
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
            Image(systemName: symbol)
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

/// A Films row (A04): its title, opening in place to its full words.
private struct SettingsDetailRow<Detail: View>: View {
    let title: String
    @ViewBuilder let detail: Detail
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 12) {
                    Text(title).orbitFont(.body, weight: .semibold).foregroundStyle(.white)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold)).foregroundStyle(Orbit.label)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
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

/// Group Films in Settings (v2 PRD V2-FR-54, V2-FR-57): the support address reports also go to, and Delete Guest Identity
/// for a guest who never signed in. Shown only where the app has a server.
private struct GroupFilmsSettingsSection: View {
    let groupFilms: GroupFilms
    @State private var confirmDelete = false

    var body: some View {
        if groupFilms.supportAddress != nil || groupFilms.hasGuestIdentity {
            VStack(alignment: .leading, spacing: 12) {
                OrbitSectionLabel("Group Films").padding(.leading, 4).padding(.top, 8)
                if let address = groupFilms.supportAddress {
                    Text("Reports and questions about Group Films go to \(address). Immerse's support answers within 48 hours.")
                        .orbitFont(.body).foregroundStyle(Orbit.body).fixedSize(horizontal: false, vertical: true)
                        .orbitRow()
                        .accessibilityIdentifier("support-address")
                }
                if groupFilms.hasGuestIdentity {
                    Button("Delete Guest Identity") { confirmDelete = true }
                        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 56, fullWidth: true))
                        .accessibilityIdentifier("delete-guest-identity")
                }
            }
            .orbitConfirmation(isPresented: $confirmDelete, symbol: "person.crop.circle.badge.xmark", title: "Delete Guest Identity?",
                               message: GroupFilmsCopy.deleteGuestIdentity, confirm: "Delete", identifier: "confirm-delete-guest-identity") {
                Task { await groupFilms.deleteGuestIdentity() }
            }
        }
    }
}
