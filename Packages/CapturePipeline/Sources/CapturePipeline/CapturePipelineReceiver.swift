import FilmPersistence
import Foundation
import NativeAdapters

public actor CapturePipelineReceiver: CaptureSaveCommitting {
    private let pipeline: CapturePersistencePipeline<FileCapturePayloadReader>
    private var committedFiles = Set<URL>()
    public private(set) var lastOutcome: CapturePipelineOutcome?

    public init(filmID: UUID, repositoryURL: URL) throws {
        pipeline = CapturePersistencePipeline(
            filmID: filmID,
            repository: try FilmRepository(rootURL: repositoryURL)
        )
    }

    public func commit(_ event: CaptureSaveEvent) async throws {
        let file: URL?
        switch event {
        case let .photoSaved(url), let .movieClipSaved(url, _, _): file = url
        default: file = nil
        }
        if let file, committedFiles.contains(file) { return }
        lastOutcome = try pipeline.handle(event)
        if let file { committedFiles.insert(file) }
    }
}
