import FilmDomain
import Foundation

public struct MovieAssemblyPlan: Equatable, Sendable {
    public let filmID: UUID
    public let clipSequenceNumbers: [Int]

    public var hasPlayback: Bool {
        !clipSequenceNumbers.isEmpty
    }

    public init(film: Film) {
        self.filmID = film.id
        self.clipSequenceNumbers = film.playableMovieClipSequenceNumbers
    }
}
