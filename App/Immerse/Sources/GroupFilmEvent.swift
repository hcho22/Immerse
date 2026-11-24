import CoreImage.CIFilterBuiltins
import FilmDomain
import ImmerseServer
#if APPCLIP
import StoreKit
#endif
import SwiftUI

/// A Group Film's page (v2 PRD sections 5.2 to 5.9): what the event is and when it ends and reveals, the countdown, the
/// album's end notices, then the member's Roll (the camera, what still waits to upload, their own Instant prints, and
/// Withdraw Before Reveal or leaving) and the Host's controls (the QR code and link, the counts and guests, pausing,
/// replacing the code, adding Rolls, the times, ending early and deleting), and after the reveal the album.
struct GroupFilmEventView: View {
    @Environment(\.groupFilms) private var groupFilms
    let eventID: String
    @State private var shooting = false
    @State private var confirmWithdraw = false
    @State private var confirmLeave = false
    @State private var editingName = false
    #if APPCLIP
    @State private var inviting = false
    #endif

    private var place: LocalPlace? { groupFilms?.place(eventID) }

    var body: some View {
        ScrollView {
            if let groupFilms, let place {
                VStack(alignment: .leading, spacing: 16) {
                    header(place)
                    if place.place == .removed {
                        OrbitNote(.info, "You can no longer take part in this event.", identifier: "group-removed")
                    } else {
                        timing(place)
                        if let notice = groupFilms.notice { OrbitNote(.info, notice, identifier: "group-notice") }
                        if let warning = groupFilms.rolls.storage.warning(for: .capture), place.place == .joined {
                            LowStorageNotice(text: warning)
                        }
                        if place.summary.phase == .revealed {
                            GroupAlbumSection(eventID: eventID)
                            #if APPCLIP
                            OrbitNote(.info, GroupFilmsCopy.miniAppInstall, identifier: "group-get-immerse")
                            #endif
                        }
                        if place.place == .joined || place.place == .left { roll(place, groupFilms) }
                        #if !APPCLIP
                        if place.isHost { GroupHostSection(eventID: eventID) }
                        #endif
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Orbit.gutter).padding(.vertical, 16)
            } else {
                Text("This event is no longer on this iPhone.").orbitFont(.body).foregroundStyle(Orbit.body).padding()
            }
        }
        .orbitGround()
        .navigationTitle(place?.summary.title ?? "Group Film")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await groupFilms?.sync(eventID) }
        .task { await groupFilms?.sync(eventID); await groupFilms?.countWaiting() }
        .onAppear {
            // In the mini-app, a guest who has just taken a Roll goes straight to the camera (V2-FR-21).
            if groupFilms?.shootOnArrival == eventID, place?.rollFilmID != nil {
                groupFilms?.shootOnArrival = nil
                shooting = true
            }
            #if APPCLIP
            inviting = place?.summary.phase == .revealed
            #endif
        }
        #if APPCLIP
        // After the reveal, the invitation to install the full app, which would have told the guest the Film was ready
        // (V2-FR-71; Apple: "Recommending your app to App Clip users").
        .appStoreOverlay(isPresented: $inviting) { SKOverlay.AppClipConfiguration(position: .bottom) }
        #endif
        .fullScreenCover(isPresented: $shooting, onDismiss: {
            groupFilms?.rolls.capture.endShootingSession()
            groupFilms?.startDevelopment()
        }) {
            if let groupFilms, let filmID = place?.rollFilmID {
                CaptureView(filmID: filmID)
                    .environment(groupFilms.rolls)
                    .environment(\.eventShooting, EventShooting(endsAt: place?.summary.endsAt ?? .now))
            }
        }
        .orbitConfirmation(isPresented: $confirmWithdraw, symbol: "arrow.uturn.backward", title: "Withdraw Before Reveal?",
                           message: GroupFilmsCopy.withdraw, confirm: "Withdraw", identifier: "confirm-withdraw") {
            Task { await groupFilms?.withdraw(eventID) }
        }
        .orbitConfirmation(isPresented: $confirmLeave, symbol: "rectangle.portrait.and.arrow.right", title: "Leave this event?",
                           message: GroupFilmsCopy.leave, confirm: "Leave", identifier: "confirm-leave") {
            Task { await groupFilms?.leave(eventID) }
        }
        .sheet(isPresented: $editingName) {
            if let place { GuestNameEditor(eventID: eventID, name: place.guestName ?? "") }
        }
    }

