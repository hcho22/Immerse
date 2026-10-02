import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import NativeAdapters
import XCTest
@testable import ExportPrivacyHarness

@MainActor final class ExportPrivacyTests: XCTestCase {
    func testDefaultPreparationAndRecoveryNeverExportAllCameras() async throws {
        for camera in CameraID.allCases {
            let scenario = try ExportScenario(camera: camera, label: "default-no-export")
            try await scenario.prepare()
            let before = try await scenario.inventory("before-recovery")
            try await scenario.recover()
            let after = try await scenario.inventory("after-recovery")
            assertUsable(after, sources: 1)
            XCTAssertTrue(after.dispositions.isEmpty)
            XCTAssertTrue(after.externalFiles.isEmpty)
            XCTAssertEqual(after.development, before.development)
            XCTAssertEqual(assetHashes(after), assetHashes(before))
        }
    }

    func testPermissionAndSealedSelectionNeverDispatchWriter() async throws {
        for status in [PhotoLibraryAuthorizationStatus.denied, .restricted, .notDetermined] {
            let scenario = try ExportScenario(label: "permission-\(status)")
            try await scenario.prepare()
            let writer = try await scenario.makeWriter()
            do { try await scenario.export(writer: writer, authorization: status); XCTFail("Export unexpectedly succeeded") }
            catch let error as FilmExportError { XCTAssertEqual(error, status == .notDetermined ? .needsPermission : .permissionDenied) }
            let calls = await writer.attempts
            XCTAssertEqual(calls, 0)
            let result = try await scenario.inventory("permission-rejected")
            assertUsable(result, sources: 1)
            XCTAssertTrue(result.externalFiles.isEmpty)
        }
        let scenario = try ExportScenario(label: "sealed-reject")
        try await scenario.prepare(develop: false)
        let writer = try await scenario.makeWriter()
        do { try await scenario.export(writer: writer); XCTFail("Sealed export accepted") }
        catch PersistenceError.mediaNotRevealed { }
        let calls = await writer.attempts
        XCTAssertEqual(calls, 0)
        let result = try await scenario.inventory("sealed-rejected")
        XCTAssertEqual(result.films.first?.captures.first?.revealState, .sealed)
        XCTAssertEqual(result.assets.filter { $0.kind == "source" }.count, 1)
        XCTAssertTrue(result.dispositions.isEmpty)
    }

    func testFailedUnknownMissingAndCancelledRepliesPreserveMedia() async throws {
        for reply in [InjectedExportReply.failBeforeCopy, .failAfterCopy, .missingReceipt, .cancelled] {
            let scenario = try ExportScenario(label: "reply-\(reply.rawValue)")
            try await scenario.prepare()
            let before = try await scenario.inventory("before-export")
            let writer = try await scenario.makeWriter(.init(reply: reply))
            do { try await scenario.export(writer: writer); XCTFail("Failed reply accepted") }
            catch let error as FilmExportError {
                if reply == .missingReceipt { XCTAssertEqual(error, .missingReceipt) }
                else if case let .writeFailed(message) = error {
                    XCTAssertEqual(message, reply == .failBeforeCopy ? "beforeCopy" : (reply == .failAfterCopy ? "unknownAfterCopy" : "CancellationError()"))
                } else { XCTFail("Wrong export error: \(error)") }
            }
            try await scenario.recover()
            let result = try await scenario.inventory("failed-reply-reopened")
            assertUsable(result, sources: 1)
            XCTAssertEqual(assetHashes(result), assetHashes(before))
            XCTAssertEqual(result.dispositions[1], .exportRequested)
            XCTAssertEqual(result.externalFiles.count, reply == .failBeforeCopy ? 0 : 1)
            assertNoWork(result)
        }
    }

