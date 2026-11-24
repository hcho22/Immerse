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
    #if !APPCLIP
    /// Group Films, where the app has a hosting session (a server configuration, or a Debug stand-in); nil otherwise.
    ///
    /// They are kept in the folder the mini-app shares (`GroupFilmsFolder`), so a guest who joined in the mini-app finds
    /// the same event, Roll and waiting pictures here, with the mini-app's guest identity read from the Keychain
    /// (V2-FR-19). The full app marks the folder as its own, so a mini-app still open hands over instead of writing.
    static func make(hosting: HostingSession?) -> GroupFilms? {
        guard let hosting else { return nil }
        do {
            #if DEBUG
            if let debug = DebugGroupFilms.make(hosting: hosting) { return debug }
            #endif
            let configuration = ServerConfiguration.main
            let folder = try GroupFilmsFolder.locate(appGroup: ServerConfiguration.appGroup(in: Bundle.main.infoDictionary ?? [:]))
            if folder.isShared { try folder.markTakenOverByFullApp() }
            return try make(hosting: hosting, folder: folder, identities: KeychainGuestIdentityStore(),
                            miniAppIdentities: KeychainGuestIdentityStore.miniApp, joinHost: configuration?.joinHost,
                            supportAddress: configuration?.supportAddress)
        } catch {
            return nil
        }
    }
    #endif

    static func make(hosting: HostingSession, folder: GroupFilmsFolder, identities: any GuestIdentityStoring,
                     miniAppIdentities: (any GuestIdentityStoring)? = nil, joinHost: String?,
                     supportAddress: String?) throws -> GroupFilms {
        let rollsRoot = folder.url.appending(path: "Rolls", directoryHint: .isDirectory)
        let rolls = try JournalModel(root: rollsRoot, trialStore: NoTrialStore(), subscriptions: nil)
        let queue = try UploadQueue(directory: folder.url.appending(path: "Uploads", directoryHint: .isDirectory))
        return GroupFilms(server: EventServer(functions: hosting.functions), hosting: hosting, rolls: rolls, rollsRoot: rollsRoot,
                          queue: queue, folder: folder, identities: identities, miniAppIdentities: miniAppIdentities,
                          joinHost: joinHost, supportAddress: supportAddress, functions: hosting.functions)
    }
}
