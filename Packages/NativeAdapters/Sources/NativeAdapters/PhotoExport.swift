import Foundation

public enum PhotoLibraryAccessLevel: Equatable, Sendable {
    case addOnly
}

public enum PhotoLibraryAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
}

public enum PhotoExportMediaKind: Equatable, Sendable {
    case photo
    case movie
}

public struct PhotoExportRequest: Equatable, Sendable {
    public let fileURL: URL
    public let mediaKind: PhotoExportMediaKind

    public init(fileURL: URL, mediaKind: PhotoExportMediaKind) {
        self.fileURL = fileURL
        self.mediaKind = mediaKind
    }
}

public struct PhotoExportReceipt: Equatable, Sendable {
    public let localIdentifier: String?

    public init(localIdentifier: String?) {
        self.localIdentifier = localIdentifier
    }
}

public enum PhotoExportOutcome: Equatable, Sendable {
    case exported(PhotoExportReceipt)
    case needsPermission(PhotoLibraryAccessLevel)
    case permissionDenied(PhotoLibraryAuthorizationStatus)
    case writeFailed(String)

    public var permitsSourceCleanupAfterIndependentVerification: Bool {
        if case .exported = self {
            return true
        }
        return false
    }
}

public protocol PhotoLibraryAuthorizing: Sendable {
    func authorizationStatus(for accessLevel: PhotoLibraryAccessLevel) -> PhotoLibraryAuthorizationStatus
    func requestAuthorization(for accessLevel: PhotoLibraryAccessLevel) async -> PhotoLibraryAuthorizationStatus
}

public protocol PhotoLibraryWriting: Sendable {
    func write(_ request: PhotoExportRequest) async throws -> PhotoExportReceipt
}

public struct PhotoExportCoordinator<Authorizer: PhotoLibraryAuthorizing, Writer: PhotoLibraryWriting>: Sendable {
    private let authorizer: Authorizer
    private let writer: Writer
    private let accessLevel: PhotoLibraryAccessLevel
    private let promptPolicy: PermissionPromptPolicy

    public init(
        authorizer: Authorizer,
        writer: Writer,
        accessLevel: PhotoLibraryAccessLevel = .addOnly,
        promptPolicy: PermissionPromptPolicy = .deferToFlowCoordinator
    ) {
        self.authorizer = authorizer
        self.writer = writer
        self.accessLevel = accessLevel
        self.promptPolicy = promptPolicy
    }

    public func export(_ request: PhotoExportRequest) async -> PhotoExportOutcome {
        switch authorizer.authorizationStatus(for: accessLevel) {
        case .authorized, .limited:
            return await write(request)
        case .notDetermined:
            guard promptPolicy == .requestAtCaptureStart else {
                return .needsPermission(accessLevel)
            }
            let requestedStatus = await authorizer.requestAuthorization(for: accessLevel)
            switch requestedStatus {
            case .authorized, .limited:
                return await write(request)
            case .notDetermined:
                return .needsPermission(accessLevel)
            case .denied, .restricted:
                return .permissionDenied(requestedStatus)
            }
        case .denied, .restricted:
            return .permissionDenied(authorizer.authorizationStatus(for: accessLevel))
        }
    }

    private func write(_ request: PhotoExportRequest) async -> PhotoExportOutcome {
        do {
            return .exported(try await writer.write(request))
        } catch {
            return .writeFailed(String(describing: error))
        }
    }
}