    private func header(_ place: LocalPlace) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(place.summary.title).orbitFont(.title).accessibilityAddTraits(.isHeader).accessibilityIdentifier("group-event-title")
            Text(place.summary.hostLeft ? "The Host has left Immerse" : "Hosted by \(place.summary.hostName ?? "the Host")")
                .orbitFont(.body).foregroundStyle(Orbit.body)
                .accessibilityIdentifier("group-event-host")
            Text([GroupFilmsCopy.camera(place.summary.camera), "\(place.summary.exposuresPerRoll) exposures a Roll",
                  GroupFilmsCopy.filmStock(place.summary.filmStock)].compactMap { $0 }.joined(separator: " · "))
                .orbitFont(.footnote).foregroundStyle(Orbit.label)
        }
    }

    /// When the event opens, ends and reveals, with the countdown to the reveal (V2-FR-38) and the album's end notices
    /// (V2-FR-48).
    @ViewBuilder private func timing(_ place: LocalPlace) -> some View {
        let summary = place.summary
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 6) {
                switch summary.phase {
                case .scheduled:
                    Text("Opens \(GroupFilmsCopy.time(summary.opensAt))").orbitFont(.headline)
                    Text("Shooting ends \(GroupFilmsCopy.time(summary.endsAt))").orbitFont(.body).foregroundStyle(Orbit.body)
                case .open, .ended:
                    if context.date < summary.endsAt {
                        Text("Shooting ends \(GroupFilmsCopy.time(summary.endsAt))").orbitFont(.headline)
                    } else {
                        Text("Shooting has ended").orbitFont(.headline)
                    }
                    Text("The album reveals in \(countdown(to: summary.revealsAt, from: context.date))")
                        .orbitFont(.body).foregroundStyle(Orbit.body)
                        .accessibilityIdentifier("group-countdown")
                case .revealed:
                    Text("The album has revealed").orbitFont(.headline)
                case .gone, .deleted:
                    Text("This event is no longer available.").orbitFont(.headline)
                }
                if summary.joiningPaused, summary.phase == .scheduled || summary.phase == .open {
                    Text("Joining is paused for now.").orbitFont(.footnote).foregroundStyle(Orbit.label)
                }
            }
        }
        if summary.albumNotice != .none {
            OrbitNote(.info, "This album ends \(GroupFilmsCopy.time(summary.albumEndsAt)). Save the pictures you want to keep.",
                      identifier: "group-album-ends")
        }
    }

    private func countdown(to date: Date, from now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let days = seconds / 86_400, hours = seconds % 86_400 / 3_600, minutes = seconds % 3_600 / 60
        if days > 0 { return "\(days) d \(hours) h" }
        if hours > 0 { return "\(hours) h \(minutes) min" }
        return minutes > 0 ? "\(minutes) min" : "less than a minute"
    }

    /// The member's Roll (V2-FR-25 to V2-FR-35, V2-FR-50, V2-FR-56).
    @ViewBuilder private func roll(_ place: LocalPlace, _ groupFilms: GroupFilms) -> some View {
        let film = place.rollFilmID.flatMap { groupFilms.rolls.film($0) }
        OrbitSectionLabel("Your Roll").padding(.leading, 4).padding(.top, 8)
        let shootingOpen = (place.summary.phase == .open || place.summary.phase == .scheduled) && Date.now < place.summary.endsAt
        if let film, !shootingOpen {
            let taken = film.captures.count
            Text(taken == 0 ? "Shooting has ended" : "Shooting has ended. You took \(taken) \(taken == 1 ? "picture" : "pictures").")
                .orbitFont(.body, weight: .semibold).accessibilityIdentifier("group-exposures-left")
        } else if let film {
            let left = film.remainingExposures ?? 0
            Text(left == 0 ? "Your Roll is finished" : "\(left) of \(place.summary.exposuresPerRoll) exposures left")
                .orbitFont(.body, weight: .semibold).accessibilityIdentifier("group-exposures-left")
            if place.place == .joined, place.summary.phase == .open, left > 0 {
                Button("Open Camera") { shooting = true }
                    .primaryAction()
                    .accessibilityIdentifier("group-open-camera")
            }
        }
        let waiting = groupFilms.waiting[eventID] ?? 0
        let sent = groupFilms.sent[eventID] ?? 0
        if waiting > 0 || sent > 0 {
            Text(waiting > 0 ? "\(waiting) waiting to send, \(sent) sent" : "All your pictures are sent")
                .orbitFont(.footnote).foregroundStyle(Orbit.label)
                .accessibilityIdentifier("group-upload-count")
        }
        #if APPCLIP
        // The mini-app sends only while it is open (V2-FR-35), and says so while anything waits.
        if waiting > 0 {
            OrbitNote(.info, GroupFilmsCopy.miniAppKeepOpen, identifier: "group-keep-open")
        }
        #endif
        if let film, film.camera.revealRule == .instantPerExposure, place.summary.phase != .revealed {
            let prints = film.captures.filter { $0.revealState == .revealed && !$0.isDiscarded }
            if !prints.isEmpty {
                Text("Your prints, seen only by you until the reveal").orbitFont(.footnote).foregroundStyle(Orbit.label)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(prints) { print in
                        RevealedPhoto(filmID: film.id, sequence: print.sequenceNumber, takesItsShape: true)
                            .environment(groupFilms.rolls)
                    }
                }
            }
        }
        if place.place == .left {
            Text("You left this event. Your pictures stay, and you will see the album after the reveal. While it is open you can rejoin through its link.")
                .orbitFont(.footnote).foregroundStyle(Orbit.label).fixedSize(horizontal: false, vertical: true)
        }
        if place.asGuest {
            #if APPCLIP
            Text(GroupFilmsCopy.miniAppPlace).orbitFont(.footnote).foregroundStyle(Orbit.label)
                .fixedSize(horizontal: false, vertical: true)
            #else
            Text(GroupFilmsCopy.unsignedPlace).orbitFont(.footnote).foregroundStyle(Orbit.label)
                .fixedSize(horizontal: false, vertical: true)
            #endif
            if groupFilms.hosting.isSignedIn {
                Button("Keep My Place with My Account") { Task { await groupFilms.claimGuestPlaces() } }
                    .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 48, fullWidth: true))
                    .accessibilityIdentifier("group-claim")
            }
        }
        HStack(spacing: 12) {
            if place.guestName != nil {
                Button("Change Name") { editingName = true }
                    .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44))
            }
            if place.summary.phase != .revealed, (film?.captures.isEmpty == false) {
                Button("Withdraw Before Reveal") { confirmWithdraw = true }
                    .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44))
                    .accessibilityIdentifier("group-withdraw")
            }
            if place.place == .joined, !place.isHost, shootingOpen {
                Button("Leave") { confirmLeave = true }
                    .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44))
                    .accessibilityIdentifier("group-leave")
            }
        }
    }
}

