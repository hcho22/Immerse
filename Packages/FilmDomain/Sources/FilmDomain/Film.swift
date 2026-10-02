import Foundation

public enum MovieOrientation: String, Codable, Equatable, Sendable {
    case portrait
    case landscape
}

public enum ClipOrientation: String, Codable, Equatable, Sendable {
    case portrait
    case landscape
}

public enum CaptureKind: Codable, Equatable, Sendable {
    case photo
    case movieClip(seconds: TimeInterval, orientation: ClipOrientation)
}

/// Movie capacity is accounted in whole frames, never in summed seconds, so clips that
/// together record a Camera's full duration always complete its Film exactly.
public enum MovieFrames {
    public static let perSecond = 30

    /// The whole frames a saved clip of this decoded duration consumes. A clip always
    /// consumes at least one frame; a non-finite or non-positive duration has none.
    public static func count(seconds: TimeInterval) -> Int? {
        guard seconds.isFinite, seconds > 0,
              let frames = Int(exactly: (seconds * Double(perSecond)).rounded()) else { return nil }
        return max(1, frames)
    }

    public static func seconds(_ frames: Int) -> TimeInterval {
        Double(frames) / Double(perSecond)
    }
}

public enum CaptureRevealState: String, Codable, Equatable, Sendable {
    case sealed
    case revealed
    case discardedPlaceholder
}

public struct CaptureRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: Int { sequenceNumber }

    public let sequenceNumber: Int
    public let kind: CaptureKind
    public let savedAt: Date
    public fileprivate(set) var revealState: CaptureRevealState

    public var isDiscarded: Bool {
        revealState == .discardedPlaceholder
    }
}

public enum CompletionState: Codable, Equatable, Sendable {
    case open
    case capacityFull
    case completedEarly(wasted: WastedCapacity)
}

public enum WastedCapacity: Codable, Equatable, Sendable {
    case exposures(Int)
    case seconds(TimeInterval)
}

public enum DevelopmentState: String, Codable, Equatable, Sendable {
    case notStarted
    case developing
    case developed
}

public enum FilmDomainError: Error, Equatable, Sendable {
    case wrongCameraMedium
    case movieOrientationRequired
    case movieOrientationNotAllowed
    case captureAlreadyComplete
    case noSavedCapturesForEarlyCompletion
    case earlyCompletionUnsupportedForInstant
    case invalidMovieDuration
    case insufficientRemainingCapacity(remainingSeconds: TimeInterval)
    case noRemainingExposures
    case developmentNotEligible
    case developmentAlreadyStarted
    case developmentNotInProgress
    case instantDoesNotUseRollDevelopment
    case captureNotFound
    case captureNotRevealed
    case captureAlreadyDiscarded
    case emptyTitle
}

