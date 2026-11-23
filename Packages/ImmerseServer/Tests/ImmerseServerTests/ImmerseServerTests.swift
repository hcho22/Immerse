import CryptoKit
import Foundation
import ImmerseServer
import XCTest

final class ServerConfigurationTests: XCTestCase {
    func testAbsentOrMalformedConfigurationMeansNoServer() {
        XCTAssertNil(ServerConfiguration(infoDictionary: [:]))
        XCTAssertNil(ServerConfiguration(infoDictionary: ["ImmerseConvexURL": "", "ImmerseClerkPublishableKey": ""]))
        XCTAssertNil(ServerConfiguration(infoDictionary: ["ImmerseConvexURL": "https://a.convex.cloud", "ImmerseClerkPublishableKey": ""]))
        XCTAssertNil(ServerConfiguration(infoDictionary: ["ImmerseConvexURL": "https://a.convex.cloud", "ImmerseClerkPublishableKey": "secret"]))
        XCTAssertNil(ServerConfiguration(infoDictionary: ["ImmerseConvexURL": "http://a.convex.cloud", "ImmerseClerkPublishableKey": "pk_test_x"]))
        // An unexpanded build setting, as a build without the local configuration file leaves it.
        XCTAssertNil(ServerConfiguration(infoDictionary: ["ImmerseConvexURL": "$(IMMERSE_CONVEX_URL)", "ImmerseClerkPublishableKey": "$(IMMERSE_CLERK_PUBLISHABLE_KEY)"]))
    }

    func testAnHTTPSDeploymentOrALocalBackendIsAccepted() {
        let cloud = ServerConfiguration(infoDictionary: ["ImmerseConvexURL": "https://a.convex.cloud", "ImmerseClerkPublishableKey": "pk_test_x"])
        XCTAssertEqual(cloud?.convexURL.absoluteString, "https://a.convex.cloud")
        XCTAssertNotNil(ServerConfiguration(infoDictionary: ["ImmerseConvexURL": "http://127.0.0.1:3210", "ImmerseClerkPublishableKey": "pk_test_x"]))
    }
}

final class ConvexHTTPClientTests: XCTestCase {
    private let deployment = URL(string: "https://example.convex.cloud")!

    func testACallPostsThePathAndArgumentsWithTheSessionToken() async throws {
        let session = StubNetwork.session { _ in success(["state": "signedOut"]) }
        let client = ConvexHTTPClient(deploymentURL: deployment, session: session) { "session-token" }
        let reply = try await client.call(.query, "accounts:me", ["a": 1])
        XCTAssertEqual(reply["state"]?.string, "signedOut")
        let request = try XCTUnwrap(StubNetwork.recorded.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.absoluteString, "https://example.convex.cloud/api/query")
        XCTAssertEqual(request.headers["Authorization"], "Bearer session-token")
        let call = try XCTUnwrap(convexCall(request))
        XCTAssertEqual(call.path, "accounts:me")
        XCTAssertEqual(call.args["a"] as? Int, 1)
    }

    func testNoTokenMeansNoAuthorizationHeader() async throws {
        let session = StubNetwork.session { _ in success(NSNull()) }
        let client = ConvexHTTPClient(deploymentURL: deployment, session: session) { nil }
        _ = try await client.call(.mutation, "x:y", [:])
        XCTAssertNil(StubNetwork.recorded.first?.headers["Authorization"])
    }

    func testRefusalsCarryTheServersCode() async {
        let session = StubNetwork.session { _ in refusal("sealed") }
        let client = ConvexHTTPClient(deploymentURL: deployment, session: session) { nil }
        await assertThrows(.refused(.sealed)) { _ = try await client.call(.action, "reads:readAddresses", [:]) }
    }

