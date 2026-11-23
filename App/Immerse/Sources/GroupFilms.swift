import FilmDomain
import FilmPersistence
import FilmRuntime
import Foundation
import ImmerseServer
import Network
import Observation
import SwiftUI
import UIKit
import UserNotifications

extension EnvironmentValues {
    /// Group Films, where the app has a server; nil everywhere else, which hides every part of them.
    @Entry var groupFilms: GroupFilms? = nil
}

/// One Group Film this iPhone takes part in, as it last learned it from the server (v2 PRD section 6): the event, this
/// phone's place in it, and the local Film of its Roll when it holds one. Kept on the phone so a guest can shoot offline
/// after joining (V2-FR-31).
struct LocalPlace: Codable, Equatable, Identifiable {
    var id: String { eventID }
    let eventID: String
    var summary: EventSummary
    /// The signed-in Host hosts it.
    var isHost: Bool
    /// The place is the phone's guest identity's; otherwise it is the signed-in Account's.
    var asGuest: Bool
    /// Where this phone's person stands: in it with a Roll, left, removed, or no place (a Host who does not shoot).
    var place: EventPlace
    var rollFilmID: UUID?
    var guestName: String?
    var exposuresReported: Int = 0
    /// Withdraw Before Reveal made offline, up to this exposure, still to tell the server (V2-FR-50, section 7).
    var pendingWithdrawal: Int?
    /// The album's pictures saved to Photos, so saving the whole album resumes without duplicates (V2-FR-44).
    var savedPictures: Set<String> = []
    /// The reveal ritual has shown once (V2-FR-38).
    var revealSeen = false
    /// The Host's current Join Code and its generation, for the QR code and link.
    var joinCode: String?
    var joinCodeGeneration: Int?

    var caller: EventCaller.Kind { asGuest ? .guest : .account }
}

extension EventCaller {
    enum Kind: String, Codable { case guest, account }
}

/// What an event left behind on this iPhone when it ended for the phone: removed, deleted, or gone at the album's end.
struct EventEnding: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// A Join Code's link opened in the app (V2-FR-19).
struct JoinRequest: Identifiable, Equatable {
    let code: String
    var id: String { code }
}

/// Group Films on this iPhone (v2 PRD Stage 2): hosting, joining by link or QR code, shooting the event's Camera offline,
/// Development of each picture on the phone, the upload queue, the album after the reveal and every member and Host
/// action. It exists only where the app has a server configuration, and nothing of personal Films, the Trial or the
/// subscription reads it or waits on it (V2-FR-02, V2-FR-07); its Rolls live in a store of their own (`rolls`).
@MainActor @Observable
final class GroupFilms {
    let server: EventServer
    let hosting: HostingSession
    /// The Group Films' own Journal: the local Films of the Rolls this phone shoots, apart from personal Films, with a
    /// Trial store that refuses every use, so a Roll can never start, use or block the Trial (V2-FR-07).
    let rolls: JournalModel
    let queue: UploadQueue
    let joinHost: String?
    let supportAddress: String?
    /// Where `rolls` keeps its Films.
    let rollsRoot: URL
    private let identities: any GuestIdentityStoring
    private let placesURL: URL
    private let uploader: PictureUploader

    private(set) var places: [LocalPlace] = []
    /// Pictures waiting to upload, by event (V2-FR-35).
    private(set) var waiting: [String: Int] = [:]
    /// Pictures of each event this phone sent since it was opened, for "12 sent".
    private(set) var sent: [String: Int] = [:]
    /// The Host's latest view of each event they host.
    private(set) var hostViews: [String: HostEventView] = [:]
    private(set) var balance: Int?
    var joinRequest: JoinRequest?
    /// The event to show next, after Load Film, joining or a notification.
    var openEvent: String?
    var ending: EventEnding?
    /// A message for the person about the last action or what happened offline.
    var notice: String?
    private(set) var busy = false
    private var developing: Task<Void, Never>?
    private var uploading: Task<Void, Never>?
    private var developmentFailures: [String: Int] = [:]
    private var pathMonitor: NWPathMonitor?
    private var timer: Task<Void, Never>?
    private var active = true
    /// The Load Film request id, kept until it succeeds so a retried Load Film makes one event (V2-FR-81).
    private var loadRequestID: String?