    func testPartialAcknowledgementRetrySkipsRecordedWrite() async throws {
        let scenario = try ExportScenario(count: 2, label: "partial-ack")
        try await scenario.prepare()
        let before = try await scenario.inventory("before-partial")
        let writer = try await scenario.makeWriter(.init(failAtAttempt: 2))
        do { try await scenario.export(writer: writer, sequences: [1, 2]); XCTFail("Partial failure accepted") }
        catch FilmExportError.writeFailed("beforeCopy") { }
        let partial = try await scenario.inventory("partial")
        assertUsable(partial, sources: 2)
        assertReceipt(partial, sequence: 1)
        XCTAssertEqual(partial.dispositions[2], .exportRequested)
        XCTAssertEqual(partial.externalFiles.count, 1)
        try await scenario.recover()
        let retry = try await scenario.makeWriter()
        try await scenario.export(writer: retry, sequences: [1, 2])
        let calls = await retry.attempts
        XCTAssertEqual(calls, 1)
        let result = try await scenario.inventory("retry-completed")
        assertUsable(result, sources: 0)
        XCTAssertEqual(assetHashes(result, kind: "master"), assetHashes(before, kind: "master"))
        XCTAssertEqual(result.externalFiles.count, 2)
        assertReceipt(result, sequence: 1); assertReceipt(result, sequence: 2)
        let repeated = try await scenario.makeWriter()
        try await scenario.export(writer: repeated, sequences: [1, 2])
        let repeatedCalls = await repeated.attempts
        XCTAssertEqual(repeatedCalls, 0)
        _ = try await scenario.inventory("acknowledged-repeat-no-write")
    }

    func testAcknowledgementCannotCleanWithoutDecodableHashMatchingMaster() async throws {
        for decodable in [false, true] {
            let scenario = try ExportScenario(label: "corrupt-master-\(decodable)")
            try await scenario.prepare()
            let initial = try await scenario.inventory("before-corruption")
            let writer = try await scenario.makeWriter(.init(boundary: .beforeReply))
            let export = Task { try await scenario.export(writer: writer) }
            try await paused(writer)
            let originalMaster = try await scenario.corruptMaster(decodable: decodable)
            _ = try await scenario.inventory("corrupt-before-ack")
            try await writer.release()
            do { try await export.value; XCTFail("Invalid master allowed cleanup") }
            catch let error as PersistenceError { XCTAssertEqual(error, decodable ? .masterChecksumMismatch : .invalidMedia) }
            let failed = try await scenario.inventory("acknowledged-cleanup-failed")
            XCTAssertEqual(assetHashes(failed, kind: "source"), assetHashes(initial, kind: "source"))
            assertReceipt(failed, sequence: 1)
            XCTAssertEqual(failed.externalFiles.count, 1)
            try await scenario.restoreSyntheticMaster(originalMaster)
            try await scenario.recover()
            let retry = try await scenario.makeWriter()
            try await scenario.export(writer: retry)
            let calls = await retry.attempts
            XCTAssertEqual(calls, 0, "Known successful receipt prevents another external write")
            let result = try await scenario.inventory("master-restored-cleanup")
            assertUsable(result, sources: 0)
            XCTAssertEqual(assetHashes(result, kind: "master"), assetHashes(initial, kind: "master"))
        }
    }

    func testDevelopedExportKeepsOriginalChoiceIndependent() async throws {
        let scenario = try ExportScenario(label: "developed-independent")
        try await scenario.prepare()
        let editedHash = try await scenario.editFirstPhoto()
        let writer = try await scenario.makeWriter()
        try await scenario.export(writer: writer, originals: false)
        let result = try await scenario.inventory("developed-exported")
        assertUsable(result, sources: 1)
        XCTAssertEqual(Array(result.externalFiles.values), [editedHash])
        XCTAssertTrue(result.dispositions.isEmpty)
    }

    func testSuspendLeavesAnInFlightExportToFinishAndRecordItsCopy() async throws {
        for boundary in [ExportBoundary.beforeCopy, .beforeReply] {
            let scenario = try ExportScenario(label: "suspend-\(boundary.rawValue)")
            try await scenario.prepare()
            let before = try await scenario.inventory("before-suspend")
            let writer = try await scenario.makeWriter(.init(boundary: boundary))
            let export = Task { try await scenario.export(writer: writer) }
            try await paused(writer)
            await scenario.suspend()
            XCTAssertTrue(try events(scenario).contains("suspend-returned"))
            let cancellations = await writer.cancellations
            XCTAssertEqual(cancellations, 0, "A Photos write already under way cannot be recalled, so suspension leaves it running")
            try await writer.release()
            try await export.value
            try await scenario.recover()
            let result = try await scenario.inventory("suspended-export-completed")
            assertUsable(result, sources: 0)
            XCTAssertEqual(assetHashes(result, kind: "master"), assetHashes(before, kind: "master"))
            assertReceipt(result, sequence: 1)
            XCTAssertEqual(result.externalFiles.count, 1)
            assertNoWork(result)
        }
    }

