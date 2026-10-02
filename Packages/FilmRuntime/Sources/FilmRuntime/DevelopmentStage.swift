import Foundation

public enum DevelopmentStage: Equatable, Sendable {
    case beforeBegin
    case afterAssignments
    case afterRendering(sequence: Int)
    case afterPersistence(sequence: Int)
    case beforeRevealOrCleanup(DevelopmentFinalization)
}

public enum DevelopmentFinalization: Equatable, Sendable {
    case instantReveal(sequence: Int)
    case filmReveal
    case sourceCleanup
}

/// Optional observation of existing Development boundaries; never installed by the app.
public typealias DevelopmentObserver = @Sendable (UUID, DevelopmentStage) async throws -> Void
