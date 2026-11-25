import Foundation
@testable import ImmerseServer
import Synchronization
import XCTest

/// Server functions answered in memory, recording each call.
final class FakeFunctions: ServerFunctions, @unchecked Sendable {
    typealias Handler = @Sendable (FunctionKind, String, [String: JSONValue]) throws(ServerError) -> JSONValue
    private let state: Mutex<[(kind: FunctionKind, path: String, args: [String: JSONValue])]> = Mutex([])
    private let handler: Handler

    init(_ handler: @escaping Handler) { self.handler = handler }

    var calls: [(kind: FunctionKind, path: String, args: [String: JSONValue])] { state.withLock { $0 } }

    func call(_ kind: FunctionKind, _ path: String, _ args: [String: JSONValue]) async throws(ServerError) -> JSONValue {
        state.withLock { $0.append((kind, path, args)) }
        return try handler(kind, path, args)
    }
}

private let summary: JSONValue = [
    "eventId": "e1", "title": "Ana & Leo", "hostName": "Maya", "hostLeft": false, "camera": "6x6", "filmStock": "blackAndWhite",
    "exposuresPerRoll": 12, "phase": "open", "startsAt": .null, "opensAt": 1_000, "endsAt": 86_401_000, "revealDelayMs": 3_600_000,
    "revealsAt": 90_001_000, "albumEndsAt": 31_626_001_000, "albumNotice": "none", "joiningPaused": false,
]

private func merged(_ base: JSONValue, _ extra: [String: JSONValue]) -> JSONValue {
    guard case .object(var object) = base else { return base }
    for (key, value) in extra { object[key] = value }
    return .object(object)
}

final class EventServerTests: XCTestCase {
    func testLoadFilmSendsTheSetupInTheServersUnits() async throws {
        let functions = FakeFunctions { _, _, _ in ["eventId": "e1", "joinCode": "abcdefghijklmnopqrstuv"] }
        let server = EventServer(functions: functions)
        let ends = Date(timeIntervalSince1970: 1_000)
        let loaded = try await server.loadFilm(EventSetup(title: "Ana & Leo", camera: .sixBySix, filmStock: .color, rolls: 3,
                                                          startsAt: nil, endsAt: ends, revealDelay: 3_600,
                                                          treatmentVersion: "film-look-5"), requestID: "r".padding(toLength: 16, withPad: "x", startingAt: 0))
        XCTAssertEqual(loaded, LoadedEvent(eventId: "e1", joinCode: "abcdefghijklmnopqrstuv"))
        let call = try XCTUnwrap(functions.calls.first)
        XCTAssertEqual(call.path, "hosting:create")
        XCTAssertEqual(call.args["camera"], "6x6")
        XCTAssertEqual(call.args["filmStock"], "color")
        XCTAssertEqual(call.args["endsAt"], .number(1_000_000))
        XCTAssertEqual(call.args["revealDelayMs"], .number(3_600_000))
        XCTAssertNil(call.args["startsAt"])
    }

    func testTheHostViewAndPreviewDecode() async throws {
        let functions = FakeFunctions { _, path, _ in
            switch path {
            case "hosting:view":
                return merged(summary, [
                    "joinCode": "abcdefghijklmnopqrstuv", "joinCodeGeneration": 2,
                    "rolls": ["setAside": 3, "taken": 1, "free": 2, "limit": 200], "picturesArrived": 4,
                    "guests": [["membershipId": "m1", "name": "Jo", "exposuresUsed": 5, "status": "joined", "isHost": false]],
                    "reports": [["reportId": "r1", "pictureId": "p1", "reason": "privacy", "at": 2_000]],
                ])
            default:
                return ["status": "paused", "event": summary, "place": "none", "isHost": false]
            }
        }
        let server = EventServer(functions: functions)
        let view = try await server.hostView(eventID: "e1")
        XCTAssertEqual(view.summary.camera, .sixBySix)
        XCTAssertEqual(view.summary.filmStock, .blackAndWhite)
        XCTAssertEqual(view.summary.endsAt, Date(timeIntervalSince1970: 86_401))
        XCTAssertEqual(view.rolls?.free, 2)
        XCTAssertEqual(view.guests.first?.name, "Jo")
        XCTAssertEqual(view.reports.first?.reason, .privacy)
        let preview = try await server.preview(code: "abcdefghijklmnopqrstuv", as: .guest(GuestIdentity(publicId: "p", secret: "s")))
        XCTAssertEqual(preview.status, .paused)
        XCTAssertEqual(functions.calls.last?.args["guest"], ["publicId": "p", "secret": "s"])
    }

