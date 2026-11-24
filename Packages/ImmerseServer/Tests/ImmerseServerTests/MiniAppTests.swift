import Foundation
@testable import ImmerseServer
import XCTest

/// What the mini-app and its hand-off to the full app rest on (v2 PRD V2-FR-19, V2-FR-47): the mini-app's configuration
/// with no sign-in in it, the folder the two apps share, the full app's mark on it, and the web album's switch as the
/// server reports it.
final class MiniAppConfigurationTests: XCTestCase {
    func testTheMiniAppNeedsTheServerAndTheJoinHostAndNoSignInKey() {
        let configuration = MiniAppConfiguration(infoDictionary: [
            "ImmerseConvexURL": "https://a.convex.cloud", "ImmerseJoinHost": "Join.Example.com",
            "ImmerseSupportAddress": "support@example.com",
        ])
        XCTAssertEqual(configuration?.convexURL.absoluteString, "https://a.convex.cloud")
        XCTAssertEqual(configuration?.joinHost, "join.example.com")
        XCTAssertEqual(configuration?.supportAddress, "support@example.com")
        XCTAssertNotNil(MiniAppConfiguration(infoDictionary: ["ImmerseConvexURL": "http://127.0.0.1:3210", "ImmerseJoinHost": "join.immerse.test"]))
    }

    func testAMiniAppBuiltWithoutTheConfigurationHasNone() {
        XCTAssertNil(MiniAppConfiguration(infoDictionary: [:]))
        XCTAssertNil(MiniAppConfiguration(infoDictionary: ["ImmerseConvexURL": "https://a.convex.cloud"]))
        XCTAssertNil(MiniAppConfiguration(infoDictionary: ["ImmerseConvexURL": "https://a.convex.cloud", "ImmerseJoinHost": ""]))
        XCTAssertNil(MiniAppConfiguration(infoDictionary: ["ImmerseConvexURL": "http://a.convex.cloud", "ImmerseJoinHost": "join.example.com"]))
        // Unexpanded build settings, as a build without the local configuration file leaves them.
        XCTAssertNil(MiniAppConfiguration(infoDictionary: ["ImmerseConvexURL": "$(IMMERSE_CONVEX_URL)", "ImmerseJoinHost": "$(IMMERSE_JOIN_HOST)"]))
    }

    func testTheAppGroupIsConfigurationAndAbsentWithoutIt() {
        XCTAssertEqual(ServerConfiguration.appGroup(in: ["ImmerseAppGroup": "group.com.example.immerse"]), "group.com.example.immerse")
        XCTAssertNil(ServerConfiguration.appGroup(in: [:]))
        XCTAssertNil(ServerConfiguration.appGroup(in: ["ImmerseAppGroup": ""]))
        XCTAssertNil(ServerConfiguration.appGroup(in: ["ImmerseAppGroup": "$(IMMERSE_APP_GROUP)"]))
        XCTAssertNil(ServerConfiguration.appGroup(in: ["ImmerseAppGroup": "com.example.not-a-group"]))
    }
}

