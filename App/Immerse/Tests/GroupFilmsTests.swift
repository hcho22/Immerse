import FilmDomain
import FilmPersistence
import Foundation
import ImmerseServer
import NativeAdapters
import Synchronization
import UIKit
import XCTest
@testable import Immerse

/// Group Films on the phone (v2 PRD V2-FR-31 to V2-FR-36, V2-FR-50, V2-FR-53, V2-FR-07), against the Debug stand-in for
/// the server's event functions behind a switch that takes the network away: a guest who joined shoots offline and every
/// picture develops and waits; with a connection each one uploads and its original goes; Withdraw Before Reveal made
/// offline deletes what waits at once and tells the server later; a removed guest's phone deletes what waits for the
/// event; and an event Roll never uses the Trial.
@MainActor
final class GroupFilmsTests: XCTestCase {
    /// The stand-in server, or no network at all.
    private final class Network: ServerFunctions, @unchecked Sendable {
        let server: DebugHostingServer
        let offline = Mutex(false)
        let paths = Mutex<[String]>([])
        init(_ server: DebugHostingServer) { self.server = server }
        func call(_ kind: FunctionKind, _ path: String, _ args: [String: JSONValue]) async throws(ServerError) -> JSONValue {
            if offline.withLock({ $0 }) { throw .unreachable }
            paths.withLock { $0.append(path) }
            return try await server.call(kind, path, args)
        }
    }

    private var base: URL!
    private var network: Network!
    private var backend: DebugEventBackend!
    private var groupFilms: GroupFilms!

