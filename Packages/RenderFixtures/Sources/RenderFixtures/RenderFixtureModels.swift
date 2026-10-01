import CoreGraphics
import Foundation

public struct RenderFixtureSettings: Codable, Equatable, Sendable {
    public var photoWidth: Int
    public var photoHeight: Int
    public var movieWidth: Int
    public var movieHeight: Int
    public var movieFrameRate: Int
    public var movieDurationSeconds: Double
    public var movieOrientation: RenderFixtureOrientation

    public init(
        photoWidth: Int,
        photoHeight: Int,
        movieWidth: Int,
        movieHeight: Int,
        movieFrameRate: Int,
        movieDurationSeconds: Double,
        movieOrientation: RenderFixtureOrientation
    ) {
        self.photoWidth = photoWidth
        self.photoHeight = photoHeight
        self.movieWidth = movieWidth
        self.movieHeight = movieHeight
        self.movieFrameRate = movieFrameRate
        self.movieDurationSeconds = movieDurationSeconds
        self.movieOrientation = movieOrientation
    }

    public static let defaultExperimental = RenderFixtureSettings(
        photoWidth: 640,
        photoHeight: 480,
        movieWidth: 640,
        movieHeight: 360,
        movieFrameRate: 18,
        movieDurationSeconds: 1.0,
        movieOrientation: .landscape
    )
}

public enum RenderFixtureOrientation: String, Codable, Equatable, Sendable {
    case portrait
    case landscape
}

public struct RenderFixtureManifest: Codable, Equatable, Sendable {
    public let note: String
    public let settings: RenderFixtureSettings
    public let photo: PhotoFixtureMetadata
    public let movie: MovieFixtureMetadata

    public init(
        note: String,
        settings: RenderFixtureSettings,
        photo: PhotoFixtureMetadata,
        movie: MovieFixtureMetadata
    ) {
        self.note = note
        self.settings = settings
        self.photo = photo
        self.movie = movie
    }
}

public struct PhotoFixtureMetadata: Codable, Equatable, Sendable {
    public let relativePath: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let uniformTypeIdentifier: String
    public let hasAlpha: Bool

    public init(
        relativePath: String,
        pixelWidth: Int,
        pixelHeight: Int,
        uniformTypeIdentifier: String,
        hasAlpha: Bool
    ) {
        self.relativePath = relativePath
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.uniformTypeIdentifier = uniformTypeIdentifier
        self.hasAlpha = hasAlpha
    }
}

public struct MovieFixtureMetadata: Codable, Equatable, Sendable {
    public let relativePath: String
    public let encodedWidth: Int
    public let encodedHeight: Int
    public let codecFourCC: String
    public let nominalFrameRate: Float
    public let durationSeconds: Double
    public let orientation: RenderFixtureOrientation
    public let preferredTransform: TransformMetadata

    public init(
        relativePath: String,
        encodedWidth: Int,
        encodedHeight: Int,
        codecFourCC: String,
        nominalFrameRate: Float,
        durationSeconds: Double,
        orientation: RenderFixtureOrientation,
        preferredTransform: TransformMetadata
    ) {
        self.relativePath = relativePath
        self.encodedWidth = encodedWidth
        self.encodedHeight = encodedHeight
        self.codecFourCC = codecFourCC
        self.nominalFrameRate = nominalFrameRate
        self.durationSeconds = durationSeconds
        self.orientation = orientation
        self.preferredTransform = preferredTransform
    }
}

public struct TransformMetadata: Codable, Equatable, Sendable {
    public let a: Double
    public let b: Double
    public let c: Double
    public let d: Double
    public let tx: Double
    public let ty: Double

    public init(_ transform: CGAffineTransform) {
        self.a = transform.a
        self.b = transform.b
        self.c = transform.c
        self.d = transform.d
        self.tx = transform.tx
        self.ty = transform.ty
    }
}
