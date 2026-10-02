import RenderFixtures
import XCTest

final class RenderFixturesTests: XCTestCase {
    private var outputDirectory: URL!

    override func setUpWithError() throws {
        outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RenderFixturesTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let outputDirectory, FileManager.default.fileExists(atPath: outputDirectory.path) {
            try FileManager.default.removeItem(at: outputDirectory)
        }
        outputDirectory = nil
    }

    func testWritesAndDecodesSyntheticPhotoAndMovieMetadata() async throws {
        let settings = RenderFixtureSettings(
            photoWidth: 160,
            photoHeight: 120,
            movieWidth: 160,
            movieHeight: 90,
            movieFrameRate: 18,
            movieDurationSeconds: 1.0,
            movieOrientation: .landscape
        )

        let manifest = try await RenderFixtureGenerator.writeFixtures(
            outputDirectory: outputDirectory,
            settings: settings
        )

        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: outputDirectory.appendingPathComponent(manifest.photo.relativePath).path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: outputDirectory.appendingPathComponent(manifest.movie.relativePath).path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: outputDirectory.appendingPathComponent("manifest.json").path
            )
        )

        XCTAssertEqual(manifest.photo.pixelWidth, 160)
        XCTAssertEqual(manifest.photo.pixelHeight, 120)
        XCTAssertEqual(manifest.photo.uniformTypeIdentifier, "public.jpeg")
        XCTAssertFalse(manifest.photo.hasAlpha)

        XCTAssertEqual(manifest.movie.encodedWidth, 160)
        XCTAssertEqual(manifest.movie.encodedHeight, 90)
        XCTAssertEqual(manifest.movie.codecFourCC, "avc1")
        XCTAssertEqual(manifest.movie.nominalFrameRate, 18, accuracy: 0.1)
        XCTAssertEqual(manifest.movie.durationSeconds, 1.0, accuracy: 0.1)
        XCTAssertEqual(manifest.movie.orientation, .landscape)
        XCTAssertEqual(manifest.movie.preferredTransform, TransformMetadata(.identity))
    }

    func testPortraitFixtureRecordsOrientationTransformSeparatelyFromEncodedRaster() async throws {
        let settings = RenderFixtureSettings(
            photoWidth: 64,
            photoHeight: 64,
            movieWidth: 90,
            movieHeight: 160,
            movieFrameRate: 24,
            movieDurationSeconds: 0.5,
            movieOrientation: .portrait
        )

        let manifest = try await RenderFixtureGenerator.writeFixtures(
            outputDirectory: outputDirectory,
            settings: settings
        )

        XCTAssertEqual(manifest.movie.encodedWidth, 90)
        XCTAssertEqual(manifest.movie.encodedHeight, 160)
        XCTAssertEqual(manifest.movie.nominalFrameRate, 24, accuracy: 0.1)
        XCTAssertEqual(manifest.movie.orientation, .portrait)
        XCTAssertNotEqual(manifest.movie.preferredTransform, TransformMetadata(.identity))
    }
}
