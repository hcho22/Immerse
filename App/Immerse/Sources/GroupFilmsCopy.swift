import Foundation
import ImmerseServer

/// The words Group Films say (v2 PRD V2-FR-18 and section 7), in one place: why a link cannot be joined, what a refusal
/// means, and the warnings before what cannot be undone. No case shows an empty page, a spinner that never ends, or an
/// error code.
enum GroupFilmsCopy {
    /// The sharing rule the Join Confirmation and Load Film state (V2-FR-13, V2-FR-21).
    static func sharingRule(instant: Bool) -> String {
        let own = instant ? "Each Instant print shows to the person who took it at once; everyone else sees it at the reveal."
            : "Every picture stays sealed until the reveal, yours included."
        return "\(own) After the reveal, everyone who joined sees every picture."
    }

    /// What a Join Code's link shows when the person cannot join now (V2-FR-18's rows), or nil when they can.
    static func joinStatus(_ preview: JoinPreview) -> String? {
        switch preview.status {
        case .open, .member: nil
        case .notYetOpen:
            "This event opens \(preview.event.map { Self.time($0.opensAt) } ?? "later"). Come back then."
        case .paused: "Joining is paused for now."
        case .full: "Every Roll has been taken. The Host can add more."
        case .ended:
            preview.event.map { "Shooting has ended. The album reveals \(Self.time($0.revealsAt))." } ?? "Shooting has ended."
        case .removed: "You can no longer take part in this event."
        case .replaced: "This link no longer works. Ask the Host for the new one."
        case .unavailable, .unknown: "This event is no longer available."
        }
    }

    static func words(for error: Error) -> String {
        switch error as? ServerError {
        case .unreachable:
            return "Immerse could not reach its server. This needs a connection; check it and try again."
        case .refused(let code):
            return words(for: code)
        case .failed:
            return "Something went wrong on Immerse's server. Try again."
        case nil:
            if error is GuestIdentityStoreError { return "Immerse could not read this iPhone's guest identity. Try again." }
            return FailureCopy.message(for: error) ?? "Something went wrong. Try again."
        }
    }

    static func words(for code: RefusalCode) -> String {
        switch code {
        case .notYetOpen: "This event has not opened yet. Come back at its Start Time."
        case .joiningPaused: "Joining is paused for now."
        case .rollsTaken: "Every Roll has been taken. The Host can add more."
        case .shootingEnded: "Shooting has ended for this event."
        case .removedFromEvent: "You can no longer take part in this event."
        case .codeReplaced: "This link no longer works. Ask the Host for the new one."
        case .unknownCode, .eventGone: "This event is no longer available."
        case .rollLimit: "An event has at most 200 Rolls."
        case .balanceTooLow: "Your balance does not hold that many Rolls. Buy Rolls or set aside fewer."
        case .notRevealed: "That waits for the reveal."
        case .alreadyRevealed: "The album has already revealed."
        case .identityClaimed: "This iPhone's guest identity belongs to another Account."
        case .notTheHost: "Only the event's Host can do that."
        case .unauthenticated, .noAccount, .accountDeleted: "Sign in again to do that."
        case .invalid: "Check the details and try again."
        case .guestTokenRefused, .notAMember: "This iPhone no longer has a place in this event."
        default: "Something went wrong on Immerse's server. Try again."
        }
    }

