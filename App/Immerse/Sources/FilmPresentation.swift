import Accessibility
import AVFoundation
import EntitlementCore
import FilmDomain
import FilmPersistence
import FilmRuntime
import NativeAdapters
import RenderCore
import SwiftUI

extension CameraPackage {
    var shortName: String {
        switch id {
        case .disposable1990s: "Disposable"
        case .instant1970s: "Instant"
        case .mediumFormat6x6: "6×6"
        case .super8HomeMovie: "Super 8"
        case .cinema16mm: "16mm"
        }
    }

    /// The Camera's names as text that VoiceOver reads naturally. Every view that shows a name uses these; a navigation
    /// title uses `SpokenText.title`.
    var shortNameText: Text { Text(SpokenText.shown(shortName)) }
    /// The title Load Film suggests for this Camera's `roll`th Film, such as "6×6 - Roll #01".
    func suggestedTitle(roll: Int) -> String { "\(shortName) - Roll #\(String(format: "%02d", roll))" }

    /// Width over height of the cell a developed print is shown in on the Journal and Film screens: the Instant's
    /// card, and square for every other Camera, so a Disposable's 3:2 picture is letterboxed in its square cell.
    var printAspectRatio: CGFloat {
        id == .instant1970s ? CGFloat(InstantPrintCard.width) / CGFloat(InstantPrintCard.height) : 1
    }

    var symbol: String { medium == .photo ? "camera" : "movieclapper" }
    var capacityLabel: String { describedCapacity(MovieDurationText.clock) }

    /// What VoiceOver reads for `capacityLabel`, with Movie time in spoken units rather than "2:45".
    var capacitySpokenLabel: String { describedCapacity(MovieDurationText.spoken) }

    var capacityText: Text { Text(capacityLabel).accessibilityLabel(capacitySpokenLabel) }

    private func describedCapacity(_ duration: (Int) -> String) -> String {
        switch capacity {
        case let .exposures(count): "\(count) exposures"
        case let .seconds(count): "\(duration(count)) of film"
        }
    }
    var revealLabel: String {
        switch revealRule {
        case .rollLevelDevelopment: "Sealed until Development"
        case .instantPerExposure: "An individual print with every exposure"
        case .movieDevelopment: "One Movie after Development"
        }
    }
    /// What the photographer does with this Camera (PRD 2.1 sections 6.1 and 6.2).
    var controlsLabel: String {
        switch id {
        case .disposable1990s: "Focus switch: Auto / Fixed; tap to focus in Auto; fixed exposure, optional flash and low-light cue"
        case .instant1970s: "Auto focus with tap to focus; square picture on a white card"
        case .mediumFormat6x6: "Square framing; Focus switch: Auto / Manual; tap to focus in Auto; Focus slider in Manual; deliberate exposure; optical focus only"
        case .super8HomeMovie: "Handheld; Focus switch: Auto / Fixed; tap to focus in Auto; automatic exposure, 18 frames per second"
        case .cinema16mm: "Auto focus with tap to focus; deliberate framing, 24 frames per second"
        }
    }

    /// The Load Film sound line for a new movie Camera. The system asks only when its shooting screen first opens.
    var loadSoundLabel: String? {
        guard recordsLiveSound == true else { return nil }
        return "Sound: Recorded while filming when microphone access is allowed. The first request appears when you open the Camera."
    }

    /// How a Film from this Camera develops on the chosen Film Stock, one Load Film row per line; the 6×6 gives each
    /// Film Stock's look a line of its own, and the 16mm names the glow of the stock chosen (PRD 2.1 section 6.2).
    /// Names a look only in descriptive terms, never a maker or a film.
    func lookLines(filmStock: FilmStock?) -> [String] {
        switch id {
        case .disposable1990s: ["1990s disposable camera: borderless 3:2 picture, warm, saturated color, heavy grain, harsh flash and soft edges"]
        case .instant1970s: ["1970s instant camera: warm, faded color, soft contrast and soft detail"]
        case .mediumFormat6x6: ["Borderless square picture", "Color: natural, warm color, very fine grain and gentle contrast",
                                "Black and white: high contrast and distinct grain"]
        case .super8HomeMovie: ["1960s home-movie camera: muted color, a warm glow, fine grain, an unsteady frame, flicker, dust and hair"]
        case .cinema16mm:
            filmStock == .blackAndWhite
                ? ["Visible grain, a neutral highlight glow, minor jitter and weave, soft dark edges"]
                : ["Visible grain, a red highlight glow, minor jitter and weave, soft dark edges"]
        }
    }
}