private struct GuestNameEditor: View {
    @Environment(\.groupFilms) private var groupFilms
    @Environment(\.dismiss) private var dismiss
    let eventID: String
    @State var name: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Name", text: $name).modifier(GroupFieldLook())
                Text("It shows on all your pictures in this event, in their details only.").orbitFont(.footnote).foregroundStyle(Orbit.label)
                Button("Save") { Task { if await groupFilms?.setGuestName(eventID, name) == true { dismiss() } } }
                    .primaryAction().disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(Orbit.gutter)
            .orbitSheetGround(screen: true)
            .navigationTitle("Your Name").toolbarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

/// A confirmation for something named at the moment, such as a guest to remove.
struct GroupConfirmSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    let confirm: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title).orbitFont(.heading).multilineTextAlignment(.center)
            Text(message).orbitFont(.body).foregroundStyle(Orbit.body).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(confirm) { action(); dismiss() }
                .buttonStyle(OrbitPillStyle(kind: .white, minHeight: 56, fullWidth: true))
                .accessibilityIdentifier("group-confirm-action")
            Button("Cancel") { dismiss() }
                .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 56, fullWidth: true))
        }
        .foregroundStyle(.white)
        .padding(24)
        .presentationDetents([.medium, .large])
        .orbitSheetGround()
    }
}

#if !APPCLIP
/// The Host's controls (V2-FR-13 to V2-FR-17, V2-FR-26 to V2-FR-29, V2-FR-40, V2-FR-53 to V2-FR-55): the QR code and
/// link, the counts and guests, never a picture before the reveal, the reports, the settings allowed before and after
/// the start, and after the reveal the web album's switch (V2-FR-47). Hosting is the full app's alone.
struct GroupHostSection: View {
    @Environment(\.groupFilms) private var groupFilms
    let eventID: String
    @State private var confirmReplace = false
    @State private var confirmEnd = false
    @State private var confirmDelete = false
    @State private var removing: HostEventView.Guest?
    @State private var adding = 1
    @State private var editingTimes = false