public struct Film: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let camera: CameraPackage
    public private(set) var title: String
    public private(set) var isArchived: Bool
    public let loadedAt: Date
    public let movieOrientation: MovieOrientation?
    public private(set) var completionState: CompletionState
    public private(set) var developmentState: DevelopmentState
    public private(set) var captures: [CaptureRecord]

    public init(
        id: UUID = UUID(),
        camera: CameraPackage,
        title: String,
        loadedAt: Date = Date(),
        movieOrientation: MovieOrientation? = nil
    ) throws {
        if camera.medium == .movie, movieOrientation == nil {
            throw FilmDomainError.movieOrientationRequired
        }
        if camera.medium == .photo, movieOrientation != nil {
            throw FilmDomainError.movieOrientationNotAllowed
        }

        self.id = id
        self.camera = camera
        self.title = try Self.validTitle(title)
        self.isArchived = false
        self.loadedAt = loadedAt
        self.movieOrientation = movieOrientation
        self.completionState = .open
        self.developmentState = .notStarted
        self.captures = []
    }

    public var savedCaptureCount: Int {
        captures.count
    }

    public var captureDateRange: ClosedRange<Date>? {
        guard let first = captures.first?.savedAt, let last = captures.last?.savedAt else {
            return nil
        }
        // Wall-clock adjustments never change capture sequence or crash the Journal.
        return min(first, last)...max(first, last)
    }

    public var remainingExposures: Int? {
        guard case let .exposures(limit) = camera.capacity else {
            return nil
        }
        return max(0, limit - captures.count)
    }

    public var consumedMovieFrames: Int {
        captures.reduce(0) { total, capture in
            guard case let .movieClip(seconds, _) = capture.kind else {
                return total
            }
            return total + (MovieFrames.count(seconds: seconds) ?? 0)
        }
    }

    public var remainingMovieFrames: Int? {
        guard case let .seconds(limit) = camera.capacity else {
            return nil
        }
        return max(0, limit * MovieFrames.perSecond - consumedMovieFrames)
    }

    public var consumedMovieSeconds: TimeInterval {
        MovieFrames.seconds(consumedMovieFrames)
    }

    public var remainingMovieSeconds: TimeInterval? {
        remainingMovieFrames.map(MovieFrames.seconds)
    }

    public var canStartDevelopment: Bool {
        switch (camera.revealRule, completionState, developmentState) {
        case (.rollLevelDevelopment, .open, _),
             (.movieDevelopment, .open, _),
             (_, _, .developing),
             (_, _, .developed),
             (.instantPerExposure, _, _):
            false
        default:
            savedCaptureCount > 0
        }
    }

    public var playableMovieClipSequenceNumbers: [Int] {
        guard camera.medium == .movie, developmentState == .developed else {
            return []
        }
        return captures.compactMap { capture in
            guard case .movieClip = capture.kind, capture.revealState == .revealed else {
                return nil
            }
            return capture.sequenceNumber
        }
    }

    public var canPlaybackDevelopedMovie: Bool {
        !playableMovieClipSequenceNumbers.isEmpty
    }

    public var canExportDevelopedMovie: Bool {
        canPlaybackDevelopedMovie
    }

    public var discardedPlaceholderSequenceNumbers: [Int] {
        captures.compactMap { capture in
            capture.isDiscarded ? capture.sequenceNumber : nil
        }
    }

    public mutating func rename(to newTitle: String) throws {
        title = try Self.validTitle(newTitle)
    }

    /// A title is trimmed and never blank, so every Journal row and heading has a name.
    private static func validTitle(_ title: String) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FilmDomainError.emptyTitle }
        return trimmed
    }

    public mutating func setArchived(_ archived: Bool) {
        isArchived = archived
    }

    public mutating func recordFailedPhotoSave() throws {
        guard camera.medium == .photo else {
            throw FilmDomainError.wrongCameraMedium
        }
    }

    public mutating func recordSavedPhoto(at savedAt: Date = Date()) throws -> CaptureRecord {
        guard camera.medium == .photo else {
            throw FilmDomainError.wrongCameraMedium
        }
        try ensureCaptureOpen()
        guard let remainingExposures, remainingExposures > 0 else {
            throw FilmDomainError.noRemainingExposures
        }

        let capture = CaptureRecord(
            sequenceNumber: captures.count + 1,
            kind: .photo,
            savedAt: savedAt,
            revealState: .sealed
        )
        captures.append(capture)
        completeIfCapacityReached()
        return capture
    }

    public mutating func recordFailedMovieClipSave(durationSeconds: TimeInterval) throws {
        guard camera.medium == .movie else {
            throw FilmDomainError.wrongCameraMedium
        }
        guard MovieFrames.count(seconds: durationSeconds) != nil else {
            throw FilmDomainError.invalidMovieDuration
        }
    }

    public mutating func recordSavedMovieClip(
        durationSeconds: TimeInterval,
        orientation: ClipOrientation,
        at savedAt: Date = Date()
    ) throws -> CaptureRecord {
        guard camera.medium == .movie else {
            throw FilmDomainError.wrongCameraMedium
        }
        try ensureCaptureOpen()
        guard let frames = MovieFrames.count(seconds: durationSeconds) else {
            throw FilmDomainError.invalidMovieDuration
        }
        let remaining = remainingMovieFrames ?? 0
        guard frames <= remaining else {
            throw FilmDomainError.insufficientRemainingCapacity(remainingSeconds: MovieFrames.seconds(remaining))
        }

        let capture = CaptureRecord(
            sequenceNumber: captures.count + 1,
            kind: .movieClip(seconds: durationSeconds, orientation: orientation),
            savedAt: savedAt,
            revealState: .sealed
        )
        captures.append(capture)
        completeIfCapacityReached()
        return capture
    }

    @discardableResult
    public mutating func completeEarly() throws -> WastedCapacity {
        try ensureCaptureOpen()
        guard savedCaptureCount > 0 else {
            throw FilmDomainError.noSavedCapturesForEarlyCompletion
        }

        switch (camera.revealRule, camera.capacity) {
        case (.rollLevelDevelopment, .exposures):
            let wasted = WastedCapacity.exposures(remainingExposures ?? 0)
            completionState = .completedEarly(wasted: wasted)
            return wasted
        case (.movieDevelopment, .seconds):
            let wasted = WastedCapacity.seconds(remainingMovieSeconds ?? 0)
            completionState = .completedEarly(wasted: wasted)
            return wasted
        case (.instantPerExposure, _):
            throw FilmDomainError.earlyCompletionUnsupportedForInstant
        default:
            throw FilmDomainError.wrongCameraMedium
        }
    }

    public mutating func startDevelopment() throws {
        guard camera.revealRule != .instantPerExposure else {
            throw FilmDomainError.instantDoesNotUseRollDevelopment
        }
        guard canStartDevelopment else {
            throw FilmDomainError.developmentNotEligible
        }
        guard developmentState == .notStarted else {
            throw FilmDomainError.developmentAlreadyStarted
        }
        developmentState = .developing
    }

    public mutating func finishDevelopment() throws {
        guard developmentState == .developing else {
            throw FilmDomainError.developmentNotInProgress
        }
        for index in captures.indices where captures[index].revealState == .sealed {
            captures[index].revealState = .revealed
        }
        developmentState = .developed
    }

    public mutating func revealInstantPrint(sequenceNumber: Int) throws {
        guard camera.revealRule == .instantPerExposure else { throw FilmDomainError.wrongCameraMedium }
        guard let index = captures.firstIndex(where: { $0.sequenceNumber == sequenceNumber }) else {
            throw FilmDomainError.captureNotFound
        }
        guard !captures[index].isDiscarded else { throw FilmDomainError.captureAlreadyDiscarded }
        captures[index].revealState = .revealed
    }

    public mutating func discardRevealedCapture(sequenceNumber: Int) throws {
        guard let index = captures.firstIndex(where: { $0.sequenceNumber == sequenceNumber }) else {
            throw FilmDomainError.captureNotFound
        }
        switch captures[index].revealState {
        case .sealed:
            throw FilmDomainError.captureNotRevealed
        case .discardedPlaceholder:
            throw FilmDomainError.captureAlreadyDiscarded
        case .revealed:
            captures[index].revealState = .discardedPlaceholder
        }
    }

    private func ensureCaptureOpen() throws {
        guard completionState == .open else {
            throw FilmDomainError.captureAlreadyComplete
        }
    }

    private mutating func completeIfCapacityReached() {
        switch camera.capacity {
        case let .exposures(limit) where captures.count == limit:
            completionState = .capacityFull
        case .seconds where remainingMovieFrames == 0:
            completionState = .capacityFull
        default:
            break
        }
    }
}