extension FilmStock {
    /// The choice as Load Film and the Film screen name it; never a Format Reference's film (ADR 0015).
    var label: String {
        switch self {
        case .color: "Color"
        case .blackAndWhite: "Black and white"
        }
    }
}

/// Product text as VoiceOver should read it: the product spells "6×6", which VoiceOver would read as "6 times 6".
enum SpokenText {
    /// `text` as written, with each "6×6" pronounced "6 by 6". A pronunciation keeps the accessibility label the shown
    /// text: the clipped-text audit measures the label in the text's frame, and a "6 by 6" label, longer than the
    /// "6×6" drawn there, was reported as clipped.
    static func shown(_ text: String) -> AttributedString {
        var sixBySix = AttributedString("6×6")
        sixBySix.accessibilitySpeechPhoneticNotation = "sɪks baɪ sɪks"
        let parts = text.components(separatedBy: "6×6")
        return parts.dropFirst().reduce(AttributedString(parts[0])) { $0 + sixBySix + AttributedString($1) }
    }

    /// A navigation title, labeled with `of(text)`: the navigation bar drops a pronunciation, and the clipped-text
    /// audit does not measure the bar's title.
    static func title(_ text: String) -> Text { Text(text).accessibilityLabel(of(text)) }

    /// `text` with each "6×6" written as VoiceOver says it.
    static func of(_ text: String) -> String { text.replacingOccurrences(of: "6×6", with: "6 by 6") }
}

extension Film {
    /// The title as typed, which VoiceOver reads with any "6×6" spoken as "6 by 6", as in a suggested 6×6 title. Every
    /// view that shows the title uses this; a navigation title uses `SpokenText.title`.
    var titleText: Text { Text(SpokenText.shown(title)) }

    var journalState: String {
        if developmentState == .developed { return "Developed" }
        if developmentState == .developing { return "Developing" }
        if completionState != .open {
            return camera.revealRule == .instantPerExposure ? "Pack complete" : "Ready to develop"
        }
        return "On the roll"
    }

    /// Whether the Film's screen offers Resume Development: a Development under way, or an Instant print still sealed.
    var offersResumeDevelopment: Bool {
        developmentState == .developing || (camera.revealRule == .instantPerExposure && captures.contains { $0.revealState == .sealed })
    }

    var remainingLabel: String { remainingLabel(recordedFor: 0) }

    /// What VoiceOver reads for `remainingLabel`, with Movie time in spoken units rather than "2:45".
    var remainingSpokenLabel: String { remainingSpokenLabel(recordedFor: 0) }

    var remainingText: Text { remainingText(recordedFor: 0) }

    /// The remaining capacity while a clip has been recording for `elapsed` seconds. Movie time counts down in
    /// the same whole seconds as the resting line, so it starts where that line stood and changes once a second.
    func remainingLabel(recordedFor elapsed: TimeInterval) -> String { remaining(MovieDurationText.clock, elapsed) }

    func remainingSpokenLabel(recordedFor elapsed: TimeInterval) -> String { remaining(MovieDurationText.spoken, elapsed) }

    /// The compact count shown beside a Camera's name on the shooting screen: a number for photos and M:SS for Movies.
    func remainingAmountLabel(recordedFor elapsed: TimeInterval) -> String {
        if let remainingExposures { return String(remainingExposures) }
        return MovieDurationText.clock(MovieDurationText.wholeSeconds((remainingMovieSeconds ?? 0) - elapsed))
    }

    func remainingText(recordedFor elapsed: TimeInterval) -> Text {
        Text(remainingLabel(recordedFor: elapsed)).accessibilityLabel(remainingSpokenLabel(recordedFor: elapsed))
    }

