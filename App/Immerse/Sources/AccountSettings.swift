import ImmerseServer
import SwiftUI

/// The Account in Settings (V2-FR-05): who is signed in, Sign Out, and Delete Account, reached from Settings in one tap
/// and confirmed with a second (guideline 5.1.1(v)). Shown only where the app has a server and someone is signed in.
struct AccountSettingsSection: View {
    let hosting: HostingSession
    @State private var confirmDelete = false

    static let deleteMessage = "Every picture you took in any Group Film is removed for everyone, sealed or revealed, with your name. Your Account, its sign-in, any Rolls in your balance and your link to a subscription are removed too. Copies others already saved to Photos cannot be recalled. An Apple subscription keeps billing until you cancel it in iPhone Settings. Your personal Films stay on this iPhone."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OrbitSectionLabel("Account").padding(.leading, 4).padding(.top, 8)
            if hosting.accountDeletedNotice {
                OrbitNote(.info, "Your Account was deleted. Your personal Films are still here.", identifier: "account-deleted")
            }
            switch hosting.phase {
            case .signedOut:
                EmptyView()
            case .needsAccount, .signedIn:
                if case .signedIn(let name) = hosting.phase {
                    Text("Signed in as \(name)").orbitFont(.body, weight: .semibold).foregroundStyle(.white)
                        .orbitRow().accessibilityIdentifier("account-name")
                }
                Button("Sign Out") { Task { await hosting.signOut() } }
                    .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 56, fullWidth: true))
                    .accessibilityIdentifier("sign-out")
                Button("Delete Account") { confirmDelete = true }
                    .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 56, fullWidth: true))
                    .accessibilityIdentifier("delete-account")
                if hosting.busy { ProgressView().frame(maxWidth: .infinity) }
                if let problem = hosting.problem { OrbitNote(.error, problem, identifier: "account-problem") }
            }
        }
        .disabled(hosting.busy)
        .task { await hosting.refresh() }
        .orbitConfirmation(isPresented: $confirmDelete, symbol: "person.crop.circle.badge.xmark", title: "Delete Account?",
                           message: Self.deleteMessage, confirm: "Delete Account", identifier: "confirm-delete-account") {
            Task { await hosting.deleteAccount() }
        }
    }
}
