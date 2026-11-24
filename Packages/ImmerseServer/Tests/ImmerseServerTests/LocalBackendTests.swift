import Foundation
import ImmerseServer
import XCTest

/// The iPhone's own client against Convex's local backend and the R2 stand-in: Convex's HTTP API with a Clerk-style
/// session token, and a picture-sized file sent with URLSession to a real presigned address, confirmed by size and
/// checksum (open check OC-3). The backend's end-to-end run (`Backend/local-backend/stage1.test.ts`) starts the stand-ins
/// and runs this with their addresses; on its own, with none given, it is skipped.
final class LocalBackendTests: XCTestCase {
    private struct Stand: Sendable {
        let convexURL: URL
        let sessionToken: String
        let eventID: String
    }

    private func stand() throws -> Stand {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["IMMERSE_LOCAL_CONVEX_URL"].flatMap(URL.init(string:)),
              let token = environment["IMMERSE_LOCAL_SESSION_TOKEN"], let event = environment["IMMERSE_LOCAL_EVENT_ID"]
        else { throw XCTSkip("Run by Backend/local-backend/stage1.test.ts, which starts the local stand-ins") }
        return Stand(convexURL: url, sessionToken: token, eventID: event)
    }

    func testThePhonesClientSendsAPictureSizedFileThroughAOneTimeAddress() async throws {
        let stand = try stand()
        let token = stand.sessionToken
        let functions = ConvexHTTPClient(deploymentURL: stand.convexURL) { token }
        let state = try await AccountServer(functions: functions).state()
        guard case .signedIn = state else { return XCTFail("Expected a signed-in Account, got \(state)") }

        let file = FileManager.default.temporaryDirectory.appending(path: "local-backend-\(UUID().uuidString).jpg")
        var bytes = [UInt8](repeating: 0, count: 4 << 20)
        for index in stride(from: 0, to: bytes.count, by: 8) { bytes[index] = UInt8.random(in: 0...255) }
        try Data(bytes).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let picture = PictureToSend(eventID: stand.eventID, exposureNumber: 2, captureTime: .now, fileURL: file)
        let uploader = PictureUploader(functions: functions)
        let first = try await uploader.send(picture)
        XCTAssertEqual(first, .stored)
        // Sent again after a lost reply, the server answers that it already has it.
        let again = try await uploader.send(picture)
        XCTAssertEqual(again, .stored)

        // Sealed: no read address before the reveal.
        do {
            _ = try await functions.call(.action, "reads:album", ["eventId": .string(stand.eventID)])
            XCTFail("A sealed event gave read addresses")
        } catch {
            XCTAssertEqual(error, .refused(.sealed))
        }
        // A request without the session is refused as signed out.
        let anonymous = ConvexHTTPClient(deploymentURL: stand.convexURL) { nil }
        do {
            try await AccountServer(functions: anonymous).setDisplayName("X")
            XCTFail("A request without a session was accepted")
        } catch {
            XCTAssertEqual(error, .refused(.unauthenticated))
        }
    }

    /// A guest with no Account, on the phone's own client: joins through the Join Code the Host's view gives, sends a
    /// picture and its viewing copy with its guest token, and is refused the album before the reveal.
    func testAGuestJoinsWithItsIdentityAndSendsAPictureWithItsViewingCopy() async throws {
        let stand = try stand()
        let token = stand.sessionToken
        let host = EventServer(functions: ConvexHTTPClient(deploymentURL: stand.convexURL) { token })
        let hostView = try await host.hostView(eventID: stand.eventID)
        let code = try XCTUnwrap(hostView.joinCode)

        let anonymous = ConvexHTTPClient(deploymentURL: stand.convexURL) { nil }
        let guests = EventServer(functions: anonymous)
        let identity = GuestIdentity.make()
        let preview = try await guests.preview(code: code, as: .guest(identity))
        XCTAssertEqual(preview.status, .open)
        let place = try await guests.join(code: code, guestName: "Jo", as: .guest(identity))
        XCTAssertEqual(place.event.eventId, stand.eventID)

        let directory = FileManager.default.temporaryDirectory.appending(path: "local-backend-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let picture = directory.appending(path: "developed.jpg")
        let view = directory.appending(path: "view.jpg")
        try Data((0..<(512 << 10)).map { UInt8(truncatingIfNeeded: $0 &* 31) }).write(to: picture)
        try Data((0..<(32 << 10)).map { UInt8(truncatingIfNeeded: $0 &* 7) }).write(to: view)
        let guestToken = try await guests.guestToken(eventID: stand.eventID, as: .guest(identity))
        let outcome = try await PictureUploader(functions: anonymous).send(
            PictureToSend(eventID: stand.eventID, exposureNumber: 1, captureTime: .now, fileURL: picture, viewFileURL: view,
                          guestToken: guestToken))
        XCTAssertEqual(outcome, .stored)
        let mine = try await guests.memberView(eventID: stand.eventID, as: .guest(identity))
        XCTAssertEqual(mine.storedExposures, [1])
        do {
            _ = try await guests.album(eventID: stand.eventID, as: .guest(identity))
            XCTFail("A sealed album was given to a guest")
        } catch {
            XCTAssertEqual(error, .refused(.sealed))
        }
    }
}