    private func remaining(_ duration: (Int) -> String, _ elapsed: TimeInterval) -> String {
        if case let .completedEarly(wasted) = completionState {
            switch wasted {
            case let .exposures(count): return "\(count) exposures wasted"
            case let .seconds(seconds): return "\(duration(MovieDurationText.wholeSeconds(seconds))) wasted"
            }
        }
        if let remainingExposures { return "\(remainingExposures) exposures left" }
        return "\(duration(MovieDurationText.wholeSeconds((remainingMovieSeconds ?? 0) - elapsed))) left"
    }

    var exactWasteLabel: String {
        if let remainingExposures { return "\(remainingExposures) unused exposures" }
        return String(format: "%.3f unused seconds", remainingMovieSeconds ?? 0)
    }

    var progress: Double {
        if completionState != .open { return 1 }
        switch camera.capacity {
        case let .exposures(total): return Double(savedCaptureCount) / Double(total)
        case let .seconds(total): return consumedMovieSeconds / Double(total)
        }
    }
}

/// The short status beside the Camera name in the shooting screen's one-line header, and the full text VoiceOver reads.
struct CaptureHeaderStatus: Equatable {
    let visible: String
    let spoken: String

    static func make(for film: Film, finishingSave: Bool, recordedFor elapsed: TimeInterval) -> Self {
        let name = SpokenText.of(film.camera.shortName)
        if finishingSave {
            return Self(visible: "Finishing save", spoken: "\(name), Finishing save")
        }

        switch film.completionState {
        case .open:
            return Self(visible: film.remainingAmountLabel(recordedFor: elapsed),
                        spoken: "\(name), \(film.remainingSpokenLabel(recordedFor: elapsed))")
        case .capacityFull:
            let complete = film.camera.revealRule == .instantPerExposure ? "Pack complete" : "Film complete"
            return Self(visible: complete, spoken: "\(name), \(complete)")
        case .completedEarly:
            return Self(visible: "Ended early", spoken: "\(name), Ended early, \(film.remainingLabel)")
        }
    }
}

/// Movie time as the catalog, Load screen, Film rows and capture line show it, in minutes and seconds, so they
/// cannot drift.
enum MovieDurationText {
    /// Whole seconds, counting a partial second as a whole one, so "0:00" appears only when no frame is left
    /// and a new Film reads the same as its Camera's capacity.
    static func wholeSeconds(_ seconds: TimeInterval) -> Int {
        let frames = MovieFrames.count(seconds: seconds) ?? 0
        return (frames + MovieFrames.perSecond - 1) / MovieFrames.perSecond
    }

    /// "2:45", "0:09" or "0:00".
    static func clock(_ seconds: Int) -> String {
        "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }

    /// "2 minutes 45 seconds", "1 minute" or "0 seconds", for VoiceOver.
    static func spoken(_ seconds: Int) -> String {
        func units(_ count: Int, _ unit: String) -> String { "\(count) \(unit)\(count == 1 ? "" : "s")" }
        let minutes = seconds / 60, rest = seconds % 60
        if minutes == 0 { return units(rest, "second") }
        return rest == 0 ? units(minutes, "minute") : "\(units(minutes, "minute")) \(units(rest, "second"))"
    }
}

/// Stops of exposure as the Darkroom shows and speaks them, in tenths, so a value a slider leaves a hair off a tenth
/// never reads "-0.0" or is saved a hair outside its limit.
enum StopsText {
    /// `stops` at the nearest tenth inside `limits`.
    static func tenths(_ stops: Double, in limits: ClosedRange<Double>) -> Double {
        min(limits.upperBound, max(limits.lowerBound, (stops * 10).rounded() / 10 + 0))
    }

    /// "1.5 stops", "-3.0 stops" or "0.0 stops".
    static func shown(_ stops: Double) -> String {
        String(format: "%.1f stops", (stops * 10).rounded() / 10 + 0)
    }