final class GroupFilmsFolderTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "group-films-folder-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testABuildWithNoAppGroupKeepsItsOwnFolder() throws {
        let folder = try GroupFilmsFolder.locate(appGroup: nil)
        XCTAssertFalse(folder.isShared)
        XCTAssertEqual(folder.url.lastPathComponent, "GroupFilms")
    }

    func testTheFullAppsMarkIsWrittenOnceAndTheMiniAppReadsIt() throws {
        let shared = GroupFilmsFolder(url: root.appending(path: "GroupFilms"), isShared: true)
        XCTAssertFalse(shared.fullAppTookOver)
        try shared.markTakenOverByFullApp()
        XCTAssertTrue(shared.fullAppTookOver)
        try shared.markTakenOverByFullApp()
        // The mini-app opens the same folder and finds the mark.
        XCTAssertTrue(GroupFilmsFolder(url: shared.url, isShared: true).fullAppTookOver)
    }

    func testWhatABuildKeptInItsOwnFolderMovesToTheSharedOneOnceAndWhole() throws {
        let local = root.appending(path: "Local/GroupFilms")
        try FileManager.default.createDirectory(at: local.appending(path: "Uploads/e1-1"), withIntermediateDirectories: true)
        try Data("places".utf8).write(to: local.appending(path: "places.json"))
        try Data("picture".utf8).write(to: local.appending(path: "Uploads/e1-1/developed.jpg"))
        let shared = GroupFilmsFolder(url: root.appending(path: "Shared/GroupFilms"), isShared: true)
        try shared.adopt(local: local)
        XCTAssertFalse(FileManager.default.fileExists(atPath: local.path))
        XCTAssertEqual(try Data(contentsOf: shared.url.appending(path: "places.json")), Data("places".utf8))
        XCTAssertEqual(try Data(contentsOf: shared.url.appending(path: "Uploads/e1-1/developed.jpg")), Data("picture".utf8))
        // Once the shared folder holds anything, a folder of the app's own is left where it is: nothing is merged over it.
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        try Data("later".utf8).write(to: local.appending(path: "places.json"))
        try shared.adopt(local: local)
        XCTAssertEqual(try Data(contentsOf: shared.url.appending(path: "places.json")), Data("places".utf8))
        XCTAssertEqual(try Data(contentsOf: local.appending(path: "places.json")), Data("later".utf8))
    }

    /// A folder whose items exist but cannot be inspected: `fileExists` reads them as absent.
    private func locked(_ name: String) throws -> URL {
        let folder = root.appending(path: name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path) }
        return folder
    }

    private func lock(_ folder: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder.path)
    }

    func testASharedFolderThatCannotBeInspectedIsKeptAndNothingIsMovedOntoIt() throws {
        let local = root.appending(path: "Local/GroupFilms")
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        try Data("places".utf8).write(to: local.appending(path: "places.json"))
        let container = try locked("Shared")
        try FileManager.default.createDirectory(at: container.appending(path: "GroupFilms"), withIntermediateDirectories: true)
        try lock(container)
        let shared = GroupFilmsFolder(url: container.appending(path: "GroupFilms"), isShared: true)
        XCTAssertNoThrow(try shared.adopt(local: local))
        XCTAssertEqual(try Data(contentsOf: local.appending(path: "places.json")), Data("places".utf8))
    }

    func testALocalFolderThatCannotBeInspectedIsNotSkippedSilently() throws {
        let parent = try locked("Local")
        let local = parent.appending(path: "GroupFilms")
        try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        try lock(parent)
        let shared = GroupFilmsFolder(url: root.appending(path: "Shared/GroupFilms"), isShared: true)
        XCTAssertThrowsError(try shared.adopt(local: local))
    }

    func testAMarkThatCannotBeInspectedReadsAsTheFullAppHavingTakenOver() throws {
        let container = try locked("Shared")
        let shared = GroupFilmsFolder(url: container.appending(path: "GroupFilms"), isShared: true)
        try shared.markTakenOverByFullApp()
        try lock(container)
        XCTAssertTrue(shared.fullAppTookOver)
        XCTAssertNoThrow(try shared.markTakenOverByFullApp())
    }
}

final class WebAlbumSwitchTests: XCTestCase {
    private func summary(_ extra: [String: JSONValue] = [:]) -> JSONValue {
        var object: [String: JSONValue] = [
            "eventId": "e1", "title": "Ana & Leo", "hostName": "Maya", "hostLeft": false, "camera": "disposable", "filmStock": .null,
            "exposuresPerRoll": 27, "phase": "revealed", "startsAt": .null, "opensAt": 1_000, "endsAt": 2_000, "revealDelayMs": 0,
            "revealsAt": 2_000, "albumEndsAt": 31_536_002_000, "albumNotice": "none", "joiningPaused": false,
        ]
        for (key, value) in extra { object[key] = value }
        return .object(object)
    }

    func testAnEventSaysWhetherItsAlbumIsOnTheWebAndWhatAPhoneKeptBeforeReadsAsOff() throws {
        XCTAssertTrue(try summary(["webAlbumOn": true]).decoded(as: EventSummary.self).isOnTheWeb)
        XCTAssertFalse(try summary(["webAlbumOn": false]).decoded(as: EventSummary.self).isOnTheWeb)
        let kept: EventSummary = try summary().decoded()
        XCTAssertFalse(kept.isOnTheWeb)
        // It round-trips through what the phone keeps.
        let stored = try JSONEncoder().encode(try summary(["webAlbumOn": true]).decoded(as: EventSummary.self))
        XCTAssertTrue(try JSONDecoder().decode(EventSummary.self, from: stored).isOnTheWeb)
    }

    func testTheHostsSwitchIsSentAndRead() async throws {
        let functions = FakeFunctions { [summary = summary()] _, path, _ in
            guard path == "hosting:view", case .object(var view) = summary else { return ["on": true] }
            for (key, value) in ["joinCode": JSONValue.null, "joinCodeGeneration": .null, "rolls": .null, "picturesArrived": 0,
                                 "guests": [], "reports": [], "webAlbum": true] { view[key] = value }
            return .object(view)
        }
        let server = EventServer(functions: functions)
        try await server.setWebAlbum(eventID: "e1", on: true)
        let call = try XCTUnwrap(functions.calls.first)
        XCTAssertEqual(call.kind, .mutation)
        XCTAssertEqual(call.path, "hosting:setWebAlbum")
        XCTAssertEqual(call.args, ["eventId": "e1", "on": true])
        let view = try await server.hostView(eventID: "e1")
        XCTAssertTrue(view.webAlbum)
    }
}

final class MiniAppIdentityStoreTests: XCTestCase {
    func testTheMiniAppsIdentityIsAnItemOfItsOwn() {
        // The two stores never name the same Keychain item, so neither app can overwrite the other's identity.
        XCTAssertNotEqual(String(describing: KeychainGuestIdentityStore.miniApp), String(describing: KeychainGuestIdentityStore()))
    }
}