    func testARejectedSessionTokenIsUnauthenticated() async {
        let session = StubNetwork.session { _ in (401, Data("Could not verify OIDC token claim".utf8)) }
        let client = ConvexHTTPClient(deploymentURL: deployment, session: session) { "expired" }
        await assertThrows(.refused(.unauthenticated)) { _ = try await client.call(.query, "accounts:me", [:]) }
    }

    func testNoNetworkIsUnreachableAndChangesNothing() async {
        let session = StubNetwork.session { _ in (0, Data()) }
        let client = ConvexHTTPClient(deploymentURL: deployment, session: session) { nil }
        await assertThrows(.unreachable) { _ = try await client.call(.query, "accounts:me", [:]) }
    }

    func testAServerErrorIsUnreachableAndAnUnknownErrorFails() async {
        var session = StubNetwork.session { _ in (503, Data()) }
        var client = ConvexHTTPClient(deploymentURL: deployment, session: session) { nil }
        await assertThrows(.unreachable) { _ = try await client.call(.query, "accounts:me", [:]) }
        session = StubNetwork.session { _ in (200, json(["status": "error", "errorMessage": "Server Error"])) }
        client = ConvexHTTPClient(deploymentURL: deployment, session: session) { nil }
        await assertThrows(.failed("Server Error")) { _ = try await client.call(.query, "accounts:me", [:]) }
    }
}

final class AccountServerTests: XCTestCase {
    private func server(_ handler: @escaping StubNetwork.Handler) -> AccountServer {
        let session = StubNetwork.session(handler: handler)
        return AccountServer(functions: ConvexHTTPClient(deploymentURL: URL(string: "https://e.convex.cloud")!, session: session) { "t" })
    }

    func testStatesAreRead() async throws {
        let signedIn = server { _ in success(["state": "signedIn", "account": ["displayName": "Maya", "ageConfirmedAt": 1_795_000_000_000, "createdAt": 1]]) }
        let first = try await signedIn.state()
        XCTAssertEqual(first, .signedIn(Account(displayName: "Maya", ageConfirmedAt: Date(timeIntervalSince1970: 1_795_000_000))))
        let second = try await server { _ in success(["state": "noAccount"]) }.state()
        XCTAssertEqual(second, .noAccount)
        let third = try await server { _ in success(["state": "accountDeleted"]) }.state()
        XCTAssertEqual(third, .accountDeleted)
    }

    func testCreatingAnAccountSendsOnlyThatAgeWasConfirmedAndHow() async throws {
        try await server { _ in success(["created": true]) }.createAccount(displayName: "Maya", confirmedBy: .birthMonthAndYear)
        let call = try XCTUnwrap(convexCall(try XCTUnwrap(StubNetwork.recorded.first)))
        XCTAssertEqual(call.path, "accounts:createAccount")
        XCTAssertEqual(call.args["ageConfirmed"] as? Bool, true)
        XCTAssertEqual(call.args["ageConfirmation"] as? String, "birthMonthAndYear")
        XCTAssertEqual(Set(call.args.keys), ["displayName", "ageConfirmed", "ageConfirmation"])
    }

    func testAPushTokenIsSentAsLowercaseHex() async throws {
        try await server { _ in success(["registered": true]) }.registerPushToken(Data([0xAB, 0x01, 0xFF]), installationID: "inst", environment: .sandbox)
        let call = try XCTUnwrap(convexCall(try XCTUnwrap(StubNetwork.recorded.first)))
        XCTAssertEqual(call.args["token"] as? String, "ab01ff")
        XCTAssertEqual(call.args["environment"] as? String, "sandbox")
    }

    func testDeleteAccountCallsTheServersDeletion() async throws {
        try await server { _ in success(["deleted": true]) }.deleteAccount()
        XCTAssertEqual(convexCall(try XCTUnwrap(StubNetwork.recorded.first))?.path, "deletion:deleteAccount")
        XCTAssertEqual(StubNetwork.recorded.first?.url.lastPathComponent, "action")
    }
}

