import FilmPersistence
import Foundation
import NativeAdapters

public actor CapturePipelineReceiver: CaptureSaveCommitting {
    private let pipeline: CapturePersistencePipeline<FileCapturePayloadReader>
    public private(set) var lastOutcome: CapturePipelineOutcome?

    public init(filmID: UUID, repositoryURL: URL) throws {
        pipeline = CapturePersistencePipeline(
            filmID: filmID,
            repository: try FilmRepository(rootURL: repositoryURL)
        )
    }

    public func commit(_ event: CaptureSaveEvent) async throws {
        lastOutcome = try pipeline.handle(event)
    }
}
