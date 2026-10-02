import Foundation

public enum CaptureAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

public enum PermissionPromptPolicy: Equatable, Sendable {
    case deferToFlowCoordinator
    case requestAtCaptureStart
}

public protocol CapturePermissionAuthorizing: Sendable {
    func authorizationStatus() -> CaptureAuthorizationStatus
    func requestAccess() async -> Bool
}

public enum CaptureStartupOutcome: Equatable, Sendable {
    case ready(CaptureSessionPlan)
    case needsPermission(PermissionPromptPolicy)
    case permissionDenied(CaptureAuthorizationStatus)
    case cameraUnavailable(CapturePosition)
}

public struct CaptureStartupCoordinator<Authorizer: CapturePermissionAuthorizing>: Sendable {
    private let authorizer: Authorizer
    private let capabilities: CaptureCapabilities

    public init(authorizer: Authorizer, capabilities: CaptureCapabilities) {
        self.authorizer = authorizer
        self.capabilities = capabilities
    }

    public func startOutcome(for request: CaptureSessionRequest) async -> CaptureStartupOutcome {
        switch authorizer.authorizationStatus() {
        case .authorized:
            return authorizedOutcome(for: request)
        case .notDetermined:
            guard request.permissionPromptPolicy == .requestAtCaptureStart else {
                return .needsPermission(request.permissionPromptPolicy)
            }
            guard await authorizer.requestAccess() else {
                return .permissionDenied(.denied)
            }
            return authorizedOutcome(for: request)
        case .denied:
            return .permissionDenied(.denied)
        case .restricted:
            return .permissionDenied(.restricted)
        }
    }

    private func authorizedOutcome(for request: CaptureSessionRequest) -> CaptureStartupOutcome {
        guard capabilities.isAvailable(request.preferredPosition) else {
            return .cameraUnavailable(request.preferredPosition)
        }
        return .ready(CaptureSessionPlan(request: request, capabilities: capabilities))
    }
}