    func testAGuestsCallsCarryItsTokenAndARefusedTokenIsReplacedOnce() async throws {
        let issued = Mutex(0)
        let functions = FakeFunctions { _, path, args throws(ServerError) in
            switch path {
            case "guests:startSession":
                let count = issued.withLock { $0 += 1; return $0 }
                return ["token": .string("token-\(count)"), "expiresAt": .number(Date.now.addingTimeInterval(3_600).timeIntervalSince1970 * 1000)]
            case "joining:leave":
                if args["guestToken"] == "token-1" { throw .refused(.guestTokenRefused) }
                return ["left": true]
            default:
                return .null
            }
        }
        let server = EventServer(functions: functions)
        try await server.leave(eventID: "e1", as: .guest(GuestIdentity(publicId: "p", secret: "s")))
        XCTAssertEqual(functions.calls.map(\.path), ["guests:startSession", "joining:leave", "guests:startSession", "joining:leave"])
        XCTAssertEqual(functions.calls.last?.args["guestToken"], "token-2")
        // The fresh token is kept for the next call.
        try await server.leave(eventID: "e1", as: .guest(GuestIdentity(publicId: "p", secret: "s")))
        XCTAssertEqual(functions.calls.count, 5)
    }

    func testJoiningKeepsTheGuestTokenItWasGiven() async throws {
        let functions = FakeFunctions { _, path, _ in
            path == "joining:join"
                ? ["event": summary, "membershipId": "m1", "guestName": "Jo", "exposuresUsed": 0, "withdrawnThrough": 0,
                   "guestToken": "joined-token", "guestTokenExpiresAt": .number(Date.now.addingTimeInterval(3_600).timeIntervalSince1970 * 1000)]
                : ["left": true]
        }
        let server = EventServer(functions: functions)
        let place = try await server.join(code: "abcdefghijklmnopqrstuv", guestName: "Jo", as: .guest(.make()))
        XCTAssertEqual(place.event.exposuresPerRoll, 12)
        try await server.leave(eventID: "e1", as: .guest(.make()))
        XCTAssertEqual(functions.calls.last?.args["guestToken"], "joined-token")
    }

    func testTheAlbumDecodesPicturesAndGaps() async throws {
        let functions = FakeFunctions { _, _, _ in
            ["camera": "disposable", "isHost": false, "entries": [
                ["number": 1, "removed": true],
                ["number": 2, "removed": false, "pictureId": "p2", "exposureNumber": 3, "shooterName": "Jo", "captureTime": 5_000,
                 "contentType": "image/jpeg", "size": 10, "sha256": "x", "url": "https://r2.test/a", "viewUrl": "https://r2.test/b",
                 "expiresAt": 9_000, "mine": true],
            ]]
        }
        let album = try await EventServer(functions: functions).album(eventID: "e1", as: .account)
        XCTAssertEqual(album.entries.map(\.number), [1, 2])
        guard case .gap = album.entries[0], case .picture(let picture) = album.entries[1] else { return XCTFail("Wrong entries") }
        XCTAssertEqual(picture.shooterName, "Jo")
        XCTAssertTrue(picture.mine)
        XCTAssertEqual(picture.capturedAt, Date(timeIntervalSince1970: 5))
    }

    func testEveryNewRefusalCodeIsNamed() {
        for code in ["notTheHost", "unknownCode", "codeReplaced", "notYetOpen", "joiningPaused", "rollsTaken", "shootingEnded",
                     "removedFromEvent", "rollLimit", "balanceTooLow", "notRevealed", "alreadyRevealed", "identityClaimed"] {
            if case .other = RefusalCode(code) { XCTFail("\(code) is not named") }
        }
    }
}