    /// "plus 1.5 stops", "minus 3 stops" or "0 stops", for VoiceOver; a strength, which has no direction, is "1 stop".
    static func spoken(_ stops: Double, signed: Bool = true) -> String {
        let tenths = Int((abs(stops) * 10).rounded())
        let amount = tenths % 10 == 0 ? "\(tenths / 10)" : "\(tenths / 10).\(tenths % 10)"
        let sign = !signed || tenths == 0 ? "" : stops < 0 ? "minus " : "plus "
        return "\(sign)\(amount) stop\(tenths == 10 ? "" : "s")"
    }
}

extension Color {
    /// Fill for filled actions. The dark-mode accent is too light under a white label, so filled
    /// actions use a deeper green that keeps both the label and the fill's edge readable.
    static let primaryAction = Color("PrimaryAction")

    /// A symbol on a `primaryAction` glass circle, as the iOS 26 bottom toolbar drew it: the fill with white added,
    /// 66% in light mode and 59% in dark.
    static let primaryActionSymbol = Color("PrimaryActionSymbol")

    /// Secondary text on a card. On the white light-mode card the system secondary label is 3.44:1, under the
    /// 4.5:1 bar, so light mode raises its opacity to at least 71% (4.58:1); dark mode keeps the system color.
    static let cardSecondaryText = secondaryText(lightOpacity: 0.71)

    /// Secondary text on the gray ground of a sealed or discarded frame, which is darker than a card: there the
    /// system secondary label is 3.29:1 in light mode, so its opacity is at least 75% (4.82:1).
    static let frameSecondaryText = secondaryText(lightOpacity: 0.75)

    private static func secondaryText(lightOpacity: CGFloat) -> Color {
        Color(uiColor: UIColor { traits in
            let system = UIColor.secondaryLabel.resolvedColor(with: traits)
            guard traits.userInterfaceStyle != .dark else { return system }
            return system.withAlphaComponent(max(system.cgColor.alpha, lightOpacity))
        })
    }
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

/// A Development that stopped before it finished, with what stopped it, so its alert says why in Development's own
/// words and names the button on the Film's screen that carries on.
struct DevelopmentFailure: Error {
    let underlying: Error
    /// The Film screen's button that develops the Film again: Resume Development, or Rebuild Movie for a developed Movie.
    let retry: String
}

enum FailureCopy {
    /// The words for a failure nothing more is known about. They name no cause, storage included: a full iPhone has its
    /// own words (`outOfSpace`), and telling people to check storage for any other failure sent them looking for a cause
    /// that was not there.
    static let retry = "The operation did not finish. Saved captures remain private; try again."
    static let outOfSpace = "This iPhone is out of space, so the operation did not finish. Saved captures are unchanged. Free space in iPhone Settings, then try again."

    /// User-facing text for a failed operation, or nil when the person cancelled it.
    static func message(for error: Error) -> String? {
        if let failure = error as? DevelopmentFailure { return developmentMessage(for: failure) }
        if isOutOfSpace(error) { return outOfSpace }
        switch error {
        case is CancellationError: return nil
        case is DevelopmentSuspended:
            return "This stopped because Immerse left the screen. Saved captures are unchanged. Try again, and keep Immerse open until it finishes."
        case JournalError.cameraDenied:
            return "Camera access is off. Allow Camera for Immerse in iPhone Settings. Saved captures are unchanged."
        case JournalError.subscriptionUnavailable:
            return "Subscriptions are not available in this build. Your existing Films remain usable."
        case JournalError.subscriptionRequired:
            return "This iPhone's Trial is used. An active subscription is required to load another Film. Your existing Films remain usable."
        case JournalError.trialInProgress:
            return "This iPhone already has an unused Trial Film. Open it in your Journal, or delete that empty Film before loading another."
        case JournalError.operationInProgress, PersistenceError.operationInProgress:
            return "Another change to this Film is still finishing. Try again when it completes."
        case FilmDomainError.emptyTitle:
            return "A Film needs a title, so the current title is kept."
        case let FilmExportError.interrupted(saved, total):
            return "Saving to Photos stopped after \(saved) of \(total). Those copies stay in Photos; check Photos before saving again."
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
        case NativeRenderError.invalidRecipe:
            return "A print's Darkroom settings are outside what this version of Immerse can print, so nothing was changed or saved to Photos. The developed photo is unchanged. In that print's Darkroom, choose Reset to Original to print it again."
        case NativeRenderError.instantMasterWithoutCard:
            return "This print is not in the card format every Instant print uses, so it cannot be shown or edited. Nothing was changed."
        case FilmExportError.missingReceipt:
            return "Photos did not confirm the save, so this Film is unchanged. A copy may already be in Photos; check there before saving again."
        default:
            return [retry, systemDetail(for: error)].compactMap { $0 }.joined(separator: " ")
        }
    }

