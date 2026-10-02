import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import NativeAdapters
import SwiftUI

extension CameraPackage {
    var shortName: String {
        switch id {
        case .disposable1990s: "Disposable"
        case .instant1970s: "Instant"
        case .mediumFormat6x6: "6x6"
        case .super8HomeMovie: "Super 8"
        case .cinema16mm: "16mm"
        }
    }

    var symbol: String { medium == .photo ? "camera" : "movieclapper" }
    var capacityLabel: String {
        switch capacity {
        case let .exposures(count): "\(count) exposures"
        case let .seconds(count): "\(count / 60):\(String(format: "%02d", count % 60)) of film"
        }
    }
    var revealLabel: String {
        switch revealRule {
        case .rollLevelDevelopment: "Sealed until Development"
        case .instantPerExposure: "An individual print with every exposure"
        case .movieDevelopment: "One silent Movie after Development"
        }
    }
    var controlsLabel: String {
        switch id {
        case .disposable1990s: "Fixed focus, optional flash"
        case .instant1970s: "Square prints"
        case .mediumFormat6x6: "Square framing, deliberate focus and exposure"
        case .super8HomeMovie: "Handheld, pronounced grain and flicker"
        case .cinema16mm: "Deliberate framing, finer grain"
        }
    }
}

extension Film {
    var journalState: String {
        if developmentState == .developed { return "Developed" }
        if developmentState == .developing { return "Developing" }
        if completionState != .open {
            return camera.revealRule == .instantPerExposure ? "Pack complete" : "Ready to develop"
        }
        return "On the roll"
    }

    var remainingLabel: String {
        if case let .completedEarly(wasted) = completionState {
            switch wasted {
            case let .exposures(count): return "\(count) exposures wasted"
            case let .seconds(count): return String(format: "%.3f seconds wasted", count)
            }
        }
        if let remainingExposures { return "\(remainingExposures) exposures left" }
        return String(format: "%.3f seconds left", remainingMovieSeconds ?? 0)
    }

    var exactWasteLabel: String {
        if let remainingExposures { return "\(remainingExposures) unused exposures" }
        return "\(String(remainingMovieSeconds ?? 0)) unused seconds"
    }

    var progress: Double {
        if completionState != .open { return 1 }
        switch camera.capacity {
        case let .exposures(total): return Double(savedCaptureCount) / Double(total)
        case let .seconds(total): return consumedMovieSeconds / Double(total)
        }
    }
}

extension Color {
    /// Fill for filled actions. The dark-mode accent is too light under a white label, so filled
    /// actions use a deeper green that keeps both the label and the fill's edge readable.
    static let primaryAction = Color("PrimaryAction")
}

extension View {
    func primaryAction() -> some View { buttonStyle(.borderedProminent).tint(.primaryAction) }
}

enum PrivacyCopy {
    static let deleteFilm = "Remove this Film and its captures from Immerse? Photos exports remain. Used Trial eligibility is not restored. Restoring an older iOS backup can bring the whole Film back."
    static let discard = "Remove this capture and its app-controlled copies? No exposures or time are refunded. Photos exports remain, and an older iOS backup can bring discarded media back."
    static let sources = "This choice cannot be changed. Originals are removed from Immerse only after a usable developed result is verified, and, if selected, after saving to Photos succeeds. Older iOS backups can restore removed originals."
    static let backup = "Films, sealed captures and reversible edits are included in iOS device backups. Immerse provides no sync or app-managed backup. Without an iOS backup, losing this iPhone loses its Films. Restoring an older backup can bring back discarded media and deleted Films."
}

enum FailureCopy {
    static let retry = "The operation did not finish. Saved captures remain private; retry after checking available storage."

    /// User-facing text for a failed operation, or nil when the person cancelled it.
    static func message(for error: Error) -> String? {
        switch error {
        case is CancellationError: return nil
        case JournalError.cameraDenied:
            return "Camera access is off. Allow Camera for Immerse in iPhone Settings. Saved captures are unchanged."
        case JournalError.subscriptionUnavailable:
            return "Subscriptions are not available in this build. Your existing Films remain usable."
        case JournalError.subscriptionRequired:
            return "This iPhone's Trial is used. An active subscription is required to load another Film. Your existing Films remain usable."
        case JournalError.trialInProgress:
            return "This iPhone already has an unused Trial Film. Open it in your Journal, or delete that empty Film before loading another."
        case PersistenceError.capacityChangedSinceConfirmation:
            return "A capture finished saving while confirmation was open. The Film is still open. Check the updated remaining capacity and confirm again."
        case FilmExportError.permissionDenied:
            return "Photos access is off, so nothing was saved and this Film is unchanged. Allow Immerse to add to Photos in iPhone Settings, then save again."
        case FilmExportError.needsPermission:
            return "Photos access was not granted, so nothing was saved and this Film is unchanged. Save again to answer the Photos request."
        case FilmExportError.writeFailed:
            return "Photos could not finish saving, so this Film is unchanged. Anything already saved stays in Photos. Check available storage, then save again."
        case let error as TrialKeychainError:
            return "Immerse could not read or update this iPhone's secure Trial record (Keychain \(error.status)). Trial eligibility has not been reset, and any capture waiting to save stays private. Try again while your iPhone is unlocked."
        case FilmExportError.missingReceipt:
            return "Photos did not confirm the save, so this Film is unchanged. A copy may already be in Photos; check there before saving again."
        default:
            return [retry, systemDetail(for: error)].compactMap { $0 }.joined(separator: " ")
        }
    }

    /// A system-provided description such as "there isn't enough space". Swift errors
    /// without their own text bridge into a domain named after their type and would read
    /// as "(Module.Type error N.)", so those add nothing.
    static func systemDetail(for error: Error) -> String? {
        guard error is LocalizedError || (error as NSError).domain != String(reflecting: type(of: error)) else { return nil }
        return error.localizedDescription
    }
}

enum PermissionCopy {
    static func label(_ status: CaptureAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "Not asked yet"
        case .authorized: "Allowed"
        case .denied: "Off"
        case .restricted: "Restricted"
        }
    }

    static func label(_ status: PhotoLibraryAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "Not asked yet"
        case .authorized: "Allowed"
        case .limited: "Limited"
        case .denied: "Off"
        case .restricted: "Restricted"
        }
    }
}
