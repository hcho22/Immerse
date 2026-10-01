import SwiftUI
import UIKit

struct KeychainProbeView: View {
    let store: KeychainProbeStore

    @State private var record: KeychainProbeRecord?
    @State private var status: String = "Read the current marker before changing anything."
    @State private var lastError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Device") {
                    LabeledContent("Model", value: UIDevice.current.model)
                    LabeledContent("System", value: UIDevice.current.systemVersion)
                    LabeledContent("Bundle", value: Bundle.main.bundleIdentifier ?? "unknown")
                }

                Section("Keychain Record") {
                    if let record {
                        LabeledContent("Marker", value: record.markerID.uuidString)
                        LabeledContent("Consumed", value: record.consumed ? "yes" : "no")
                        LabeledContent("Written", value: record.writtenAt.formatted(date: .numeric, time: .standard))
                        LabeledContent("Probe build", value: record.appBuild)
                    } else {
                        Text("No marker found.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Actions") {
                    Button("Read marker") {
                        read()
                    }
                    Button("Write fresh this-device-only marker") {
                        writeFresh()
                    }
                    Button("Mark consumed") {
                        markConsumed()
                    }
                    Button("Delete probe marker", role: .destructive) {
                        delete()
                    }
                }

                Section("Status") {
                    Text(status)
                    if let lastError {
                        Text(lastError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Trial Keychain Probe")
            .onAppear(perform: read)
        }
    }

    private func read() {
        do {
            record = try store.read()
            status = record == nil ? "Read complete. No marker found." : "Read complete. Marker found."
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func writeFresh() {
        do {
            let next = KeychainProbeRecord.fresh(appBuild: appBuild)
            try store.write(next)
            record = next
            status = "Fresh this-device-only marker written."
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func markConsumed() {
        do {
            var next = record ?? KeychainProbeRecord.fresh(appBuild: appBuild)
            next.consumed = true
            try store.write(next)
            record = next
            status = "Marker updated to consumed."
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func delete() {
        do {
            try store.delete()
            record = nil
            status = "Probe marker deleted."
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private var appBuild: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
