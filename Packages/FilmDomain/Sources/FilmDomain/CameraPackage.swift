import Foundation

public enum CameraID: String, CaseIterable, Codable, Equatable, Sendable {
    case disposable1990s
    case instant1970s
    case mediumFormat6x6
    case super8HomeMovie
    case cinema16mm
}

public enum CameraMedium: String, Codable, Equatable, Sendable {
    case photo
    case movie
}

public enum RevealRule: String, Codable, Equatable, Sendable {
    case rollLevelDevelopment
    case instantPerExposure
    case movieDevelopment
}

/// The color or black-and-white film a 6×6 Medium Format or 16mm Cinema Film is loaded with, chosen at Load Film and
/// fixed for that Film (ADR 0014). No other Camera offers one.
public enum FilmStock: String, CaseIterable, Codable, Equatable, Sendable {
    case color
    case blackAndWhite
}

public enum FilmCapacity: Codable, Equatable, Sendable {
    case exposures(Int)
    case seconds(Int)
}

public struct CameraPackage: Codable, Equatable, Identifiable, Sendable {
    public let id: CameraID
    public let displayName: String
    public let medium: CameraMedium
    public let capacity: FilmCapacity
    public let revealRule: RevealRule
    public let supportsBuiltInSoundtrack: Bool

    public init(
        id: CameraID,
        displayName: String,
        medium: CameraMedium,
        capacity: FilmCapacity,
        revealRule: RevealRule,
        supportsBuiltInSoundtrack: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.medium = medium
        self.capacity = capacity
        self.revealRule = revealRule
        self.supportsBuiltInSoundtrack = supportsBuiltInSoundtrack
    }
}

extension CameraPackage {
    /// The Film Stocks Load Film offers for this Camera, color first, or none for a Camera that is a complete package
    /// (ADR 0014). It follows the Camera, not the stored package, so a package a Film locked before Film Stock
    /// existed answers the same as today's.
    public var filmStocks: [FilmStock] {
        switch id {
        case .mediumFormat6x6, .cinema16mm: FilmStock.allCases
        case .disposable1990s, .instant1970s, .super8HomeMovie: []
        }
    }

    /// The Film Stock Load Film shows selected until the person chooses: color, where the Camera offers one.
    public var defaultFilmStock: FilmStock? { filmStocks.first }
}

public enum CameraCatalog {
    public static let disposable1990s = CameraPackage(
        id: .disposable1990s,
        displayName: "1990s Disposable",
        medium: .photo,
        capacity: .exposures(27),
        revealRule: .rollLevelDevelopment
    )

    public static let instant1970s = CameraPackage(
        id: .instant1970s,
        displayName: "1970s Instant",
        medium: .photo,
        capacity: .exposures(10),
        revealRule: .instantPerExposure
    )

    public static let mediumFormat6x6 = CameraPackage(
        id: .mediumFormat6x6,
        displayName: "6×6 Medium Format",
        medium: .photo,
        capacity: .exposures(12),
        revealRule: .rollLevelDevelopment
    )

    public static let super8HomeMovie = CameraPackage(
        id: .super8HomeMovie,
        displayName: "1960s Super 8 Home Movie",
        medium: .movie,
        capacity: .seconds(200),
        revealRule: .movieDevelopment,
        supportsBuiltInSoundtrack: true
    )

    public static let cinema16mm = CameraPackage(
        id: .cinema16mm,
        displayName: "16mm Cinema",
        medium: .movie,
        capacity: .seconds(167),
        revealRule: .movieDevelopment,
        supportsBuiltInSoundtrack: true
    )

    public static let all: [CameraPackage] = [
        disposable1990s,
        instant1970s,
        mediumFormat6x6,
        super8HomeMovie,
        cinema16mm
    ]

    public static func package(for id: CameraID) -> CameraPackage {
        switch id {
        case .disposable1990s:
            disposable1990s
        case .instant1970s:
            instant1970s
        case .mediumFormat6x6:
            mediumFormat6x6
        case .super8HomeMovie:
            super8HomeMovie
        case .cinema16mm:
            cinema16mm
        }
    }
}
