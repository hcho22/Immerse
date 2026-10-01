import NativeAdapters
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(JournalModel.self) private var model

    var body: some View {
        NavigationStack {
            Form {
                Section("Storage and backup") { Text(PrivacyCopy.backup) }
                Section("Trial") {
                    if let error = model.trialError {
                        Text("Trial status unavailable: \(error)").foregroundStyle(.red)
                    }
                    Text("One complete Film per iPhone, with any Camera. The first successfully saved capture consumes it. Deleting a used Film or the app does not restore the Trial.")
                    Text("The Trial record stays on this iPhone. Films restored to another iPhone keep their remaining capture rights and do not use that iPhone's Trial.")
                }
                Section("Saving to Photos") {
                    Text("Exports are optional. Photos receives only the revealed media you choose. A developed export is a flattened result, not a restorable Film or edit history.")
                }
                Section("Privacy") {
                    LabeledContent("Camera", value: String(describing: AVFoundationCaptureAuthorizer().authorizationStatus()).capitalized)
                    LabeledContent("Photos (add only)", value: String(describing: PhotoKitAuthorizer().authorizationStatus(for: .addOnly)).capitalized)
                    LabeledContent("Microphone", value: "Not used")
                    Text("No Accounts, sign-in, analytics or Immerse server. Your Films stay under your control.")
                    Button("Open iPhone Settings", systemImage: "gearshape") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                Section("Subscription") {
                    NavigationLink("Subscription") { SubscriptionView() }
                }
                Section("About") { LabeledContent("Immerse", value: "1.0") }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
        }
    }
}
