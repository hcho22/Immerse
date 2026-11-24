import Foundation
import ImmerseServer
import XCTest

/// The hand-off from the mini-app to the full app against Convex's local backend and the R2 stand-in (v2 PRD V2-FR-19,
/// V2-FR-35): a guest joins as the mini-app does, queues three pictures in the folder the two apps share, sends one and
/// loses the connection. The full app then starts as a new process would, with nothing in memory: a new client, the
/// same folder, and the guest identity the mini-app made. It sends what waits, and the server holds every picture once,
/// under the same place. The backend's end-to-end run (`Backend/local-backend/stage3.test.ts`) starts the stand-ins and
/// runs this with their addresses; on its own, with none given, it is skipped.
final class HandOffLocalBackendTests: XCTestCase {
    /// Sends queued pictures as a guest, and loses the connection after `limit` of them.
    private actor Sender: QueuedPictureSending {
        private let server: EventServer
        private let uploader: PictureUploader
        private let identity: GuestIdentity
        private var left: Int

        init(functions: any ServerFunctions, identity: GuestIdentity, limit: Int = .max) {
            server = EventServer(functions: functions)
            uploader = PictureUploader(functions: functions)
            self.identity = identity
            left = limit
        }

        func send(_ picture: QueuedPicture, file: URL, view: URL?) async throws -> SendOutcome {
            guard left > 0 else { throw PictureUploader.UploadError.server(.unreachable) }
            left -= 1
            let token = try await server.guestToken(eventID: picture.eventID, as: .guest(identity))
            return try await uploader.send(PictureToSend(eventID: picture.eventID, exposureNumber: picture.exposureNumber,
                                                         captureTime: picture.captureTime, contentType: picture.contentType,
                                                         fileURL: file, viewFileURL: view, guestToken: token))
        }
    }

    func testAMiniAppGuestsQueueGoesOnFromTheFullAppAndTheServerHoldsEachPictureOnce() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["IMMERSE_LOCAL_CONVEX_URL"].flatMap(URL.init(string:)),
              let code = environment["IMMERSE_LOCAL_HANDOFF_CODE"]
        else { throw XCTSkip("Run by Backend/local-backend/stage3.test.ts, which starts the local stand-ins") }
        let folder = FileManager.default.temporaryDirectory.appending(path: "hand-off-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let uploads = folder.appending(path: "Uploads", directoryHint: .isDirectory)
        // The mini-app's Keychain item, which the full app reads once it is installed.
        let miniAppIdentity = MemoryGuestIdentityStore()

        // The mini-app: no session, a guest identity of its own, the shared folder.
        let identity = try miniAppIdentity.identity()
        let miniApp = ConvexHTTPClient(deploymentURL: url) { nil }
        let place = try await EventServer(functions: miniApp).join(code: code, guestName: "Lee", as: .guest(identity))
        let eventID = place.event.eventId
        let queue = try UploadQueue(directory: uploads)
        let taken = Date.now.addingTimeInterval(-60)
        var pictures: [Data] = []
        for exposure in 1...3 {
            let developed = Data((0..<(96 << 10)).map { UInt8(truncatingIfNeeded: $0 &* (exposure + 30)) })
            let view = Data((0..<(8 << 10)).map { UInt8(truncatingIfNeeded: $0 &* (exposure + 6)) })
            pictures.append(developed)
            try await queue.enqueue(eventID: eventID, exposureNumber: exposure, captureTime: taken.addingTimeInterval(Double(exposure)),
                                    developed: developed, view: view)
        }
        let sentByTheMiniApp = await queue.run(using: Sender(functions: miniApp, identity: identity, limit: 1))
        XCTAssertEqual(sentByTheMiniApp.count, 1)
        let stillWaiting = await queue.pending().map(\.exposureNumber)
        XCTAssertEqual(stillWaiting, [2, 3])

        // The full app, installed afterwards: a new client and queue on the same folder, and the mini-app's identity.
        let handedOver = try XCTUnwrap(try miniAppIdentity.read())
        XCTAssertEqual(handedOver, identity)
        let fullApp = ConvexHTTPClient(deploymentURL: url) { nil }
        let appQueue = try UploadQueue(directory: uploads)
        let found = await appQueue.pending().map(\.exposureNumber)
        XCTAssertEqual(found, [2, 3], "The pictures not yet sent are waiting for the full app")
        let sentByTheFullApp = await appQueue.run(using: Sender(functions: fullApp, identity: handedOver))
        XCTAssertEqual(sentByTheFullApp.count, 2)
        let leftWaiting = await appQueue.pending()
        XCTAssertEqual(leftWaiting, [])

        // The server holds each picture once, under the place the mini-app took.
        let server = EventServer(functions: fullApp)
        let mine = try await server.memberView(eventID: eventID, as: .guest(handedOver))
        XCTAssertEqual(mine.storedExposures.sorted(), [1, 2, 3])
        XCTAssertEqual(mine.membershipId, place.membershipId)
        XCTAssertEqual(mine.guestName, "Lee")
        // The same link in the full app finds the guest already in, and joining again gives the same place.
        let preview = try await server.preview(code: code, as: .guest(handedOver))
        XCTAssertEqual(preview.status, .member)
        let again = try await server.join(code: code, guestName: "", as: .guest(handedOver))
        XCTAssertEqual(again.membershipId, place.membershipId)
        // A picture the mini-app had sent, queued again by mistake, is answered as held: nothing is stored twice.
        try await appQueue.enqueue(eventID: eventID, exposureNumber: 1, captureTime: taken.addingTimeInterval(1),
                                   developed: pictures[0], view: nil)
        let repeated = await appQueue.run(using: Sender(functions: fullApp, identity: handedOver))
        XCTAssertEqual(repeated.count, 1)
        if case .stored = repeated.first {} else { XCTFail("The server did not answer that it holds the picture") }
        let after = try await server.memberView(eventID: eventID, as: .guest(handedOver))
        XCTAssertEqual(after.storedExposures.sorted(), [1, 2, 3])
    }
}