    override func setUp() async throws {
        base = FileManager.default.temporaryDirectory.appending(path: "GroupFilmsTests-\(UUID().uuidString)")
        let server = DebugHostingServer(accountName: nil)
        backend = DebugEventBackend()
        backend.seedOpenEvent(code: DebugGroupFilms.openCode)
        server.events = backend
        network = Network(server)
        let signIn = DebugHostSignIn(server: server, signedIn: false)
        let hosting = HostingSession(signIn: signIn, functions: network,
                                     defaults: UserDefaults(suiteName: "GroupFilmsTests-\(UUID().uuidString)")!)
        groupFilms = try GroupFilmsSetup.make(hosting: hosting, base: base, identities: MemoryGuestIdentityStore(),
                                              joinHost: DebugGroupFilms.joinHost, supportAddress: nil)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: base)
    }

    private func joined() async throws -> (eventID: String, filmID: UUID) {
        let ok = await groupFilms.join(code: DebugGroupFilms.openCode, guestName: "Jo")
        XCTAssertTrue(ok, groupFilms.notice ?? "")
        let place = try XCTUnwrap(groupFilms.places.first)
        return (place.eventID, try XCTUnwrap(place.rollFilmID))
    }

    /// Saves a capture through the real capture commit path, as the shooting screen's backend does.
    private func shoot(_ filmID: UUID) async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900)).image { context in
            UIColor(hue: .random(in: 0...1), saturation: 0.6, brightness: 0.7, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
            UIColor.white.setFill()
            context.fill(CGRect(x: 300, y: 200, width: 400, height: 300))
        }
        let source = FileManager.default.temporaryDirectory.appending(path: "capture-\(UUID().uuidString).jpg")
        try XCTUnwrap(image.jpegData(compressionQuality: 0.9)).write(to: source)
        let receiver = try await groupFilms.rolls.trial.receiver(filmID: filmID)
        try await receiver.commit(.photoSaved(source))
        groupFilms.rolls.refresh()
    }

    private func source(_ filmID: UUID, _ sequence: Int) throws -> StoredMediaAsset? {
        try groupFilms.rolls.repository.mediaAsset(filmID: filmID, sequenceNumber: sequence, kind: .source)
    }

    func testAGuestShootsOfflineAndEveryPictureUploadsAndItsOriginalGoesOnceStored() async throws {
        let (eventID, filmID) = try await joined()
        network.offline.withLock { $0 = true }
        try await shoot(filmID)
        try await shoot(filmID)
        await groupFilms.developPending()
        XCTAssertEqual(groupFilms.waiting[eventID], 2, "Both pictures developed offline and wait")
        await groupFilms.uploadPass()
        XCTAssertEqual(groupFilms.waiting[eventID], 2, "Nothing is lost while the server cannot be reached")
        XCTAssertNotNil(try source(filmID, 1), "The original stays until the server has the picture")
        let sealed = try XCTUnwrap(groupFilms.rolls.film(filmID)).captures.map(\.revealState)
        XCTAssertEqual(sealed, [.sealed, .sealed], "Nobody sees a Disposable picture before the reveal, its shooter included")

        network.offline.withLock { $0 = false }
        await groupFilms.uploadPass()
        XCTAssertEqual(groupFilms.waiting[eventID] ?? 0, 0)
        XCTAssertEqual(groupFilms.sent[eventID], 2)
        XCTAssertNil(try source(filmID, 1), "The original goes once the server has the picture whole")
        XCTAssertNil(try source(filmID, 2))
        XCTAssertEqual(groupFilms.rolls.film(filmID)?.remainingExposures, 25, "The exposures stay used")
        XCTAssertEqual(network.paths.withLock { $0.filter { $0 == "pictures:requestUpload" }.count }, 2)
    }

    func testWithdrawingOfflineDeletesWhatWaitsAtOnceAndTellsTheServerLater() async throws {
        let (eventID, filmID) = try await joined()
        network.offline.withLock { $0 = true }
        try await shoot(filmID)
        await groupFilms.developPending()
        XCTAssertEqual(groupFilms.waiting[eventID], 1)
        await groupFilms.withdraw(eventID)
        XCTAssertEqual(groupFilms.waiting[eventID] ?? 0, 0, "A withdrawn picture that waited never uploads")
        XCTAssertEqual(groupFilms.rolls.film(filmID)?.captures.map(\.revealState), [.discardedPlaceholder])
        XCTAssertEqual(groupFilms.place(eventID)?.pendingWithdrawal, 1)
        network.offline.withLock { $0 = false }
        await groupFilms.sync(eventID)
        XCTAssertNil(groupFilms.place(eventID)?.pendingWithdrawal)
        XCTAssertTrue(network.paths.withLock { $0.contains("joining:withdraw") })
        XCTAssertEqual(groupFilms.rolls.film(filmID)?.remainingExposures, 26, "No exposure comes back")
    }

    func testARemovedGuestsPhoneDeletesItsWaitingPicturesWhenItNextComesOnline() async throws {
        let (eventID, filmID) = try await joined()
        network.offline.withLock { $0 = true }
        try await shoot(filmID)
        await groupFilms.developPending()
        // The Host removes Jo while Jo's phone is offline.
        _ = try backend.call("hosting:removeGuest", ["membershipId": "member-1"], signedIn: true, accountName: "Maya")
        network.offline.withLock { $0 = false }
        await groupFilms.sync(eventID)
        XCTAssertEqual(groupFilms.place(eventID)?.place, .removed)
        XCTAssertEqual(groupFilms.waiting[eventID] ?? 0, 0)
        XCTAssertNil(try source(filmID, 1))
    }

    func testAnEventRollNeverUsesTheTrialAndLivesApartFromPersonalFilms() async throws {
        let (_, filmID) = try await joined()
        // The Group Films' Journal refuses every Trial use (NoTrialStore), so a save that touched the Trial would fail.
        try await shoot(filmID)
        XCTAssertEqual(groupFilms.rolls.film(filmID)?.savedCaptureCount, 1)
        XCTAssertEqual(try groupFilms.rolls.repository.filmAccess(filmID: filmID), .groupRoll(eventID: "event-open"))
        XCTAssertTrue(groupFilms.rollsRoot.path.hasPrefix(base.path), "Event Rolls live in their own store")
        XCTAssertEqual(groupFilms.rolls.packEndOriginalQuestion(filmID), [], "Event originals have no question")
        let trialState = try await groupFilms.rolls.trial.state()
        XCTAssertEqual(trialState, .unused)
    }
}