    init(server: EventServer, hosting: HostingSession, rolls: JournalModel, rollsRoot: URL, queue: UploadQueue, root: URL,
         identities: any GuestIdentityStoring, joinHost: String?, supportAddress: String?, functions: any ServerFunctions) {
        self.server = server
        self.hosting = hosting
        self.rolls = rolls
        self.rollsRoot = rollsRoot
        self.queue = queue
        self.joinHost = joinHost
        self.supportAddress = supportAddress
        self.identities = identities
        self.placesURL = root.appending(path: "places.json")
        self.uploader = PictureUploader(functions: functions)
        places = (try? JSONDecoder().decode([LocalPlace].self, from: Data(contentsOf: placesURL))) ?? []
        hosting.accountDeleted = { [weak self] in self?.accountDeleted() }
    }

    // MARK: Places

    func place(_ eventID: String) -> LocalPlace? { places.first { $0.eventID == eventID } }

    /// The places shown now: the guest identity's always, the Account's while it is signed in.
    var visiblePlaces: [LocalPlace] {
        let signedIn = hosting.isSignedIn
        return places.filter { $0.asGuest || signedIn }
            .sorted { $0.summary.opensAt > $1.summary.opensAt }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: placesURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(places).write(to: placesURL, options: .atomic)
        } catch {
            notice = "Immerse could not save this iPhone's Group Films. Free space and try again."
        }
    }

    private func update(_ eventID: String, _ change: (inout LocalPlace) -> Void) {
        guard let index = places.firstIndex(where: { $0.eventID == eventID }) else { return }
        change(&places[index])
        save()
    }

    private func caller(for place: LocalPlace) throws -> EventCaller {
        place.asGuest ? .guest(try identities.identity()) : .account
    }

    /// Who joins through a link: the signed-in Account, so the place follows it to any iPhone, or else the phone's guest
    /// identity. Joining never asks anyone to sign in (V2-FR-02, V2-FR-21).
    private func joiningCaller() throws -> EventCaller {
        hosting.isSignedIn ? .account : .guest(try identities.identity())
    }

    /// Whether this phone holds a guest identity, for Delete Guest Identity in Settings (V2-FR-57).
    var hasGuestIdentity: Bool { (try? identities.read()) != nil }

    #if DEBUG
    /// Debug builds only: a place as a screen test's scenario sets it (`DebugGroupFilms`).
    func adoptForTesting(_ place: LocalPlace) {
        places.removeAll { $0.eventID == place.eventID }
        places.append(place)
        save()
    }
    #endif

    // MARK: Hosting

    func refreshBalance() async {
        balance = try? await server.balance()
    }

    /// Load Film (V2-FR-13): the event is made on the server, its Rolls set aside and its Join Code issued at once.
    func loadFilm(_ setup: EventSetup) async -> Bool {
        let requestID = loadRequestID ?? GuestIdentity.make().publicId
        loadRequestID = requestID
        return await run { [self] in
            let loaded = try await server.loadFilm(setup, requestID: requestID)
            loadRequestID = nil
            let view = try await server.hostView(eventID: loaded.eventId)
            hostViews[loaded.eventId] = view
            places.removeAll { $0.eventID == loaded.eventId }
            places.append(LocalPlace(eventID: loaded.eventId, summary: view.summary, isHost: true, asGuest: false, place: .none,
                                     joinCode: view.joinCode ?? loaded.joinCode, joinCodeGeneration: view.joinCodeGeneration))
            save()
            openEvent = loaded.eventId
            await refreshBalance()
            // Asked once the event's page is up, so the question never stands in the way of the event.
            Task { await askForTheAlert(as: .account) }
        }
    }

    func refreshHostView(_ eventID: String) async {
        guard place(eventID)?.isHost == true else { return }
        do {
            let view = try await server.hostView(eventID: eventID)
            hostViews[eventID] = view
            update(eventID) {
                $0.summary = view.summary
                $0.joinCode = view.joinCode
                $0.joinCodeGeneration = view.joinCodeGeneration
            }
        } catch .refused(.notTheHost) {
            update(eventID) { $0.isHost = false }
        } catch {}
    }

    /// The Host takes one Roll from their own event, like any guest (V2-FR-25).
    func takeHostRoll(_ eventID: String) async {
        guard let code = place(eventID)?.joinCode, case .signedIn(let name) = hosting.phase else { return }
        _ = await join(code: code, guestName: name)
    }

    func setJoiningPaused(_ eventID: String, _ paused: Bool) async {
        await hostAction(eventID) { try await self.server.setJoiningPaused(eventID: eventID, paused: paused) }
    }

    func replaceJoinCode(_ eventID: String) async {
        guard let generation = place(eventID)?.joinCodeGeneration else { return }
        await hostAction(eventID) { _ = try await self.server.replaceJoinCode(eventID: eventID, generation: generation) }
    }

    func addRolls(_ eventID: String, _ rolls: Int) async {
        let requestID = GuestIdentity.make().publicId
        await hostAction(eventID) { try await self.server.addRolls(eventID: eventID, rolls: rolls, requestID: requestID) }
        await refreshBalance()
    }

    func updateTimes(_ eventID: String, start: EventServer.StartChange?, endsAt: Date?, revealDelay: TimeInterval?) async -> Bool {
        await hostAction(eventID) {
            try await self.server.updateTimes(eventID: eventID, start: start, endsAt: endsAt, revealDelay: revealDelay)
        }
    }

    func endEarly(_ eventID: String) async {
        await hostAction(eventID) { try await self.server.endEarly(eventID: eventID) }
        await refreshBalance()
    }

    func rename(_ eventID: String, _ title: String) async -> Bool {
        await hostAction(eventID) { try await self.server.rename(eventID: eventID, title: title) }
    }

    func removeGuest(_ eventID: String, membershipID: String) async {
        await hostAction(eventID) { try await self.server.removeGuest(eventID: eventID, membershipID: membershipID) }
    }

    func removePictureAsHost(_ eventID: String, pictureID: String) async -> Bool {
        await hostAction(eventID) { try await self.server.removePictureAsHost(eventID: eventID, pictureID: pictureID) }
    }

    /// The Host deletes the whole event (V2-FR-55); this phone's own waiting pictures and prints for it go too.
    func deleteEvent(_ eventID: String) async {
        let deleted = await run { try await self.server.deleteEvent(eventID: eventID) }
        guard deleted else { return }
        await forget(eventID)
        await refreshBalance()
    }

    @discardableResult
    private func hostAction(_ eventID: String, _ work: @escaping @MainActor () async throws -> Void) async -> Bool {
        let done = await run(work)
        await refreshHostView(eventID)
        return done
    }

    // MARK: Joining

    func handle(url: URL) -> Bool {
        guard let joinHost, let code = JoinLink.code(in: url, host: joinHost) else { return false }
        joinRequest = JoinRequest(code: code)
        return true
    }

    func link(for place: LocalPlace) -> URL? {
        guard let joinHost, let code = place.joinCode else { return nil }
        return JoinLink.url(code: code, host: joinHost)
    }

    func preview(code: String) async throws(ServerError) -> JoinPreview {
        let caller: EventCaller
        do { caller = try joiningCaller() } catch { throw .failed("The guest identity is unavailable") }
        return try await server.preview(code: code, as: caller)
    }

    /// Joins, or rejoins, with only a Guest Name (V2-FR-21): the Roll's local Film is made so the guest can shoot offline.
    func join(code: String, guestName: String) async -> Bool {
        await run { [self] in
            let caller = try joiningCaller()
            let joined = try await server.join(code: code, guestName: guestName, as: caller)
            let eventID = joined.event.eventId
            var place = self.place(eventID) ?? LocalPlace(eventID: eventID, summary: joined.event, isHost: false,
                                                           asGuest: caller != .account, place: .joined)
            place.summary = joined.event
            place.place = .joined
            place.guestName = joined.guestName
            place.asGuest = caller != .account
            if place.rollFilmID == nil || rolls.film(place.rollFilmID!) == nil {
                let film = try rolls.loadEventRoll(eventID: eventID, camera: Self.package(for: joined.event.camera),
                                                   title: joined.event.title, filmStock: Self.filmStock(joined.event.filmStock))
                place.rollFilmID = film.id
            }
            places.removeAll { $0.eventID == eventID }
            places.append(place)
            save()
            joinRequest = nil
            openEvent = eventID
            Task { await askForTheAlert(as: caller) }
        }
    }

    static func package(for camera: EventCamera) -> CameraPackage {
        switch camera {
        case .disposable: CameraCatalog.disposable1990s
        case .sixBySix: CameraCatalog.mediumFormat6x6
        case .instant: CameraCatalog.instant1970s
        }
    }

    static func filmStock(_ stock: EventFilmStock?) -> FilmStock? {
        switch stock {
        case .color: .color
        case .blackAndWhite: .blackAndWhite
        case nil: nil
        }
    }

    // MARK: The member

    func leave(_ eventID: String) async {
        guard let place = place(eventID) else { return }
        let left = await run { try await self.server.leave(eventID: eventID, as: try self.caller(for: place)) }
        if left { update(eventID) { $0.place = .left } }
    }

    func setGuestName(_ eventID: String, _ name: String) async -> Bool {
        guard let place = place(eventID) else { return false }
        let done = await run { try await self.server.setGuestName(eventID: eventID, name: name, as: try self.caller(for: place)) }
        if done { update(eventID) { $0.guestName = name.trimmingCharacters(in: .whitespacesAndNewlines) } }
        return done
    }

    /// Withdraw Before Reveal (V2-FR-50): every picture of the guest's goes for good. What waits on this phone, and its
    /// Instant prints, are deleted at once, offline included; the server is told now or when the phone is next online.
    func withdraw(_ eventID: String) async {
        guard let place = place(eventID), let filmID = place.rollFilmID else { return }
        let used = rolls.film(filmID)?.captures.count ?? 0
        await retireLocally(place, throughExposure: used)
        update(eventID) { $0.pendingWithdrawal = max($0.pendingWithdrawal ?? 0, used) }
        await sendPendingWithdrawal(eventID)
    }

    private func sendPendingWithdrawal(_ eventID: String) async {
        guard let place = place(eventID), let through = place.pendingWithdrawal, let caller = try? caller(for: place) else { return }
        do {
            try await server.withdraw(eventID: eventID, throughExposure: through, as: caller)
            update(eventID) { $0.pendingWithdrawal = nil }
        } catch .refused(.alreadyRevealed) {
            update(eventID) { $0.pendingWithdrawal = nil }
            notice = "The album had already revealed, so your pictures there were not withdrawn. You can remove them one at a time."
        } catch .refused(let code) where code == .eventGone || code == .removedFromEvent || code == .guestTokenRefused {
            // Nothing of the guest's is left to withdraw.
            update(eventID) { $0.pendingWithdrawal = nil }
        } catch {
            // Unreachable or refused for a moment: told on the next sync.
        }
    }

    func removeMyPicture(_ eventID: String, exposureNumber: Int) async -> Bool {
        guard let place = place(eventID) else { return false }
        return await run {
            try await self.server.removeMyPicture(eventID: eventID, exposureNumber: exposureNumber, as: try self.caller(for: place))
        }
    }

    func report(_ eventID: String, pictureID: String, reason: ReportReason) async -> Bool {
        guard let place = place(eventID) else { return false }
        let done = await run {
            try await self.server.report(eventID: eventID, pictureID: pictureID, reason: reason, as: try self.caller(for: place))
        }
        if done { notice = "Thank you. The Host and Immerse's support have the report." }
        return done
    }

    func album(_ eventID: String) async throws -> Album {
        guard let place = place(eventID) else { throw ServerError.refused(.notAMember) }
        return try await server.album(eventID: eventID, as: try caller(for: place))
    }

    func markRevealSeen(_ eventID: String) {
        update(eventID) { $0.revealSeen = true }
    }

    func markSaved(_ eventID: String, pictureID: String) {
        update(eventID) { $0.savedPictures.insert(pictureID) }
    }

    /// Claim Guest Identity (V2-FR-04): the places of the phone's guest identity move to the signed-in Account, and follow
    /// it to any iPhone it signs in on.
    func claimGuestPlaces() async {
        guard hosting.isSignedIn, let identity = try? identities.read() else { return }
        let done = await run { [self] in
            let (moved, kept) = try await server.claim(identity)
            for eventID in moved { update(eventID) { $0.asGuest = false } }
            if !kept.isEmpty {
                notice = "Your Account already had a place in \(kept.count == 1 ? "one of these Group Films" : "some of these Group Films"), so both places stay as they were, each with its own Roll."
            }
        }
        if done { await refresh() }
    }

    /// Delete Guest Identity (V2-FR-57): every picture of the phone's guest identity goes from every event it joined, its
    /// waiting pictures never upload, and its Instant prints on this phone go too.
    func deleteGuestIdentity() async {
        guard let identity = try? identities.read() else { return }
        let done = await run { try await self.server.deleteGuestIdentity(identity) }
        guard done else { return }
        for place in places where place.asGuest { await forget(place.eventID) }
        try? identities.delete()
        notice = "Your guest identity and its pictures were deleted."
    }

    /// Delete Account removed the person's pictures everywhere (V2-FR-05): what waits on this phone for the Account's
    /// places, and their Instant prints, go too.
    private func accountDeleted() {
        Task {
            for place in places where !place.asGuest { await forget(place.eventID) }
        }
    }

    // MARK: Syncing with the server

    /// Learns what changed while the phone was away, for every place: a moved End Time, the reveal, a removal or a
    /// deleted event (V2-FR-31, V2-FR-53, V2-FR-55), and sends what it owes the server.
    func refresh() async {
        for place in places {
            guard place.asGuest || hosting.isSignedIn else { continue }
            await sync(place.eventID)
        }
        if hosting.isSignedIn { await adoptAccountPlaces() }
        startDevelopment()
        startUploads()
    }

    /// Brings in the events the signed-in Account hosts or joined on another iPhone (V2-FR-04, V2-FR-61).
    private func adoptAccountPlaces() async {
        if let hosted = try? await server.hostedEvents() {
            for summary in hosted where place(summary.eventId) == nil {
                places.append(LocalPlace(eventID: summary.eventId, summary: summary, isHost: true, asGuest: false, place: .none))
            }
        }
        if let joined = try? await server.joinedEvents() {
            for entry in joined {
                if let existing = place(entry.event.eventId), existing.place != .none || existing.asGuest { continue }
                var place = place(entry.event.eventId)
                    ?? LocalPlace(eventID: entry.event.eventId, summary: entry.event, isHost: entry.isHost, asGuest: false, place: entry.status)
                place.place = entry.status
                place.guestName = entry.guestName
                places.removeAll { $0.eventID == entry.event.eventId }
                places.append(place)
            }
        }
        save()
        for place in places where !place.asGuest && place.place != .none && place.rollFilmID == nil {
            await sync(place.eventID)
        }
    }

    func sync(_ eventID: String) async {
        guard let place = place(eventID), let caller = try? caller(for: place) else { return }
        let standing: EventStanding
        do {
            standing = try await server.standing(eventID: eventID, as: caller)
        } catch {
            return
        }
        switch standing.event {
        case .deleted:
            await end(place, message: "\(place.summary.title) was deleted by its Host. Its pictures are gone for everyone.")
            return
        case .gone:
            await end(place, message: "The album of \(place.summary.title) has ended.")
            return
        default:
            break
        }
        if standing.place == .removed {
            await retireLocally(place, throughExposure: .max)
            update(eventID) { $0.place = .removed }
            return
        }
        if place.pendingWithdrawal != nil { await sendPendingWithdrawal(eventID) }
        if place.isHost { await refreshHostView(eventID) }
        guard standing.place == .joined || standing.place == .left else {
            if !place.isHost, standing.place == .none, !place.asGuest {
                places.removeAll { $0.eventID == eventID }
                save()
            }
            return
        }
        guard let view = try? await server.memberView(eventID: eventID, as: caller) else { return }
        update(eventID) {
            $0.summary = view.event
            $0.place = view.status
            $0.guestName = view.guestName
        }
        // A Roll joined on another iPhone, or before this phone kept its Film, gets its local Film to shoot on.
        if self.place(eventID)?.rollFilmID == nil, view.status == .joined, view.event.phase == .open || view.event.phase == .scheduled {
            if let film = try? rolls.loadEventRoll(eventID: eventID, camera: Self.package(for: view.event.camera),
                                                   title: view.event.title, filmStock: Self.filmStock(view.event.filmStock)) {
                update(eventID) { $0.rollFilmID = film.id }
            }
        }
        if let filmID = self.place(eventID)?.rollFilmID, let film = rolls.film(filmID) {
            let used = film.captures.count
            if used > (self.place(eventID)?.exposuresReported ?? 0) {
                if (try? await server.reportExposures(eventID: eventID, used: used, as: caller)) != nil {
                    update(eventID) { $0.exposuresReported = used }
                }
            }
            if view.event.phase == .revealed { retireRevealedInstantPrints(film: film, eventID: eventID) }
        }
    }

    /// At the reveal the shooter's own Instant prints leave the phone, once each has reached the server, and the shooter
    /// sees them in the album like everyone else (V2-FR-32).
    private func retireRevealedInstantPrints(film: Film, eventID: String) {
        guard film.camera.revealRule == .instantPerExposure else { return }
        Task {
            for capture in film.captures where !capture.isDiscarded {
                guard await !queue.contains(eventID: eventID, exposureNumber: capture.sequenceNumber),
                      (try? rolls.repository.mediaAsset(filmID: film.id, sequenceNumber: capture.sequenceNumber, kind: .source)) == nil
                else { continue }
                try? rolls.repository.retireEventCapture(filmID: film.id, sequenceNumber: capture.sequenceNumber)
            }
            rolls.refresh()
        }
    }

    /// Deletes what this phone keeps for an event up to an exposure: its waiting pictures, which never upload, and its
    /// local captures and Instant prints (V2-FR-50, V2-FR-53, V2-FR-55).
    private func retireLocally(_ place: LocalPlace, throughExposure: Int) async {
        _ = try? await queue.removeAll(eventID: place.eventID, throughExposure: throughExposure)
        if let filmID = place.rollFilmID, let film = rolls.film(filmID) {
            for capture in film.captures where capture.sequenceNumber <= throughExposure {
                try? rolls.repository.retireEventCapture(filmID: filmID, sequenceNumber: capture.sequenceNumber)
            }
        }
        rolls.refresh()
        await countWaiting()
    }

    /// The event is over for this phone: deleted by its Host, or its album ended. Everything kept for it goes.
    private func end(_ place: LocalPlace, message: String) async {
        await forget(place.eventID)
        ending = EventEnding(title: place.summary.title, message: message)
    }

    private func forget(_ eventID: String) async {
        guard let place = place(eventID) else { return }
        _ = try? await queue.removeAll(eventID: eventID)
        if let filmID = place.rollFilmID, rolls.film(filmID) != nil {
            try? await rolls.trial.deleteFilm(filmID: filmID, processor: rolls.processor)
        }
        places.removeAll { $0.eventID == eventID }
        hostViews[eventID] = nil
        save()
        rolls.refresh()
        await countWaiting()
    }

    // MARK: Development and the upload queue

    /// Develops every saved picture not yet queued, one at a time, while the app is on the screen (V2-FR-33): a Disposable
    /// or 6×6 picture unseen, an Instant print from the one developed at the camera.
    func startDevelopment() {
        // Not while the camera is open: developing heats an older iPhone and slows its camera (RK-V2-12).
        guard developing == nil, active, !rolls.capture.presented else { return }
        developing = Task { [weak self] in
            await self?.developPending()
            self?.developing = nil
            self?.startUploads()
        }
    }

    func developPending() async {
        for place in places {
            guard let filmID = place.rollFilmID, let film = rolls.film(filmID), place.place != .removed else { continue }
            let instant = film.camera.revealRule == .instantPerExposure
            for capture in film.captures where !capture.isDiscarded {
                guard active, !Task.isCancelled else { return }
                let key = "\(place.eventID)-\(capture.sequenceNumber)"
                guard (developmentFailures[key] ?? 0) < 3,
                      await !queue.contains(eventID: place.eventID, exposureNumber: capture.sequenceNumber),
                      (try? rolls.repository.mediaAsset(filmID: filmID, sequenceNumber: capture.sequenceNumber, kind: .source)) != nil
                else { continue }
                // An Instant print uploads once it has developed at the camera.
                if instant, capture.revealState != .revealed { continue }
                let root = rollsRoot
                let sequence = capture.sequenceNumber
                let result = await Task.detached(priority: .utility) { () -> Result<(Data, Data), Error> in
                    Result {
                        let developed = try EventPictureDevelopment.developed(root: root, filmID: filmID, sequenceNumber: sequence)
                        return (developed, try EventPictureDevelopment.viewingCopy(of: developed))
                    }
                }.value
                switch result {
                case .success(let (developed, view)):
                    try? await queue.enqueue(eventID: place.eventID, exposureNumber: sequence, captureTime: capture.savedAt,
                                             developed: developed, view: view)
                case .failure:
                    developmentFailures[key, default: 0] += 1
                    if developmentFailures[key] == 3 {
                        notice = "This iPhone could not develop a picture of \(place.summary.title). It stays on this iPhone and is not sent undeveloped."
                    }
                }
            }
        }
        await countWaiting()
    }

    /// One pass of the upload queue, retried on its own until the album ends (V2-FR-35).
    func startUploads() {
        guard uploading == nil else { return }
        uploading = Task { [weak self] in
            await self?.uploadPass()
            self?.uploading = nil
        }
    }

    func uploadPass() async {
        let sender = QueueSender(owner: self)
        let results = await queue.run(using: sender)
        for result in results {
            switch result {
            case .stored(let picture):
                sent[picture.eventID, default: 0] += 1
                if let filmID = place(picture.eventID)?.rollFilmID {
                    // Its original goes once the server has it whole (V2-FR-36).
                    try? rolls.repository.removeEventOriginal(filmID: filmID, sequenceNumber: picture.exposureNumber)
                }
            case .refused(let picture, let code):
                await refused(picture, code: code)
            }
        }
        if !results.isEmpty { rolls.refresh() }
        await countWaiting()
    }

    private func refused(_ picture: QueuedPicture, code: RefusalCode) async {
        guard let place = place(picture.eventID) else { return }
        if let filmID = place.rollFilmID {
            try? rolls.repository.retireEventCapture(filmID: filmID, sequenceNumber: picture.exposureNumber)
        }
        switch code {
        case .afterEndTime:
            notice = "A picture taken after shooting ended in \(place.summary.title) was not added to the album."
        case .removedFromEvent, .notAMember, .eventGone:
            await sync(picture.eventID)
        default:
            break
        }
    }

    func countWaiting() async {
        var counts: [String: Int] = [:]
        for picture in await queue.pending() { counts[picture.eventID, default: 0] += 1 }
        waiting = counts
    }

    /// The token or session a queued picture is sent with.
    fileprivate func sendingCaller(_ eventID: String) async throws -> String? {
        guard let place = place(eventID) else { throw ServerError.refused(.eventGone) }
        return try await server.guestToken(eventID: eventID, as: caller(for: place))
    }

    fileprivate var pictureUploader: PictureUploader { uploader }

    // MARK: The app's lifecycle

    /// The app came to the screen: Development resumes, the queue runs, and it runs again whenever the network returns
    /// and every half minute while pictures wait.
    func becameActive() {
        active = true
        Task { await refresh() }
        if pathMonitor == nil {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                guard path.status == .satisfied else { return }
                Task { @MainActor in self?.startUploads() }
            }
            monitor.start(queue: DispatchQueue(label: "GroupFilms.network"))
            pathMonitor = monitor
        }
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self else { return }
                guard self.active else { continue }
                if self.waiting.values.contains(where: { $0 > 0 }) { self.startUploads() }
                self.startDevelopment()
            }
        }
    }

    /// The app left the screen: Development pauses, as v1's does (V2-FR-33), and the queue gets the time iOS allows an
    /// app that leaves the screen to send what waits (V2-FR-35). The rest goes when the app is next opened.
    func enteredBackground() {
        active = false
        developing?.cancel()
        developing = nil
        timer?.cancel()
        let time = BackgroundTime()
        time.identifier = UIApplication.shared.beginBackgroundTask(withName: "Group Film uploads") {
            MainActor.assumeIsolated { time.end() }
        }
        Task {
            await uploadPass()
            time.end()
        }
    }

    // MARK: The alert

    /// Asks once to allow notifications, so the reveal's "Your Film is ready" can arrive (V2-FR-70), and registers this
    /// installation's token for the Account or the guest identity. Declining blocks nothing.
    private func askForTheAlert(as caller: EventCaller) async {
        guard (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) == true else { return }
        guard let token = try? await PushRegistration.shared.register() else { return }
        let installation = HostingSession.installationID()
        switch caller {
        case .account:
            try? await AccountServer(functions: hosting.functions)
                .registerPushToken(token, installationID: installation, environment: PushRegistration.environment)
        case .guest(let identity):
            try? await server.registerGuestPushToken(token, installationID: installation,
                                                     environment: PushRegistration.environment, identity: identity)
        }
    }

    /// A tap on "Your Film is ready": the event opens once the server has said the person may still see it (V2-FR-70).
    func openFromAlert(eventID: String) async {
        guard place(eventID) != nil else { return }
        await sync(eventID)
        if place(eventID).map({ $0.place != .removed }) == true { openEvent = eventID }
    }

    // MARK: Helpers

    @discardableResult
    func run(_ work: @escaping @MainActor () async throws -> Void) async -> Bool {
        busy = true
        defer { busy = false }
        do {
            try await work()
            return true
        } catch is CancellationError {
            return false
        } catch {
            notice = GroupFilmsCopy.words(for: error)
            return false
        }
    }
}