    /// What stopped a Development, and what the person can do. Storage is named only for a full iPhone.
    static func developmentMessage(for failure: DevelopmentFailure) -> String? {
        let error = failure.underlying
        let unchanged = "Saved captures are unchanged."
        let again = "Tap \(failure.retry) to try again."
        switch error {
        case is CancellationError: return nil
        case is DevelopmentSuspended:
            return "Development stopped because Immerse left the screen. \(unchanged) Tap \(failure.retry) and keep Immerse open until it finishes."
        case _ where isOutOfSpace(error):
            return "This iPhone is out of space, so Development stopped. \(unchanged) Free space in iPhone Settings, then tap \(failure.retry)."
        case NativeRenderError.tableReaderUnavailable:
            return "This iPhone could not prepare the colors of the Color Film Stock, so Development stopped. \(unchanged) \(again)"
        case NativeRenderError.unrenderableTreatment, PersistenceError.treatmentConflict:
            return "This Film began developing in a newer version of Immerse, so this version cannot finish it. \(unchanged) Update Immerse, then tap \(failure.retry)."
        case NativeRenderError.unreadableSource, NativeRenderError.invalidMovie, PersistenceError.invalidMedia,
             PersistenceError.unreadableMedia, PersistenceError.mediaChangedDuringVerification, PersistenceError.captureNotFound,
             PersistenceError.missingVerifiedMaster, PersistenceError.masterChecksumMismatch,
             PersistenceError.missingDevelopedClip, PersistenceError.clipChecksumMismatch:
            return "Immerse could not read one of this Film's photos or clips, so Development stopped. \(unchanged) \(again)"
        case NativeRenderError.writerFailed, NativeRenderError.writerTimedOut, NativeRenderError.renderFailed:
            return "Immerse could not finish writing this Film's developed photos or clips, so Development stopped. \(unchanged) \(again)"
        case PersistenceError.soundtrackUnavailable:
            return "The Soundtrack chosen for this Movie could not be read, so the Movie was not made. \(unchanged) Choose the Movie's sound again, or tap \(failure.retry)."
        case PersistenceError.soundtrackChanged:
            return "The Movie's sound changed while the Movie was being made. \(unchanged) Tap \(failure.retry) to make it with the sound now chosen."
        case PersistenceError.filmNotFound:
            return "This Film is no longer in your Journal, so it was not developed."
        case JournalError.operationInProgress, PersistenceError.operationInProgress:
            return message(for: error)
        default:
            return ["Development stopped before it finished. \(unchanged) \(again)", systemDetail(for: error)]
                .compactMap { $0 }.joined(separator: " ")
        }
    }

    /// Whether the error, or one it carries, is the system's or the Film store's report that the iPhone is full.
    static func isOutOfSpace(_ error: Error) -> Bool {
        switch error {
        case PersistenceError.outOfSpace: return true
        case let NativeRenderError.writerFailed(underlying?), let NativeRenderError.invalidMovie(underlying?):
            return isOutOfSpace(underlying)
        case is NativeRenderError, is PersistenceError: return false
        default: break
        }
        let error = error as NSError
        switch (error.domain, error.code) {
        case (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError), (NSPOSIXErrorDomain, Int(ENOSPC)),
             (NSPOSIXErrorDomain, Int(EDQUOT)), (AVFoundationErrorDomain, AVError.Code.diskFull.rawValue):
            return true
        default:
            return error.underlyingErrors.contains(where: isOutOfSpace)
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
