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
            _ = try await functions.call(.action, "reads:readAddresses", ["eventId": .string(stand.eventID)])
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
}
