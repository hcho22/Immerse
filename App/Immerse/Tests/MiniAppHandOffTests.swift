import FilmDomain
import FilmPersistence
import Foundation
import ImmerseServer
import NativeAdapters
import Synchronization
import UIKit
import XCTest
@testable import Immerse

/// The hand-off from the mini-app to the full app (v2 PRD V2-FR-19, V2-FR-34, V2-FR-35): a guest joins and shoots in the
/// mini-app, some pictures are sent and some still wait, and the full app is installed. Here the mini-app is the same
/// Group Films code the App Clip target builds, run on a folder standing for the shared App Group container with the
/// mini-app's own guest identity store; the full app then opens that folder with a store of its own and the mini-app's
/// to read. The place, the Roll, the pictures not yet sent and the queue are all there, each waiting picture is sent
/// once, and nothing the server already holds is sent again.
///
/// What only an iPhone can show stays unproved here: the real App Group container, the full app reading the App Clip's
/// Keychain item, and iOS handing the link to the full app (Evidence/NativeApp/manual-validation.md, section J).
@MainActor
final class MiniAppHandOffTests: XCTestCase {
    /// The stand-in server, recording each call, with a switch that takes the network away.
    private final class Network: ServerFunctions, @unchecked Sendable {
        let server: DebugHostingServer
        let offline = Mutex(false)
        let calls = Mutex<[(path: String, args: [String: JSONValue])]>([])
        /// The exposures the server holds, as the real server's upload path records them.
        let stored = Mutex<[Int]>([])
        /// Cuts the network after this many pictures have been confirmed, as a guest walking out of signal would.
        let confirmLimit = Mutex<Int?>(nil)
        init(_ server: DebugHostingServer) { self.server = server }

        func call(_ kind: FunctionKind, _ path: String, _ args: [String: JSONValue]) async throws(ServerError) -> JSONValue {
            if offline.withLock({ $0 }) { throw .unreachable }
            calls.withLock { $0.append((path, args)) }
            let reply = try await server.call(kind, path, args)
            if path == "pictures:requestUpload" {
                stored.withLock { $0.append(Int(args["exposureNumber"]?.number ?? 0)) }
                let held = stored.withLock { $0.count }
                if let limit = confirmLimit.withLock({ $0 }), held >= limit { offline.withLock { $0 = true } }
            }
            if path == "joining:join" || path == "joining:memberView", case var .object(fields) = reply {
                fields["exposuresUsed"] = .number(Double(stored.withLock { $0.max() ?? 0 }))
                return .object(fields)
            }
            return reply
        }

        func uploads() -> [Int] {
            calls.withLock { $0.filter { $0.path == "pictures:requestUpload" }.map { Int($0.args["exposureNumber"]?.number ?? 0) } }
        }

        /// The guest identity each call of a function was made as.
        func identities(of path: String) -> [String] {
            calls.withLock { $0.filter { $0.path == path }.compactMap { $0.args["guest"]?["publicId"]?.string } }
        }
    }

    private var shared: GroupFilmsFolder!
    private var network: Network!
    private var server: DebugHostingServer!
    private var miniAppIdentities: MemoryGuestIdentityStore!
    private var appIdentities: MemoryGuestIdentityStore!