    func testDeleteWaitsForPausedReplyAndCannotRecallCompletedCopy() async throws {
        for boundary in [ExportBoundary.beforeCopy, .beforeReply] {
            for lateAcknowledgement in [false, true] {
                let scenario = try ExportScenario(label: "delete-\(boundary.rawValue)-lateAck-\(lateAcknowledgement)")
                try await scenario.prepare()
                let writer = try await scenario.makeWriter(.init(boundary: boundary, acknowledgeAfterCancellation: lateAcknowledgement))
                let export = Task { try await scenario.export(writer: writer) }
                try await paused(writer)
                let deletion = Task { try await scenario.removeFilm() }
                try await cancelled(writer)
                let held = try await scenario.inventory("delete-awaits-writer")
                XCTAssertEqual(held.films.count, 1)
                XCTAssertFalse(try events(scenario).contains("removal-returned"))
                try await writer.release()
                do { try await export.value; XCTFail("Cancelled original export reported completed cleanup") }
                catch is CancellationError { XCTAssertTrue(lateAcknowledgement) }
                catch FilmExportError.writeFailed("CancellationError()") { XCTAssertFalse(lateAcknowledgement) }
                try await deletion.value
                try await scenario.recover()
                let result = try await scenario.inventory("deleted-reopened")
                XCTAssertTrue(result.films.isEmpty)
                XCTAssertTrue(result.assets.isEmpty)
                XCTAssertTrue(result.privateFiles.keys.allSatisfy { !$0.hasPrefix("Media/") && !$0.hasPrefix("Work/") && !$0.hasPrefix("Staging/") })
                XCTAssertEqual(result.externalFiles.count, boundary == .beforeReply || lateAcknowledgement ? 1 : 0)
                let stale = try await scenario.makeWriter()
                do { try await scenario.export(writer: stale); XCTFail("Deleted Film exported") }
                catch PersistenceError.filmNotFound { }
                let calls = await stale.attempts
                XCTAssertEqual(calls, 0)
                let final = try await scenario.inventory("late-export-rejected")
                XCTAssertEqual(final.externalFiles, result.externalFiles)
            }
        }
    }