final class PictureUploaderTests: XCTestCase {
    private var file: URL!
    private let bytes = Data((0..<300_000).map { UInt8($0 % 251) })
    private let storage = "https://account.r2.cloudflarestorage.com/immerse-pictures/pictures/e/k?X-Amz-Expires=300"

    override func setUpWithError() throws {
        file = FileManager.default.temporaryDirectory.appending(path: "picture-\(UUID().uuidString).jpg")
        try bytes.write(to: file)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: file)
    }

    private var sha256: String { Data(SHA256.hash(data: bytes)).base64EncodedString() }

    private func uploader(_ handler: @escaping StubNetwork.Handler) -> PictureUploader {
        let session = StubNetwork.session(handler: handler)
        return PictureUploader(functions: ConvexHTTPClient(deploymentURL: URL(string: "https://e.convex.cloud")!, session: session) { "t" },
                               session: session)
    }

    private func address() -> (status: Int, body: Data) {
        success(["status": "upload", "url": storage, "method": "PUT",
                 "headers": ["Content-Type": "image/jpeg", "x-amz-checksum-sha256": sha256], "expiresAt": 1])
    }

    private var picture: PictureToSend {
        PictureToSend(eventID: "event1", exposureNumber: 3, captureTime: Date(timeIntervalSince1970: 1_795_000_000.5), fileURL: file)
    }

    func testTheFingerprintIsTheSizeAndBase64SHA256() throws {
        let fingerprint = try PictureUploader.fingerprint(of: file)
        XCTAssertEqual(fingerprint.size, bytes.count)
        XCTAssertEqual(fingerprint.sha256, sha256)
    }

    func testAPictureIsAddressedSentWithTheSignedHeadersAndConfirmed() async throws {
        let address = address()
        let outcome = try await uploader { request in
            switch convexCall(request)?.path {
            case "pictures:requestUpload": return address
            case "pictures:confirmUpload": return success(["status": "stored"])
            default: return (200, Data())
            }
        }.send(picture)
        XCTAssertEqual(outcome, .stored)
        let recorded = StubNetwork.recorded
        XCTAssertEqual(recorded.count, 3)
        let request = try XCTUnwrap(convexCall(recorded[0]))
        XCTAssertEqual(request.args["size"] as? Int, bytes.count)
        XCTAssertEqual(request.args["sha256"] as? String, sha256)
        XCTAssertEqual(request.args["captureTime"] as? Double, 1_795_000_000_500)
        XCTAssertEqual(request.args["exposureNumber"] as? Int, 3)
        XCTAssertNil(request.args["guestToken"])
        XCTAssertEqual(recorded[1].method, "PUT")
        XCTAssertEqual(recorded[1].url.absoluteString, storage)
        XCTAssertEqual(recorded[1].headers["Content-Type"], "image/jpeg")
        XCTAssertEqual(recorded[1].headers["x-amz-checksum-sha256"], sha256)
        XCTAssertEqual(recorded[1].body, bytes)
        XCTAssertEqual(convexCall(recorded[2])?.path, "pictures:confirmUpload")
    }

    func testAPictureTheServerAlreadyHasIsNotSentAgain() async throws {
        let outcome = try await uploader { _ in success(["status": "stored"]) }.send(picture)
        XCTAssertEqual(outcome, .stored)
        XCTAssertEqual(StubNetwork.recorded.count, 1)
    }

    func testAnAddressStorageTurnsAwayIsReplacedWithAFreshOne() async throws {
        let address = address()
        let puts = Counter()
        let outcome = try await uploader { request in
            if request.method == "PUT" { return puts.next() == 1 ? (403, Data()) : (200, Data()) }
            return convexCall(request)?.path == "pictures:requestUpload" ? address : success(["status": "stored"])
        }.send(picture)
        XCTAssertEqual(outcome, .stored)
        XCTAssertEqual(StubNetwork.recorded.compactMap { convexCall($0)?.path }, ["pictures:requestUpload", "pictures:requestUpload", "pictures:confirmUpload"])
    }

    func testAMismatchSendsThePictureAgain() async throws {
        let address = address()
        let confirmations = Counter()
        let outcome = try await uploader { request in
            if request.method == "PUT" { return (200, Data()) }
            if convexCall(request)?.path == "pictures:requestUpload" { return address }
            return success(["status": confirmations.next() == 1 ? "mismatch" : "stored"])
        }.send(picture)
        XCTAssertEqual(outcome, .stored)
        XCTAssertEqual(StubNetwork.recorded.filter { $0.method == "PUT" }.count, 2)
    }

    func testAPictureNeverConfirmedStaysOnThePhone() async {
        let address = address()
        let uploader = uploader { request in
            if request.method == "PUT" { return (200, Data()) }
            return convexCall(request)?.path == "pictures:requestUpload" ? address : success(["status": "missing"])
        }
        do {
            _ = try await uploader.send(picture)
            XCTFail("expected the send to fail")
        } catch {
            XCTAssertEqual(error, .notConfirmed)
        }
    }

    func testARemovedPictureOrALateOneIsRefusedForGood() async throws {
        for code in ["pictureRemoved", "afterEndTime", "eventGone", "notAMember"] {
            let outcome = try await uploader { _ in refusal(code) }.send(picture)
            guard case .refused = outcome else { return XCTFail("\(code) should be refused for good") }
        }
    }

    func testLosingTheNetworkKeepsThePictureForLater() async {
        do {
            _ = try await uploader { _ in (0, Data()) }.send(picture)
            XCTFail("expected the send to fail")
        } catch {
            XCTAssertEqual(error, .server(.unreachable))
        }
    }

    func testAGuestSendsWithTheirToken() async throws {
        let guest = PictureToSend(eventID: "e", exposureNumber: 1, captureTime: .now, fileURL: file, guestToken: "guest-token")
        _ = try await uploader { _ in success(["status": "stored"]) }.send(guest)
        XCTAssertEqual(convexCall(try XCTUnwrap(StubNetwork.recorded.first))?.args["guestToken"] as? String, "guest-token")
    }
}

