@preconcurrency import Photos
import Foundation

public struct PhotoKitAuthorizer: PhotoLibraryAuthorizing {
    public init() {}

    public func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus {
        Self.map(PHPhotoLibrary.authorizationStatus(for: accessLevel.phAccessLevel))
    }

    public func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: accessLevel.phAccessLevel) { status in
                continuation.resume(returning: Self.map(status))
            }
        }
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoLibraryAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }
}

public struct PhotoKitWriter: PhotoLibraryWriting {
    public init() {}

    public func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt {
        let box = PhotoKitLocalIdentifierBox()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(
                    with: request.mediaKind.resourceType,
                    fileURL: request.fileURL,
                    options: nil
                )
                box.localIdentifier = creationRequest.placeholderForCreatedAsset?.localIdentifier
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: PhotoKitWriteError.changeRequestFailed)
                }
            }
        }
        return PhotoExportReceipt(localIdentifier: box.localIdentifier)
    }
}

public enum PhotoKitWriteError: Error, Equatable, Sendable {
    case changeRequestFailed
}

private final class PhotoKitLocalIdentifierBox: @unchecked Sendable {
    var localIdentifier: String?
}

private extension PhotoLibraryAccessLevel {
    var phAccessLevel: PHAccessLevel {
        switch self {
        case .addOnly:
            return .addOnly
        }
    }
}

private extension PhotoExportMediaKind {
    var resourceType: PHAssetResourceType {
        switch self {
        case .photo:
            return .photo
        case .movie:
            return .video
        }
    }
}