    func testMovieDiscardRetiresPrivateAssemblyButKeepsCompletedExternalCopy() async throws {
        for camera in [CameraID.super8HomeMovie, .cinema16mm] {
            for boundary in [ExportBoundary.beforeCopy, .beforeReply] {
                let scenario = try ExportScenario(camera: camera, count: 2, label: "movie-discard-\(boundary.rawValue)")
                try await scenario.prepare()
                let before = try await scenario.inventory("before-discard")
                let oldURL = try await scenario.assetURL(sequence: 0, kind: .movie)
                let oldHash = try XCTUnwrap(before.assets.first { $0.kind == "movie" }?.actualHash)
                let writer = try await scenario.makeWriter(.init(boundary: boundary, acknowledgeAfterCancellation: boundary == .beforeReply))
                let export = Task { try await scenario.export(writer: writer, originals: false, sequences: [1, 2]) }
                try await paused(writer)
                let discard = Task { try await scenario.removeFilm(discardSequence: 1) }
                try await cancelled(writer)
                _ = try await scenario.inventory("discard-awaits-writer")
                XCTAssertFalse(try events(scenario).contains("removal-returned"))
                try await writer.release()
                if boundary == .beforeReply { try await export.value }
                else {
                    do { try await export.value; XCTFail("Cancelled before-copy writer succeeded") }
                    catch FilmExportError.writeFailed("CancellationError()") { }
                }
                try await discard.value
                try await scenario.recover()
                let result = try await scenario.inventory("discard-reassembled-reopened")
                XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
                XCTAssertEqual(result.films.first?.discardedPlaceholderSequenceNumbers, [1])
                XCTAssertEqual(result.films.first?.consumedMovieSeconds, before.films.first?.consumedMovieSeconds)
                XCTAssertEqual(result.films.first?.movieOrientation, .portrait)
                XCTAssertEqual(result.development?.assignments, before.development?.assignments)
                XCTAssertEqual(result.assets.first { $0.kind == "clip" && $0.sequence == 2 }?.actualHash,
                               before.assets.first { $0.kind == "clip" && $0.sequence == 2 }?.actualHash)
                XCTAssertFalse(result.assets.contains { $0.sequence == 1 })
                let movie = try XCTUnwrap(result.assets.first { $0.kind == "movie" })
                XCTAssertNotEqual(movie.actualHash, oldHash)
                XCTAssertEqual(try XCTUnwrap(movie.duration), try XCTUnwrap(before.assets.first { $0.kind == "clip" }?.duration), accuracy: 0.01)
                XCTAssertGreaterThan(movie.decodedFrames ?? 0, 0)
                if boundary == .beforeReply { XCTAssertEqual(Array(result.externalFiles.values), [oldHash]) }
                else { XCTAssertTrue(result.externalFiles.isEmpty) }
                try await scenario.removeFilm(discardSequence: 2)
                try await scenario.recover()
                let empty = try await scenario.inventory("last-clip-empty-reopened")
                XCTAssertEqual(empty.films.first?.discardedPlaceholderSequenceNumbers, [1, 2])
                XCTAssertEqual(empty.films.first?.canPlaybackDevelopedMovie, false)
                XCTAssertEqual(empty.films.first?.consumedMovieSeconds, before.films.first?.consumedMovieSeconds)
                XCTAssertTrue(empty.assets.isEmpty)
                XCTAssertEqual(empty.externalFiles, result.externalFiles)
                let emptyWriter = try await scenario.makeWriter()
                do { try await scenario.export(writer: emptyWriter, originals: false, sequences: [1, 2]); XCTFail("Empty Movie exported") }
                catch PersistenceError.mediaNotRevealed { }
                let calls = await emptyWriter.attempts
                XCTAssertEqual(calls, 0)
            }
        }
    }

    private func paused(_ writer: ControlledExportWriter) async throws {
        let deadline = Date().addingTimeInterval(20)
        while !(await writer.phase).hasPrefix("paused-") {
            guard Date() < deadline else { throw ExportHarnessError.invalidControl }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    private func cancelled(_ writer: ControlledExportWriter) async throws {
        let deadline = Date().addingTimeInterval(10)
        while await writer.cancellations == 0 {
            guard Date() < deadline else { throw ExportHarnessError.invalidControl }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
    private func events(_ scenario: ExportScenario) throws -> String {
        try String(contentsOf: scenario.evidence.directory.appendingPathComponent("events.jsonl"), encoding: .utf8)
    }
    private func assetHashes(_ value: ExportInventory, kind: String? = nil) -> [String: String] {
        Dictionary(uniqueKeysWithValues: value.assets.filter { kind == nil || $0.kind == kind }
            .map { ("\($0.kind)-\($0.sequence)", $0.actualHash ?? "missing") })
    }
    private func assertNoWork(_ value: ExportInventory, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(value.privateFiles.keys.contains { $0.hasPrefix("Work/") }, file: file, line: line)
    }
    private func assertUsable(_ value: ExportInventory, sources: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(value.films.count, 1, file: file, line: line)
        XCTAssertEqual(value.assets.filter { $0.kind == "source" }.count, sources, file: file, line: line)
        XCTAssertTrue(value.assets.contains { ["master", "clip"].contains($0.kind) }, file: file, line: line)
        for asset in value.assets {
            XCTAssertEqual(asset.actualHash, asset.expectedHash, file: file, line: line)
            XCTAssertGreaterThan(asset.decodedFrames ?? 0, 0, file: file, line: line)
            XCTAssertNil(asset.error, file: file, line: line)
        }
    }
    private func assertReceipt(_ value: ExportInventory, sequence: Int, file: StaticString = #filePath, line: UInt = #line) {
        guard case let .exported(_, identifier) = value.dispositions[sequence] else {
            return XCTFail("Missing durable acknowledgment", file: file, line: line)
        }
        XCTAssertTrue(identifier.hasPrefix("injected-private-export036:"), file: file, line: line)
    }
}
