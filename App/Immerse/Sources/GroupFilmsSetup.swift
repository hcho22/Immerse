import EntitlementCore
import FilmPersistence
import Foundation
import ImmerseServer

/// A Trial store that refuses every use, for the Group Films' own Journal: a Roll taken in a Group Film never starts,
/// uses or blocks the Trial (v2 PRD V2-FR-07). Reading finds no record, so nothing about the Trial shows there.
struct NoTrialStore: DeviceTrialStoring {
    struct Refused: Error {}
    func read() throws -> DeviceTrialRecord? { nil }
    func ensureDeviceRecord() throws -> DeviceTrialRecord { throw Refused() }
    func consume(filmID: UUID, captureID: String?, savedAt: Date) throws { throw Refused() }
}

@MainActor
enum GroupFilmsSetup {
    /// Group Films, where the app has a hosting session (a server configuration, or a Debug stand-in); nil otherwise.
    static func make(hosting: HostingSession?) -> GroupFilms? {
        guard let hosting else { return nil }
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
                                                   create: true).appending(path: "GroupFilms", directoryHint: .isDirectory)
            #if DEBUG
            if let debug = DebugGroupFilms.make(hosting: hosting, base: base) { return debug }
            #endif
            let configuration = ServerConfiguration.main
            return try make(hosting: hosting, base: base, identities: KeychainGuestIdentityStore(),
                            joinHost: configuration?.joinHost, supportAddress: configuration?.supportAddress)
        } catch {
            return nil
        }
    }

    static func make(hosting: HostingSession, base: URL, identities: any GuestIdentityStoring, joinHost: String?,
                     supportAddress: String?) throws -> GroupFilms {
        let rollsRoot = base.appending(path: "Rolls", directoryHint: .isDirectory)
        let rolls = try JournalModel(root: rollsRoot, trialStore: NoTrialStore(), subscriptions: nil)
        let queue = try UploadQueue(directory: base.appending(path: "Uploads", directoryHint: .isDirectory))
        return GroupFilms(server: EventServer(functions: hosting.functions), hosting: hosting, rolls: rolls, rollsRoot: rollsRoot,
                          queue: queue, root: base, identities: identities, joinHost: joinHost, supportAddress: supportAddress,
                          functions: hosting.functions)
    }
}