/// The time iOS gives an app that leaves the screen, ended once, by the work finishing or by iOS.
@MainActor
private final class BackgroundTime {
    var identifier = UIBackgroundTaskIdentifier.invalid

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}

/// Sends a queued picture through the upload path, with the guest's token for its event, or the Account's session.
private struct QueueSender: QueuedPictureSending {
    let owner: GroupFilms

    func send(_ picture: QueuedPicture, file: URL, view: URL?) async throws -> SendOutcome {
        let token = try await owner.sendingCaller(picture.eventID)
        let uploader = await owner.pictureUploader
        do {
            return try await uploader.send(PictureToSend(eventID: picture.eventID, exposureNumber: picture.exposureNumber,
                                                         captureTime: picture.captureTime, contentType: picture.contentType,
                                                         fileURL: file, viewFileURL: view, guestToken: token))
        } catch .server(.refused(.guestTokenRefused)) where token != nil {
            // The token ran out or the place changed: one fresh token, then the server's word stands.
            await owner.server.sessions.forget(eventID: picture.eventID)
            let fresh = try await owner.sendingCaller(picture.eventID)
            return try await uploader.send(PictureToSend(eventID: picture.eventID, exposureNumber: picture.exposureNumber,
                                                         captureTime: picture.captureTime, contentType: picture.contentType,
                                                         fileURL: file, viewFileURL: view, guestToken: fresh))
        }
    }
}

/// Opens the event a tap on "Your Film is ready" names, once the server has said the person may still see it (V2-FR-70).
@MainActor
final class GroupFilmAlertRouter {
    static let shared = GroupFilmAlertRouter()
    weak var groupFilms: GroupFilms?

    func open(eventID: String) {
        guard let groupFilms else { return }
        Task { await groupFilms.openFromAlert(eventID: eventID) }
    }
}