final class JoinLinkTests: XCTestCase {
    func testTheLinkCarriesTheCodeAndNothingElse() throws {
        let url = try XCTUnwrap(JoinLink.url(code: "abcdefghijklmnopqrstuv", host: "join.example"))
        XCTAssertEqual(url.absoluteString, "https://join.example/j/abcdefghijklmnopqrstuv")
        XCTAssertEqual(JoinLink.code(in: url, host: "join.example"), "abcdefghijklmnopqrstuv")
        XCTAssertEqual(JoinLink.code(in: URL(string: "https://JOIN.example/j/abcdefghijklmnopqrstuv")!, host: "join.example"),
                       "abcdefghijklmnopqrstuv")
    }

    func testAnythingElseIsNotAJoinLink() {
        for text in ["http://join.example/j/abcdefghijklmnopqrstuv", "https://other.example/j/abcdefghijklmnopqrstuv",
                     "https://join.example/x/abcdefghijklmnopqrstuv", "https://join.example/j/short",
                     "https://join.example/j/abcdefghijklmnopqrstuv/extra", "https://join.example/j/abcdefghijklmnopqrstu!"] {
            XCTAssertNil(JoinLink.code(in: URL(string: text)!, host: "join.example"), text)
        }
    }

    func testTheJoinHostAndSupportAddressAreOptionalConfiguration() {
        let base: [String: Any] = ["ImmerseConvexURL": "https://a.convex.cloud", "ImmerseClerkPublishableKey": ServerConfigurationTests.key]
        XCTAssertNil(ServerConfiguration(infoDictionary: base)?.joinHost)
        var full = base
        full["ImmerseJoinHost"] = "Join.Example"
        full["ImmerseSupportAddress"] = "support@example.org"
        XCTAssertEqual(ServerConfiguration(infoDictionary: full)?.joinHost, "join.example")
        XCTAssertEqual(ServerConfiguration(infoDictionary: full)?.supportAddress, "support@example.org")
        full["ImmerseJoinHost"] = "$(IMMERSE_JOIN_HOST)"
        full["ImmerseSupportAddress"] = "$(IMMERSE_SUPPORT_ADDRESS)"
        XCTAssertNil(ServerConfiguration(infoDictionary: full)?.joinHost)
        XCTAssertNil(ServerConfiguration(infoDictionary: full)?.supportAddress)
    }
}

final class GuestIdentityTests: XCTestCase {
    func testAnIdentityIsMadeOnceAndKept() throws {
        let store = MemoryGuestIdentityStore()
        let first = try store.identity()
        XCTAssertEqual(try store.identity(), first)
        XCTAssertEqual(first.publicId.count, 24)
        XCTAssertEqual(first.secret.count, 43)
        XCTAssertNotEqual(GuestIdentity.make(), GuestIdentity.make())
        try store.delete()
        XCTAssertNotEqual(try store.identity(), first)
    }
}

/// A sender whose outcome per exposure a test chooses.
final class ScriptedSender: QueuedPictureSending, @unchecked Sendable {
    private let outcomes: Mutex<[Int: Result<SendOutcome, PictureUploader.UploadError>]>
    let sent = Mutex<[Int]>([])

    init(_ outcomes: [Int: Result<SendOutcome, PictureUploader.UploadError>]) { self.outcomes = Mutex(outcomes) }

    func send(_ picture: QueuedPicture, file: URL, view: URL?) async throws -> SendOutcome {
        sent.withLock { $0.append(picture.exposureNumber) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        XCTAssertNotNil(view)
        let outcome = outcomes.withLock { $0[picture.exposureNumber] } ?? .success(.stored)
        return try outcome.get()
    }
}

final class UploadQueueTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appending(path: "upload-queue-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func queue(_ count: Int, event: String = "e1") async throws -> UploadQueue {
        let queue = try UploadQueue(directory: directory)
        for exposure in 1...count {
            try await queue.enqueue(eventID: event, exposureNumber: exposure, captureTime: Date(timeIntervalSince1970: Double(10 - exposure)),
                                    developed: Data("picture \(exposure)".utf8), view: Data("view \(exposure)".utf8))
        }
        return queue
    }

