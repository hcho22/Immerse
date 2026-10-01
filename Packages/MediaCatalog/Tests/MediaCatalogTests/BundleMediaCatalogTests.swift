import FilmDomain
import Foundation
import XCTest
@testable import MediaCatalog

final class BundleMediaCatalogTests: XCTestCase {
    func testProductionRejectsSyntheticClearanceAndEmptyCatalogLoadsWithoutEffects() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        XCTAssertThrowsError(try BundleMediaCatalog(rootURL: fixture.root, manifestData: fixture.manifest())) {
            XCTAssertEqual($0 as? MediaCatalogError, .unapprovedRights)
        }
        let empty = try JSONEncoder().encode(MediaCatalogManifest(schemaVersion: 1, soundtrackReselection: nil, assets: []))
        let catalog = try BundleMediaCatalog(rootURL: fixture.root, manifestData: empty)
        XCTAssertTrue(catalog.manifest.assets.isEmpty)
        XCTAssertNil(catalog.manifest.soundtrackReselection)
    }

    func testVerifiedResourceAndLicenseCannotSilentlyChange() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let catalog = try fixture.catalog()
        XCTAssertEqual(catalog.assets(for: .disposable1990s, purpose: .cameraSample).map(\.id), ["fixture"])
        XCTAssertTrue(catalog.assets(for: .instant1970s, purpose: .cameraSample).isEmpty)
        let verified = try catalog.resolve(id: "fixture")
        XCTAssertEqual(try verified.data(), fixture.bytes)
        try Data("changed media".utf8).write(to: fixture.root.appendingPathComponent("sample.bin"))
        XCTAssertThrowsError(try verified.data())
        try fixture.bytes.write(to: fixture.root.appendingPathComponent("sample.bin"))
        try Data("changed license".utf8).write(to: fixture.root.appendingPathComponent("license.txt"))
        XCTAssertThrowsError(try catalog.resolve(id: "fixture"))
    }

    func testPathsDuplicateIDsAndWrongMediaAreRejected() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        for path in ["../sample.bin", "/sample.bin", "https://invalid.example/sample"] {
            XCTAssertThrowsError(try fixture.catalog(assets: [fixture.asset(path: path)]))
        }
        let outside = fixture.root.appendingPathExtension("outside")
        try fixture.bytes.write(to: outside)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(at: fixture.root.appendingPathComponent("linked"), withDestinationURL: outside)
        XCTAssertThrowsError(try fixture.catalog(assets: [fixture.asset(path: "linked")]))
        XCTAssertThrowsError(try fixture.catalog(assets: [fixture.asset(), fixture.asset()]))
        XCTAssertThrowsError(try fixture.catalog(assets: [fixture.asset(cameras: [.super8HomeMovie])]))
    }

    func testInstrumentalNeedsMovieCameraAndExportRights() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        XCTAssertThrowsError(try fixture.catalog(assets: [fixture.asset(cameras: [.super8HomeMovie], purpose: .instrumental, kind: .audio)]))
        let valid = fixture.asset(cameras: [.super8HomeMovie, .cinema16mm], purpose: .instrumental, kind: .audio, export: true)
        XCTAssertEqual(try fixture.catalog(assets: [valid]).assets(for: .super8HomeMovie, purpose: .instrumental).count, 1)
        XCTAssertThrowsError(try fixture.catalog(assets: [fixture.asset(cameras: [.instant1970s], purpose: .instrumental, kind: .audio, export: true)]))
    }

    private struct Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MediaCatalog-\(UUID())")
        let bytes = Data("synthetic catalog bytes, not decodable production media".utf8)
        let license = Data("Test-only synthetic fixture. Not cleared for distribution.".utf8)

        init() throws {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try bytes.write(to: root.appendingPathComponent("sample.bin"))
            try license.write(to: root.appendingPathComponent("license.txt"))
        }
        func remove() { try? FileManager.default.removeItem(at: root) }
        func asset(path: String = "sample.bin", cameras: [CameraID] = [.disposable1990s],
                   purpose: CatalogMediaAsset.Purpose = .cameraSample, kind: CatalogMediaAsset.Kind = .photo,
                   export: Bool = false) -> CatalogMediaAsset {
            CatalogMediaAsset(id: "fixture", title: "Synthetic fixture", cameraIDs: cameras, purpose: purpose,
                kind: kind, resourcePath: path, sha256: BundleMediaCatalog.digest(bytes),
                rights: MediaRights(clearance: .syntheticTestOnly, creator: "Unit test", source: "Generated in test",
                    acquiredAt: "2026-10-01", approvalReference: "Test fixture only", licensePath: "license.txt",
                    licenseSHA256: BundleMediaCatalog.digest(license), permitsBundling: true,
                    permitsMovieExport: export, attribution: "Synthetic unit fixture"))
        }
        func manifest(assets: [CatalogMediaAsset]? = nil) throws -> Data {
            try JSONEncoder().encode(MediaCatalogManifest(schemaVersion: 1, soundtrackReselection: nil, assets: assets ?? [asset()]))
        }
        func catalog(assets: [CatalogMediaAsset]? = nil) throws -> BundleMediaCatalog {
            try BundleMediaCatalog(rootURL: root, manifestData: manifest(assets: assets), allowSyntheticFixtures: true)
        }
    }
}