    var body: some View {
        if let groupFilms, let place = groupFilms.place(eventID) {
            let view = groupFilms.hostViews[eventID]
            let phase = place.summary.phase
            let beforeEnd = phase == .scheduled || phase == .open
            VStack(alignment: .leading, spacing: 14) {
                OrbitSectionLabel("Your Group Film").padding(.leading, 4).padding(.top, 8)
                if let link = groupFilms.link(for: place) {
                    JoinCodeCard(link: link)
                } else if place.joinCode != nil {
                    OrbitNote(.info, "This build has no join link host, so the link and QR code cannot be made.")
                }
                if let rolls = view?.rolls {
                    Text("\(rolls.taken) of \(rolls.setAside) Rolls taken, \(rolls.free) free").orbitFont(.body, weight: .semibold)
                        .accessibilityIdentifier("group-roll-counts")
                    Text("\(view?.picturesArrived ?? 0) pictures have arrived. Nobody sees them before the reveal, you included.")
                        .orbitFont(.footnote).foregroundStyle(Orbit.label)
                }
                if place.place == .none, phase == .open {
                    Button("Shoot Too: Take a Roll") { Task { await groupFilms.takeHostRoll(eventID) } }
                        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 48, fullWidth: true))
                        .accessibilityIdentifier("group-host-take-roll")
                }
                if let guests = view?.guests, !guests.isEmpty {
                    OrbitSectionLabel("Guests").padding(.leading, 4)
                    ForEach(guests) { guest in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(guest.name + (guest.isHost ? " (you)" : "")).orbitFont(.body, weight: .semibold)
                                Text(guestLine(guest, of: place.summary.exposuresPerRoll)).orbitFont(.footnote).foregroundStyle(Orbit.label)
                            }
                            Spacer()
                            if !guest.isHost, guest.status != .removed, phase != .gone {
                                Button("Remove") { removing = guest }
                                    .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 36))
                                    .accessibilityLabel("Remove \(guest.name)")
                            }
                        }
                        .orbitRow()
                    }
                }
                if let reports = view?.reports, !reports.isEmpty {
                    OrbitSectionLabel("Reports").padding(.leading, 4)
                    ForEach(reports) { report in
                        Text("A picture was reported (\(GroupReportReasonCopy.title(report.reason))) \(GroupFilmsCopy.time(report.reportedAt)). Find it in the album to remove it.")
                            .orbitFont(.footnote).foregroundStyle(Orbit.body).orbitRow()
                    }
                }
                if beforeEnd {
                    Toggle(isOn: Binding(get: { place.summary.joiningPaused },
                                         set: { paused in Task { await groupFilms.setJoiningPaused(eventID, paused) } })) {
                        Text("Pause joining").orbitFont(.body, weight: .semibold)
                    }
                    .accessibilityIdentifier("group-pause")
                    Stepper(value: $adding, in: 1...max(1, min(200 - (view?.rolls?.setAside ?? 0), max(groupFilms.balance ?? 1, 1)))) {
                        Text("Add \(adding) \(adding == 1 ? "Roll" : "Rolls")").orbitFont(.body)
                    }
                    Button("Add Rolls") { Task { await groupFilms.addRolls(eventID, adding) } }
                        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44, fullWidth: true))
                        .disabled((groupFilms.balance ?? 0) < adding)
                        .accessibilityIdentifier("group-add-rolls")
                    Button("Change the Times") { editingTimes = true }
                        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44, fullWidth: true))
                    Button("Replace the Code") { confirmReplace = true }
                        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44, fullWidth: true))
                        .accessibilityIdentifier("group-replace-code")
                }
                if phase == .revealed {
                    // Off unless the Host turns it on, and off again at any time (V2-FR-47).
                    Toggle(isOn: Binding(get: { view?.webAlbum ?? false },
                                         set: { on in Task { await groupFilms.setWebAlbum(eventID, on) } })) {
                        Text("Share the album on the web").orbitFont(.body, weight: .semibold)
                    }
                    .disabled(view == nil || groupFilms.busy)
                    .accessibilityIdentifier("group-web-album")
                    Text(view?.webAlbum == true ? GroupFilmsCopy.webAlbumOn : GroupFilmsCopy.webAlbumOff)
                        .orbitFont(.footnote).foregroundStyle(Orbit.label).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("group-web-album-note")
                }
                if phase == .open {
                    Button("End Early") { confirmEnd = true }
                        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44, fullWidth: true))
                        .accessibilityIdentifier("group-end-early")
                }
                Button("Delete Event") { confirmDelete = true }
                    .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44, fullWidth: true))
                    .accessibilityIdentifier("group-delete")
            }
            .task { await groupFilms.refreshBalance() }
            .orbitConfirmation(isPresented: $confirmReplace, symbol: "qrcode", title: "Replace the code?",
                               message: GroupFilmsCopy.replaceCode, confirm: "Replace", identifier: "confirm-replace-code") {
                Task { await groupFilms.replaceJoinCode(eventID) }
            }
            .orbitConfirmation(isPresented: $confirmEnd, symbol: "stop.circle", title: "End early?",
                               message: GroupFilmsCopy.endEarly, confirm: "End Early", identifier: "confirm-end-early") {
                Task { await groupFilms.endEarly(eventID); await groupFilms.sync(eventID) }
            }
            .orbitConfirmation(isPresented: $confirmDelete, symbol: "trash", title: "Delete this event?",
                               message: GroupFilmsCopy.deleteEvent, confirm: "Delete Event", identifier: "confirm-delete-event") {
                Task { await groupFilms.deleteEvent(eventID) }
            }
            .sheet(item: $removing) { guest in
                GroupConfirmSheet(title: "Remove \(guest.name)?", message: GroupFilmsCopy.removeGuest, confirm: "Remove") {
                    Task { await groupFilms.removeGuest(eventID, membershipID: guest.membershipId) }
                }
            }
            .sheet(isPresented: $editingTimes) { GroupTimesEditor(eventID: eventID, summary: place.summary) }
        }
    }

    private func guestLine(_ guest: HostEventView.Guest, of exposures: Int) -> String {
        switch guest.status {
        case .left: "Left · \(guest.exposuresUsed) of \(exposures) used"
        case .removed: "Removed"
        default: "\(guest.exposuresUsed) of \(exposures) used"
        }
    }
}

