import FilmDomain
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

enum PrivacyCopy {
    static let deleteFilm = "Remove this Film and its captures from Immerse? Photos exports remain. Used Trial eligibility is not restored. Restoring an older iOS backup can bring the whole Film back."
    static let discard = "Remove this capture and its app-controlled copies? No exposures or time are refunded. Photos exports remain, and an older iOS backup can bring discarded media back."
    static let sources = "This choice cannot be changed. Originals are removed from Immerse only after a usable developed result is verified, and, if selected, after saving to Photos succeeds. Older iOS backups can restore removed originals."
    static let backup = "Films, sealed captures and reversible edits are included in iOS device backups. Immerse provides no sync or app-managed backup. Without an iOS backup, losing this iPhone loses its Films. Restoring an older backup can bring back discarded media and deleted Films."
}