    /// A time in the person's own time zone (V2-FR-12): "today at 22:00", "on 12 December at 10:00".
    static func time(_ date: Date) -> String {
        let calendar = Calendar.current
        let clock = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "today at \(clock)" }
        if calendar.isDateInTomorrow(date) { return "tomorrow at \(clock)" }
        return "on \(date.formatted(.dateTime.weekday(.wide).day().month(.wide))) at \(clock)"
    }

    static func revealDelay(_ seconds: TimeInterval) -> String {
        let hours = Int((seconds / 3600).rounded(.down))
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600) / 60).rounded())
        switch (hours, minutes) {
        case (0, 0): return "At the End Time"
        case (0, _): return "\(minutes) min after the End Time"
        case (_, 0): return hours == 1 ? "1 hour after the End Time" : "\(hours) hours after the End Time"
        default: return "\(hours) h \(minutes) min after the End Time"
        }
    }

    static func camera(_ camera: EventCamera) -> String {
        switch camera {
        case .disposable: "Disposable"
        case .sixBySix: "6×6"
        case .instant: "Instant"
        }
    }

    static func filmStock(_ stock: EventFilmStock?) -> String? {
        switch stock {
        case .color: "Color"
        case .blackAndWhite: "Black and white"
        case nil: nil
        }
    }

    static let savedCopiesNote = "A saved picture is your own copy, outside Immerse. Removing it from the album later cannot recall it."
    static let withdraw = "Every picture you took in this event is removed for good, unseen, including any still waiting on this iPhone. Nobody can bring them back, and no exposures come back. You can keep shooting with what is left of your Roll until shooting ends."
    static let removeMine = "This picture leaves the album for everyone, for good. No exposure comes back. Copies others already saved to Photos cannot be recalled."
    static let removeAsHost = "This picture leaves the album for everyone, for good. Copies members already saved to Photos cannot be recalled."
    static let removeGuest = "Every picture this guest took in the event goes with them, for everyone, for good, and they can no longer take part. Copies members already saved to Photos cannot be recalled."
    static let replaceCode = "The old link and QR code, including every printed copy, stop working at once and for good. Guests who joined keep their place."
    static let endEarly = "Shooting stops for everyone at once, and the album reveals now. Rolls nobody took return to your balance."
    static let deleteEvent = "Every picture is removed for everyone, for good, and the link stops working. Copies already saved to Photos cannot be recalled. Rolls nobody took return to your balance."
    static let leave = "You stop shooting in this event, and your Roll stays used. Your pictures stay, and you still see the album after the reveal. While the event is open you can rejoin through its link."
    static let unsignedPlace = "Your place lives on this iPhone only. If you lose or replace it without signing in, your place cannot be recovered. Signing in keeps it on any iPhone."
    static let webAlbumOn = "Anyone with the event's link can see and save the pictures on the web while this is on, without Immerse. Switching it off takes them off the web at once; copies already saved cannot be recalled."
    static let webAlbumOff = "Off: the pictures are seen only by the people who joined. Switched on, anyone with the event's link can see and save them on the web, such as guests with an Android phone."
    /// The mini-app (V2-FR-35, V2-FR-71, open checks OC-6 and OC-10).
    static let miniAppKeepOpen = "Keep Immerse open until all your pictures are sent, or come back through the same link. This mini-app sends only while it is open, and the pictures wait on this iPhone alone until then."
    static let miniAppPlace = "Your place lives on this iPhone only, in a mini-app that iOS can clear when it has not been used for a while. Installing Immerse keeps your place, your Roll and any pictures still waiting."
    static let miniAppInstall = "Get Immerse to be told when a Film is ready, to save a whole album to Photos, and to keep your place."
    static let miniAppSaveAll = "This mini-app saves one picture at a time, through the share sheet. Get Immerse to save the whole album to Photos."
    static let miniAppSaveAllOnTheWeb = "This mini-app saves one picture at a time, through the share sheet. To save them all, get Immerse or open the event's link in Safari, where the Host shares the album."
    static let deleteGuestIdentity = "Every picture this iPhone's guest identity took, in every Group Film it joined, is removed for everyone, with any still waiting here. Copies others already saved to Photos cannot be recalled."
}

/// The balance's words on the screens that set Rolls aside (V2-FR-61, V2-FR-65, section 7).
enum RollsCopy {
    static func tooFew(_ balance: Int) -> String {
        balance < 0
            ? "A refund took your balance below zero. Rolls can be set aside again once it is above zero."
            : "Your balance holds \(balance) \(balance == 1 ? "Roll" : "Rolls"). Buy Rolls or set aside fewer."
    }
}
