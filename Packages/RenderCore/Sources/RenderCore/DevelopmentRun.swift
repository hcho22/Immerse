import FilmDomain
import CryptoKit
import Foundation

public struct TreatmentAssignment: Codable, Equatable, Sendable {
    public let sequenceNumber: Int
    public let seed: UInt64

    public init(sequenceNumber: Int, seed: UInt64) {
        self.sequenceNumber = sequenceNumber
        self.seed = seed
    }
}

public enum DevelopmentRunError: Error, Equatable, Sendable {
    case emptyFilm
    case captureNotFound(Int)
    case treatmentAlreadyAssigned(Int)
    case developmentAlreadyComplete
}

public struct DevelopmentRun: Codable, Equatable, Sendable {
    public let filmID: UUID
    public private(set) var assignments: [Int: TreatmentAssignment]
    public private(set) var completedSequences: Set<Int>
    public private(set) var isComplete: Bool

    public init(filmID: UUID) {
        self.filmID = filmID
        self.assignments = [:]
        self.completedSequences = []
        self.isComplete = false
    }

    public mutating func assignMissingTreatments(for film: Film) throws {
        guard !film.captures.isEmpty else {
            throw DevelopmentRunError.emptyFilm
        }
        guard !isComplete else {
            throw DevelopmentRunError.developmentAlreadyComplete
        }

        for capture in film.captures where assignments[capture.sequenceNumber] == nil {
            assignments[capture.sequenceNumber] = TreatmentAssignment(
                sequenceNumber: capture.sequenceNumber,
                seed: Self.seed(filmID: film.id, sequenceNumber: capture.sequenceNumber)
            )
        }
    }

    public mutating func markRendered(sequenceNumber: Int, in film: Film) throws {
        guard film.captures.contains(where: { $0.sequenceNumber == sequenceNumber }) else {
            throw DevelopmentRunError.captureNotFound(sequenceNumber)
        }
        if assignments[sequenceNumber] == nil {
            assignments[sequenceNumber] = TreatmentAssignment(
                sequenceNumber: sequenceNumber,
                seed: Self.seed(filmID: film.id, sequenceNumber: sequenceNumber)
            )
        }
        completedSequences.insert(sequenceNumber)
        isComplete = film.captures.allSatisfy { completedSequences.contains($0.sequenceNumber) }
    }

    public func resumed() -> DevelopmentRun {
        self
    }

    private static func seed(filmID: UUID, sequenceNumber: Int) -> UInt64 {
        let payload = "\(filmID.uuidString.lowercased()):\(sequenceNumber)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.prefix(8).reduce(UInt64(0)) { partialResult, byte in
            (partialResult << 8) | UInt64(byte)
        }
    }
}
