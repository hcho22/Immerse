import SwiftUI

@main
struct ImmerseApp: App {
    @UIApplicationDelegateAdaptor(ImmerseAppDelegate.self) private var appDelegate
    @State private var launcher = JournalLauncher()
    /// Signing in to host, only where the app has a server (v2 Stage 1); nil in every build without one.
    @State private var hosting = HostingSetup.make()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let model = launcher.model {
                    JournalView().environment(model)
                } else if let failure = launcher.failure {
                    JournalUnavailableView(failure: failure, detail: launcher.failureDetail, opening: launcher.opening) { Task { await launcher.open() } }
                } else {
                    ProgressView().task { await launcher.open() }
                }
            }
            .orbitRoot()
            .environment(\.hosting, hosting)
            // Reads the Host's Account in the background; nothing waits on it, and without a network it keeps what it knew.
            .task { await hosting?.refresh() }
            .onChange(of: scenePhase) { _, phase in launcher.model?.sceneChanged(to: phase) }
        }
    }
}

/// Opens the Journal at most once at a time, so its single Trial owner is never duplicated.
@MainActor @Observable
final class JournalLauncher {
    private(set) var model: JournalModel?
    private(set) var failure: String?
    /// The system's own words for what stopped the Journal opening, where it has any.
    private(set) var failureDetail: String?
    private(set) var opening = false
    private let makeModel: @MainActor () throws -> JournalModel

    init(makeModel: @escaping @MainActor () throws -> JournalModel = JournalLauncher.makeJournal) {
        self.makeModel = makeModel
    }

    func open() async {
        guard !opening, model == nil else { return }
        opening = true
        defer { opening = false }
        do {
            let opened = try makeModel()
            await opened.recoverAtLaunch()
            model = opened
            failure = nil
        } catch {
            failure = JournalUnavailableView.message
            failureDetail = FailureCopy.systemDetail(for: error)
        }
    }

    static func makeJournal() throws -> JournalModel {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
            .appendingPathComponent("FilmJournal", isDirectory: true)
        #if DEBUG
        let model = try JournalModel(root: root, freeSpace: DebugFreeSpace(defaults: .standard))
        model.testingUnlock = TestingUnlock(defaults: .standard)
        model.developedPreviews = DevelopedPreviews(root: root, defaults: .standard)
        // A preview lasts no longer than the run that made it.
        model.developedPreviews.clearAll()
        #else
        let model = try JournalModel(root: root)
        #endif
        return model
    }
}

/// The Journal could not open (A06): what happened, that the Films are still there, the system's own words where it has
/// any, and Try Again.
private struct JournalUnavailableView: View {
    static let message = "Your Films have not been removed. Free space in iPhone Settings and try again."
    let failure: String
    let detail: String?
    let opening: Bool
    let tryAgain: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    OrbitRing(progress: 0, lineWidth: 6)
                    OrbitDashedRing(lineWidth: 6, dash: [2, 18]).padding(1)
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 34, weight: .light))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96).background(Orbit.surface, in: Circle())
                }
                .frame(width: 200, height: 200)
                .accessibilityHidden(true)
                Text("Journal unavailable").orbitFont(.title).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 20) {
                    Text(failure).orbitFont(.body).foregroundStyle(Orbit.body)
                    if let detail { Text(detail).orbitFont(.footnote).foregroundStyle(Orbit.smallest) }
                }
                .multilineTextAlignment(.center).frame(maxWidth: 320)
                Button(action: tryAgain) {
                    ZStack {
                        Text("Try Again").opacity(opening ? 0 : 1)
                        if opening { ProgressView().tint(.black) }
                    }
                }
                .buttonStyle(OrbitMainActionStyle())
                .accessibilityLabel("Try Again")
                .frame(maxWidth: 220)
                .disabled(opening)
                .padding(.top, 20)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, alignment: .center) { length, _ in length }
        }
        .scrollBounceBehavior(.basedOnSize)
        .orbitGround()
    }
}