    func testQueuedPicturesSurviveARestartAndGoInCaptureOrder() async throws {
        _ = try await queue(3)
        // A new queue over the same folder, as after the app was killed.
        let reopened = try UploadQueue(directory: directory)
        let pending = await reopened.pending()
        XCTAssertEqual(pending.map(\.exposureNumber), [3, 2, 1])
        // Queuing an exposure again keeps the first copy.
        try await reopened.enqueue(eventID: "e1", exposureNumber: 1, captureTime: .now, developed: Data("other".utf8), view: nil)
        let first = await reopened.developedFile(of: try XCTUnwrap(pending.last))
        XCTAssertEqual(try Data(contentsOf: first), Data("picture 1".utf8))
    }

    func testStoredAndRefusedPicturesLeaveAndFailuresStay() async throws {
        let queue = try await queue(4)
        let sender = ScriptedSender([
            2: .failure(.notConfirmed),
            3: .success(.refused(.afterEndTime)),
        ])
        let results = await queue.run(using: sender)
        XCTAssertEqual(results.count, 3)
        let left = await queue.pending()
        XCTAssertEqual(left.map(\.exposureNumber), [2])
        guard case .refused(let refused, .afterEndTime) = results.first(where: { if case .refused = $0 { true } else { false } }) else {
            return XCTFail("Expected the refused picture")
        }
        XCTAssertEqual(refused.exposureNumber, 3)
    }

    func testAPassStopsWhenTheServerCannotBeReached() async throws {
        let queue = try await queue(3)
        let sender = ScriptedSender([3: .failure(.server(.unreachable))])
        let results = await queue.run(using: sender)
        XCTAssertEqual(results, [])
        XCTAssertEqual(sender.sent.withLock { $0 }, [3])
        let left = await queue.pending()
        XCTAssertEqual(left.count, 3)
    }

    func testWithdrawingRemovesAnEventsWaitingPicturesUpToAnExposure() async throws {
        let queue = try await queue(4)
        try await queue.enqueue(eventID: "e2", exposureNumber: 1, captureTime: .now, developed: Data("x".utf8), view: nil)
        let removed = try await queue.removeAll(eventID: "e1", throughExposure: 3)
        XCTAssertEqual(removed.map(\.exposureNumber).sorted(), [1, 2, 3])
        let left = await queue.pending()
        XCTAssertEqual(left.map(\.id).sorted(), ["e1-4", "e2-1"])
    }

    func testAHalfWrittenFolderLeftByACrashIsCleared() async throws {
        let queue = try await queue(1)
        let staging = directory.appending(path: ".staging-crashed")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let left = await queue.pending()
        XCTAssertEqual(left.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.path))
    }
}

final class PictureUploaderViewCopyTests: XCTestCase {
    func testTheViewingCopyIsAnnouncedSentAndConfirmedWithThePicture() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "uploader-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let picture = directory.appending(path: "p.jpg")
        let view = directory.appending(path: "v.jpg")
        try Data(repeating: 1, count: 2_000).write(to: picture)
        try Data(repeating: 2, count: 300).write(to: view)
        let session = StubNetwork.session { recorded in
            if recorded.method == "PUT" { return (200, Data()) }
            let call = convexCall(recorded)
            if call?.path == "pictures:requestUpload" {
                let announced = call?.args["view"] as? [String: Any]
                XCTAssertEqual(announced?["size"] as? Int, 300)
                return success(["status": "upload", "url": "https://r2.test/p", "method": "PUT", "headers": ["Content-Type": "image/jpeg"],
                                "view": ["url": "https://r2.test/v", "method": "PUT", "headers": ["Content-Type": "image/jpeg"]],
                                "expiresAt": 1])
            }
            return success(["status": "stored"])
        }
        let client = ConvexHTTPClient(deploymentURL: URL(string: "https://e.convex.cloud")!, session: session) { "t" }
        let outcome = try await PictureUploader(functions: client, session: session)
            .send(PictureToSend(eventID: "e1", exposureNumber: 1, captureTime: .now, fileURL: picture, viewFileURL: view))
        XCTAssertEqual(outcome, .stored)
        let puts = StubNetwork.recorded.filter { $0.method == "PUT" }
        XCTAssertEqual(puts.map(\.url.absoluteString), ["https://r2.test/p", "https://r2.test/v"])
        XCTAssertEqual(puts.map(\.body.count), [2_000, 300])
    }
}