    override func setUp() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "MiniAppHandOff-\(UUID().uuidString)")
        shared = GroupFilmsFolder(url: root.appending(path: "GroupFilms"), isShared: true)
        server = DebugHostingServer(accountName: nil)
        let backend = DebugEventBackend()
        backend.seedOpenEvent(code: DebugGroupFilms.openCode)
        server.events = backend
        network = Network(server)
        miniAppIdentities = MemoryGuestIdentityStore()
        appIdentities = MemoryGuestIdentityStore()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: shared.url.deletingLastPathComponent())
    }

    private func hosting() -> HostingSession {
        HostingSession(signIn: DebugHostSignIn(server: server, signedIn: false), functions: network,
                       defaults: UserDefaults(suiteName: "MiniAppHandOff-\(UUID().uuidString)")!)
    }

    /// The mini-app: Group Films on the shared folder with the mini-app's own identity and nothing else.
    private func miniApp() throws -> GroupFilms {
        try GroupFilmsSetup.make(hosting: hosting(), folder: shared, identities: miniAppIdentities,
                                 joinHost: DebugGroupFilms.joinHost, supportAddress: nil)
    }

    /// The full app, installed afterwards: the same folder, marked as its own, its own identity store and the mini-app's.
    private func fullApp() throws -> GroupFilms {
        try shared.markTakenOverByFullApp()
        return try GroupFilmsSetup.make(hosting: hosting(), folder: shared, identities: appIdentities,
                                        miniAppIdentities: miniAppIdentities, joinHost: DebugGroupFilms.joinHost,
                                        supportAddress: nil)
    }

    private func shoot(_ groupFilms: GroupFilms, _ filmID: UUID) async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900)).image { context in
            UIColor(hue: .random(in: 0...1), saturation: 0.6, brightness: 0.7, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
        }
        let source = FileManager.default.temporaryDirectory.appending(path: "capture-\(UUID().uuidString).jpg")
        try XCTUnwrap(image.jpegData(compressionQuality: 0.9)).write(to: source)
        let receiver = try await groupFilms.rolls.trial.receiver(filmID: filmID)
        try await receiver.commit(.photoSaved(source))
        groupFilms.rolls.refresh()
    }

    /// A guest joins in the mini-app and shoots `pictures` pictures, of which `sent` reach the server before the mini-app
    /// loses its connection and is put away.
    private func guestInTheMiniApp(pictures: Int, sent: Int) async throws -> (eventID: String, filmID: UUID, identity: GuestIdentity) {
        let miniApp = try miniApp()
        let ok = await miniApp.join(code: DebugGroupFilms.openCode, guestName: "Jo")
        XCTAssertTrue(ok, miniApp.notice ?? "")
        let place = try XCTUnwrap(miniApp.places.first)
        let filmID = try XCTUnwrap(place.rollFilmID)
        for _ in 0..<pictures { try await shoot(miniApp, filmID) }
        await miniApp.developPending()
        XCTAssertEqual(miniApp.waiting[place.eventID], pictures)
        network.confirmLimit.withLock { $0 = sent }
        if sent == 0 { network.offline.withLock { $0 = true } }
        await miniApp.uploadPass()
        XCTAssertEqual(miniApp.waiting[place.eventID] ?? 0, pictures - sent, "The mini-app sent what it could while it was open")
        // The mini-app leaves the screen for good. An App Clip does nothing in the background, so nothing more is sent
        // from it (this test runs the full app's build of the same code, whose own time after leaving the screen is not
        // the mini-app's, so it is not asked for here).
        network.confirmLimit.withLock { $0 = nil }
        return (place.eventID, filmID, try XCTUnwrap(try miniAppIdentities.read()))
    }

    func testAMiniAppGuestsPlaceRollPicturesAndQueueAreThereInTheFullAppAndNothingIsSentTwice() async throws {
        let (eventID, filmID, identity) = try await guestInTheMiniApp(pictures: 5, sent: 2)
        XCTAssertEqual(network.uploads(), [1, 2])

        let app = try fullApp()
        // The same event and place, held by the guest identity the mini-app made.
        let place = try XCTUnwrap(app.place(eventID))
        XCTAssertEqual(place.place, .joined)
        XCTAssertEqual(place.guestName, "Jo")
        XCTAssertTrue(place.asGuest)
        XCTAssertEqual(place.guestPublicID, identity.publicId)
        // The same Roll, with the same exposures used and left.
        XCTAssertEqual(place.rollFilmID, filmID)
        let film = try XCTUnwrap(app.rolls.film(filmID))
        XCTAssertEqual(film.captures.map(\.sequenceNumber), [1, 2, 3, 4, 5])
        XCTAssertEqual(film.remainingExposures, 22)
        // The pictures not yet sent still wait, and the sent ones' originals are gone as before.
        await app.countWaiting()
        XCTAssertEqual(app.waiting[eventID], 3)
        XCTAssertNil(try app.rolls.repository.mediaAsset(filmID: filmID, sequenceNumber: 1, kind: .source))
        XCTAssertNotNil(try app.rolls.repository.mediaAsset(filmID: filmID, sequenceNumber: 3, kind: .source))

        // The full app has a connection: every waiting picture goes, once, as the same guest.
        network.offline.withLock { $0 = false }
        await app.developPending()
        await app.uploadPass()
        XCTAssertEqual(app.waiting[eventID] ?? 0, 0)
        XCTAssertEqual(network.uploads(), [1, 2, 3, 4, 5], "Each picture was sent once; the two the mini-app sent were not sent again")
        XCTAssertEqual(network.stored.withLock { $0.sorted() }, [1, 2, 3, 4, 5], "Every picture taken reached the server")
        XCTAssertNil(try app.rolls.repository.mediaAsset(filmID: filmID, sequenceNumber: 5, kind: .source))
        // The full app made no identity of its own: the guest is still the guest they were.
        XCTAssertNil(try appIdentities.read())
        let sessions = network.calls.withLock { $0.filter { $0.path == "guests:startSession" }.compactMap { $0.args["publicId"]?.string } }
        XCTAssertFalse(sessions.isEmpty)
        XCTAssertEqual(Set(sessions), [identity.publicId])
    }

    func testAGuestWhoShotWithNoSignalAtAllLosesNothingByInstallingTheFullApp() async throws {
        let (eventID, filmID, _) = try await guestInTheMiniApp(pictures: 3, sent: 0)
        XCTAssertEqual(network.uploads(), [])
        let app = try fullApp()
        await app.countWaiting()
        XCTAssertEqual(app.waiting[eventID], 3)
        network.offline.withLock { $0 = false }
        await app.uploadPass()
        XCTAssertEqual(network.uploads(), [1, 2, 3])
        XCTAssertEqual(app.rolls.film(filmID)?.remainingExposures, 24)
    }

    func testAPictureSavedButNotYetDevelopedInTheMiniAppDevelopsAndGoesFromTheFullApp() async throws {
        let (place, filmID) = try await { () async throws -> (LocalPlace, UUID) in
            let miniApp = try miniApp()
            let joined = await miniApp.join(code: DebugGroupFilms.openCode, guestName: "Jo")
            XCTAssertTrue(joined)
            let place = try XCTUnwrap(miniApp.places.first)
            let filmID = try XCTUnwrap(place.rollFilmID)
            // Saved at the camera, and the mini-app is put away before it could develop it.
            try await shoot(miniApp, filmID)
            return (place, filmID)
        }()

        let app = try fullApp()
        await app.countWaiting()
        XCTAssertEqual(app.waiting[place.eventID] ?? 0, 0)
        await app.developPending()
        XCTAssertEqual(app.waiting[place.eventID], 1, "The full app develops the picture the mini-app saved")
        await app.uploadPass()
        XCTAssertEqual(network.uploads(), [1])
    }

    func testTheSameLinkOpenedInTheFullAppFindsTheGuestsOwnPlaceAndGoesOnWithTheirRoll() async throws {
        let (eventID, filmID, identity) = try await guestInTheMiniApp(pictures: 2, sent: 2)
        let app = try fullApp()
        network.offline.withLock { $0 = false }
        // The guest scans the printed code again; iOS now gives the link to the full app.
        XCTAssertTrue(app.handle(url: try XCTUnwrap(URL(string: "https://\(DebugGroupFilms.joinHost)/j/\(DebugGroupFilms.openCode)"))))
        let preview = try await app.preview(code: DebugGroupFilms.openCode)
        XCTAssertEqual(preview.status, .member, "The server knows the guest: the full app asked as the mini-app's identity")
        XCTAssertEqual(Set(network.identities(of: "joining:preview")), [identity.publicId])
        let opened = await app.openAsMember(code: DebugGroupFilms.openCode, eventID: eventID)
        XCTAssertTrue(opened)
        XCTAssertEqual(app.openEvent, eventID)
        XCTAssertEqual(app.place(eventID)?.rollFilmID, filmID, "No new Roll was made")
        XCTAssertEqual(network.calls.withLock { $0.filter { $0.path == "joining:join" }.count }, 1, "The guest joined once, in the mini-app")
        // And keeps shooting their own Roll in the full app.
        try await shoot(app, filmID)
        await app.developPending()
        await app.uploadPass()
        XCTAssertEqual(network.uploads(), [1, 2, 3])
        XCTAssertEqual(app.rolls.film(filmID)?.remainingExposures, 24)
    }

    func testANewEventJoinedInTheFullAppUsesTheGuestIdentityThePhoneAlreadyHolds() async throws {
        _ = try await guestInTheMiniApp(pictures: 1, sent: 1)
        let app = try fullApp()
        network.offline.withLock { $0 = false }
        let caller = try XCTUnwrap(try miniAppIdentities.read())
        _ = try await app.preview(code: "AnotherEventCodeTests0")
        XCTAssertEqual(network.identities(of: "joining:preview").last, caller.publicId)
        XCTAssertNil(try appIdentities.read(), "The phone keeps one guest identity, not two")
    }

    func testAPlaceWhoseIdentityCannotBeReadIsNeverActedOnAsAStranger() async throws {
        let (eventID, _, _) = try await guestInTheMiniApp(pictures: 2, sent: 0)
        // The full app cannot read the mini-app's identity (the Keychain item is missing or unreadable).
        try miniAppIdentities.delete()
        let app = try fullApp()
        network.offline.withLock { $0 = false }
        await app.uploadPass()
        await app.sync(eventID)
        await app.countWaiting()
        XCTAssertEqual(app.waiting[eventID], 2, "The pictures stay on the phone, waiting, rather than being refused as a stranger's")
        XCTAssertEqual(network.uploads(), [])
        XCTAssertNil(try appIdentities.read(), "No new identity was made in the guest's stead")
        XCTAssertEqual(app.place(eventID)?.place, .joined)
        // Once the identity can be read again, they go.
        let restored = try XCTUnwrap(app.place(eventID)?.guestPublicID)
        try miniAppIdentities.write(GuestIdentity(publicId: restored, secret: "restored-secret-for-the-stand-in-server-0000000"))
        await app.uploadPass()
        XCTAssertEqual(network.uploads(), [1, 2])
    }

    func testTheMiniAppGoesStraightToTheCameraOnlyInTheMiniApp() async throws {
        // In the full app, taking a Roll opens the event's page, as in Stage 2; the mini-app's one-tap arrival at the
        // camera is its own (ImmerseClipUITests).
        let app = try fullApp()
        let joined = await app.join(code: DebugGroupFilms.openCode, guestName: "Sam")
        XCTAssertTrue(joined)
        XCTAssertNil(app.shootOnArrival)
        XCTAssertNotNil(app.openEvent)
        XCTAssertNotNil(try appIdentities.read(), "With no mini-app identity on the phone, the full app makes its own")
    }
}