final class AgeGateTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testThirteenCountsFromTheMonthAfterTheThirteenthBirthdayMonth() {
        let today = date(2026, 11, 23)
        XCTAssertTrue(AgeGate.isOldEnough(birthYear: 2013, birthMonth: 10, on: today, calendar: calendar))
        XCTAssertFalse(AgeGate.isOldEnough(birthYear: 2013, birthMonth: 11, on: today, calendar: calendar))
        XCTAssertFalse(AgeGate.isOldEnough(birthYear: 2013, birthMonth: 12, on: today, calendar: calendar))
        XCTAssertFalse(AgeGate.isOldEnough(birthYear: 2014, birthMonth: 1, on: today, calendar: calendar))
        XCTAssertTrue(AgeGate.isOldEnough(birthYear: 1970, birthMonth: 6, on: today, calendar: calendar))
    }

    func testAMonthOutsideTheYearIsRefused() {
        XCTAssertFalse(AgeGate.isOldEnough(birthYear: 1990, birthMonth: 0, calendar: calendar))
        XCTAssertFalse(AgeGate.isOldEnough(birthYear: 1990, birthMonth: 13, calendar: calendar))
    }

    func testTheYearsOfferedRunBackFromThisYear() {
        let years = AgeGate.selectableYears(on: date(2026, 11, 23), calendar: calendar)
        XCTAssertEqual(years.first, 2026)
        XCTAssertEqual(years.last, 1906)
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
}

func assertThrows(_ expected: ServerError, file: StaticString = #filePath, line: UInt = #line,
                  _ body: () async throws -> Void) async {
    do {
        try await body()
        XCTFail("expected \(expected)", file: file, line: line)
    } catch let error as ServerError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("unexpected \(error)", file: file, line: line)
    }
}