/// The Host moves the Start Time until the event opens, and the End Time and Reveal Delay until the End Time, within
/// V2-FR-12's limits.
private struct GroupTimesEditor: View {
    @Environment(\.groupFilms) private var groupFilms
    @Environment(\.dismiss) private var dismiss
    let eventID: String
    let summary: EventSummary
    @State private var startsAt = Date.now
    @State private var endsAt = Date.now
    @State private var delayHours = 0

    var body: some View {
        NavigationStack {
            Form {
                if summary.phase == .scheduled {
                    DatePicker("Start Time", selection: $startsAt, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    Button("Open Now") { save(start: .now) }
                }
                DatePicker("End Time", selection: $endsAt, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                Stepper("Reveal: \(GroupFilmsCopy.revealDelay(TimeInterval(delayHours) * 3600))", value: $delayHours, in: 0...24)
                if let notice = groupFilms?.notice { Text(notice).foregroundStyle(.secondary) }
                Button("Save") {
                    save(start: summary.phase == .scheduled && startsAt != summary.startsAt ? .at(startsAt) : nil)
                }
            }
            .navigationTitle("The Times").toolbarTitleDisplayMode(.inline)
        }
        .onAppear {
            startsAt = summary.startsAt ?? .now
            endsAt = summary.endsAt
            delayHours = Int(summary.revealDelayMs / 3_600_000)
        }
    }

    private func save(start: EventServer.StartChange?) {
        Task {
            let saved = await groupFilms?.updateTimes(eventID, start: start, endsAt: endsAt,
                                                      revealDelay: TimeInterval(delayHours) * 3600) == true
            if saved { await groupFilms?.sync(eventID); dismiss() }
        }
    }
}

/// The event's link and QR code, to print or share (V2-FR-15).
struct JoinCodeCard: View {
    let link: URL

    var body: some View {
        VStack(spacing: 12) {
            if let image = QRCode.image(for: link) {
                Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                    .frame(maxWidth: 220).padding(12).background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("QR code for the event's link")
                    .accessibilityIdentifier("group-qr")
                HStack(spacing: 12) {
                    ShareLink(item: link) { Label("Share Link", systemImage: "square.and.arrow.up") }
                        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44))
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("QR code", image: Image(uiImage: image))) {
                        Label("Share QR Code", systemImage: "qrcode")
                    }
                    .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 44))
                }
            }
            Text(link.absoluteString).orbitFont(.footnote).foregroundStyle(Orbit.label).textSelection(.enabled)
                .accessibilityIdentifier("group-link")
            Text("Guests join by scanning the code or opening the link on an iPhone, with nothing to install. It stays the same for the event's whole life.")
                .orbitFont(.footnote).foregroundStyle(Orbit.label).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

enum QRCode {
    /// The link as a QR code image, sharp at print sizes.
    static func image(for link: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(link.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }
}

#endif

enum GroupReportReasonCopy {
    static func title(_ reason: ReportReason) -> String {
        switch reason {
        case .sexual: "nudity or sexual content"
        case .violence: "violence or harm"
        case .harassment: "harassment or bullying"
        case .privacy: "shows someone without their consent"
        case .other: "something else"
        }
    }
}
