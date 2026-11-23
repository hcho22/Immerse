#if DEBUG
import CryptoKit
import Security
import ImmerseServer
import SwiftUI
import UserNotifications

/// Debug builds only: the tools Stage 1's iPhone proofs use (`Evidence/NativeApp/manual-validation.md`, section V), on
/// a build with a real server configuration and a signed-in Host. They send a picture-sized file through the upload
/// path to a proof event (open check OC-3), try to read it before and after its reveal (OC-4), and register this iPhone
/// for the push test (OC-7). The proof event and its reveal are made on the server with `npx convex run`
/// (`Backend/SETUP.md`). `Scripts/verify-release-excludes-testing-unlock.sh` holds this out of Release.
struct ServerChecksView: View {
    let hosting: HostingSession
    @State private var eventID = ""
    @State private var log: [String] = []
    @State private var running = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Proof event id, from `proofs:createProofEvent`").orbitFont(.footnote).foregroundStyle(Orbit.label)
                TextField("Event id", text: $eventID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .orbitFont(.body).foregroundStyle(.white).tint(.white)
                    .padding(.horizontal, 20).frame(minHeight: 52).background(Orbit.button, in: Capsule())
                    .accessibilityIdentifier("server-checks-event")
                check("Send a picture-sized file") { try await sendPicture() }
                check("Read the event's pictures") { try await readPictures() }
                check("Register for the push test") { try await registerForPush() }
                ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                    Text(line).orbitFont(.footnote).foregroundStyle(Orbit.body).textSelection(.enabled)
                }
            }
            .padding(.horizontal, Orbit.gutter).padding(.vertical, 16)
        }
        .orbitSheetGround(screen: true)
        .navigationTitle("Server checks")
        .disabled(running)
    }

    private func check(_ title: String, _ work: @escaping @MainActor () async throws -> Void) -> some View {
        Button(title) {
            running = true
            Task {
                do { try await work() } catch { log.append("\(title): failed, \(error)") }
                running = false
            }
        }
        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 52, fullWidth: true))
    }

    private var trimmedEventID: String { eventID.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// A 4 MB file of random bytes, the size of a developed Disposable picture, as exposure 1.
    private func sendPicture() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "server-check-\(UUID().uuidString).jpg")
        var bytes = [UInt8](repeating: 0, count: 4 << 20)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw CocoaError(.fileWriteUnknown) }
        try Data(bytes).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let fingerprint = try PictureUploader.fingerprint(of: file)
        let started = Date.now
        let outcome = try await PictureUploader(functions: hosting.functions)
            .send(PictureToSend(eventID: trimmedEventID, exposureNumber: 1, captureTime: .now, fileURL: file))
        log.append("Send: \(outcome) in \(String(format: "%.1f", Date.now.timeIntervalSince(started))) s, \(fingerprint.size) bytes, SHA-256 \(fingerprint.sha256)")
    }

    /// Before the reveal the server must refuse ("sealed"); after it, each picture downloads whole.
    private func readPictures() async throws {
        do {
            let reply = try await hosting.functions.call(.action, "reads:readAddresses", ["eventId": .string(trimmedEventID)])
            for picture in reply.array ?? [] {
                guard let address = picture["url"]?.string.flatMap(URL.init(string:)) else { continue }
                let (data, _) = try await URLSession.shared.data(from: address)
                let sha = Data(SHA256.hash(data: data)).base64EncodedString()
                log.append("Read exposure \(Int(picture["exposureNumber"]?.number ?? 0)): \(data.count) bytes, checksum \(sha == picture["sha256"]?.string ? "matches" : "DIFFERS")")
                // The same object without its signature.
                var unsigned = URLComponents(url: address, resolvingAgainstBaseURL: false)!
                unsigned.query = nil
                let (_, response) = try await URLSession.shared.data(from: unsigned.url!)
                log.append("Unsigned read: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
            if reply.array?.isEmpty ?? true { log.append("Read: no stored pictures") }
        } catch let error as ServerError {
            log.append("Read: \(error)")
        }
    }

    private func registerForPush() async throws {
        let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        log.append("Notifications \(allowed ? "allowed" : "not allowed")")
        let token = try await PushRegistration.shared.register()
        try await AccountServer(functions: hosting.functions)
            .registerPushToken(token, installationID: HostingSession.installationID(), environment: PushRegistration.environment)
        log.append("Push token registered (\(PushRegistration.environment.rawValue)); run push:sendTestAlert for this Account")
    }
}
#endif
