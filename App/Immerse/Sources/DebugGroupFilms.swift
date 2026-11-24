#if DEBUG
import Foundation
import ImmerseServer
import Synchronization
import UIKit

/// Debug builds only: Group Films against an in-memory stand-in for the server's event functions, for screen tests, with
/// no Convex deployment. `-ImmerseDebugGroupFilm open` seeds an open Disposable event whose link screen tests open with
/// `-ImmerseDebugJoinLink https://join.immerse.test/j/<code>` (the mini-app's with `_XCAppClipURL`); `paused`, `full`,
/// `scheduled` and `ended` seed it in that state; `revealed` also gives this iPhone a place in a revealed event with
/// pictures and a numbered gap; `waiting` gives it a place in the open event with a picture that cannot be sent yet. It follows the server's rules only as far as the screens need; the server's
/// own tests hold the rules (Backend/tests). `Scripts/verify-release-excludes-testing-unlock.sh` holds it out of Release.
@MainActor
enum DebugGroupFilms {
    static let joinHost = "join.immerse.test"
    /// The open event's Join Code.
    static let openCode = "OpenEventCodeForTests0"

    static func make(hosting: HostingSession) -> GroupFilms? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ImmerseDebugGroupFilm"), index + 1 < arguments.count,
              let server = hosting.functions as? DebugHostingServer,
              let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                         appropriateFor: nil, create: true) else { return nil }
        let scenario = arguments[index + 1]
        // A folder of the stand-in's own, never the one real Group Films are kept in.
        let base = support.appending(path: "DebugGroupFilms", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: base)
        let identities = MemoryGuestIdentityStore()
        let backend = DebugEventBackend()
        server.events = backend
        backend.seedOpenEvent(code: openCode, state: scenario)
        guard let groupFilms = try? GroupFilmsSetup.make(hosting: hosting, folder: GroupFilmsFolder(url: base, isShared: false),
                                                        identities: identities, joinHost: joinHost,
                                                        supportAddress: "support@immerse.test") else { return nil }
        if scenario == "revealed", let identity = try? identities.identity() {
            let summary = backend.seedRevealedEvent(guest: identity)
            groupFilms.adoptForTesting(LocalPlace(eventID: summary.eventId, summary: summary, isHost: false, asGuest: true,
                                                  place: .joined, guestName: "Jo", revealSeen: true))
        }
        if scenario == "waiting", let identity = try? identities.identity() {
            // A place in the open event with one developed picture in the queue and no way to send it yet.
            let summary = backend.seedMember(of: "event-open", guest: identity, name: "Jo")
            backend.uploadsUnreachable = true
            groupFilms.adoptForTesting(LocalPlace(eventID: summary.eventId, summary: summary, isHost: false, asGuest: true,
                                                  guestPublicID: identity.publicId, place: .joined, guestName: "Jo"))
            let queue = groupFilms.queue
            Task { try? await queue.enqueue(eventID: summary.eventId, exposureNumber: 1, captureTime: .now, developed: Data([0xFF, 0xD8]), view: nil) }
        }
        return groupFilms
    }

    static func launchLink(arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: "-ImmerseDebugJoinLink"), index + 1 < arguments.count else { return nil }
        return URL(string: arguments[index + 1])
    }
}

/// The event functions held in memory (Debug only).
final class DebugEventBackend: @unchecked Sendable {
    private struct Event {
        var id: String
        var title: String
        var hostName: String?
        var camera: String
        var filmStock: String?
        var exposures: Int
        var rollsSetAside: Int
        var rollsTaken = 0
        var startsAt: Double?
        var createdAt: Double
        var endsAt: Double
        var revealDelayMs: Double
        var revealsAt: Double
        var paused = false
        var code: String
        var generation = 1
        var deleted = false
        var revealed = false
        var webAlbum = false
        var album: [JSONValue] = []
    }

    private struct Member {
        var eventID: String
        var id: String
        var publicId: String?
        var account: Bool
        var name: String
        var used = 0
        var status = "joined"
        var stored: [Int] = []
    }

    private let state = Mutex<(events: [String: Event], members: [Member], balance: Int, retired: Set<String>)>(([:], [], 3, []))
    private let unreachableUploads = Mutex(false)

    /// The balance, for the Roll functions' stand-in (`DebugRollBackend`).
    var balance: Int { state.withLock { $0.balance } }

    /// Adds bought Rolls to the balance.
    func credit(_ rolls: Int) { state.withLock { $0.balance += rolls } }

    /// While set, the upload path cannot be reached, so what waits keeps waiting.
    var uploadsUnreachable: Bool {
        get { unreachableUploads.withLock { $0 } }
        set { unreachableUploads.withLock { $0 = newValue } }
    }

    private static var now: Double { (Date.now.timeIntervalSince1970 * 1000).rounded() }

    /// The open event, or the same event paused, with every Roll taken, not yet open, or with shooting ended.
    func seedOpenEvent(code: String, state scenario: String = "open") {
        let now = Self.now
        var event = Event(id: "event-open", title: "Ana & Leo", hostName: "Maya", camera: "disposable", exposures: 27,
                          rollsSetAside: 5, createdAt: now, endsAt: now + 6 * 3_600_000, revealDelayMs: 3_600_000,
                          revealsAt: now + 7 * 3_600_000, code: code)
        switch scenario {
        case "paused": event.paused = true
        case "full": event.rollsTaken = event.rollsSetAside
        case "scheduled": event.startsAt = now + 2 * 86_400_000; event.endsAt = now + 3 * 86_400_000; event.revealsAt = event.endsAt
        case "ended": event.endsAt = now - 60_000; event.revealsAt = now + 3_600_000
        default: break
        }
        state.withLock { $0.events[event.id] = event }
    }

    /// A guest already in an event, as joining would leave it.
    func seedMember(of eventID: String, guest: GuestIdentity, name: String) -> EventSummary {
        state.withLock { state in
            state.events[eventID]?.rollsTaken += 1
            state.members.append(Member(eventID: eventID, id: "member-\(state.members.count + 1)", publicId: guest.publicId,
                                        account: false, name: name, used: 1))
            return try! summary(state.events[eventID]!).decoded()
        }
    }

    /// A revealed event with pictures this iPhone's guest and others took, and a removed one's gap.
    func seedRevealedEvent(guest: GuestIdentity) -> EventSummary {
        let now = Self.now
        var event = Event(id: "event-revealed", title: "Sam's Birthday", hostName: "Sam", camera: "disposable", exposures: 27,
                          rollsSetAside: 3, rollsTaken: 3, createdAt: now - 3 * 86_400_000, endsAt: now - 86_400_000,
                          revealDelayMs: 0, revealsAt: now - 86_400_000, code: "RevealedEventCodeTests", revealed: true)
        let names = ["Sam", "Jo", "Lee", "Jo"]
        var entries: [JSONValue] = []
        for (index, name) in names.enumerated() {
            let number = index + 1
            if number == 3 {
                entries.append(["number": 3, "removed": true])
                continue
            }
            let url = Self.picture(number: number)
            entries.append([
                "number": .number(Double(number)), "removed": false, "pictureId": .string("picture-\(number)"),
                "exposureNumber": .number(Double(number)), "shooterName": .string(name),
                "captureTime": .number(event.endsAt - Double(10 - number) * 60_000), "contentType": "image/jpeg",
                "size": 1, "sha256": "x", "url": .string(url.absoluteString), "viewUrl": .string(url.absoluteString),
                "expiresAt": .number(now + 3_600_000), "mine": .bool(name == "Jo"),
            ])
        }
        event.album = entries
        state.withLock {
            $0.events[event.id] = event
            $0.members.append(Member(eventID: event.id, id: "member-jo", publicId: guest.publicId, account: false, name: "Jo",
                                     used: 2, stored: [2, 4]))
        }
        return try! summary(event).decoded()
    }

    /// A picture file for the album, a colour of its own per number.
    private static func picture(number: Int) -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "debug-album-\(number).jpg")
        let hues: [CGFloat] = [0.08, 0.55, 0.3, 0.75]
        let image = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 180)).image { context in
            UIColor(hue: hues[(number - 1) % hues.count], saturation: 0.5, brightness: 0.8, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 240, height: 180))
        }
        try? image.jpegData(compressionQuality: 0.8)?.write(to: url)
        return url
    }

    private func summary(_ event: Event) -> JSONValue {
        let now = Self.now
        let phase = event.deleted ? "deleted" : event.revealed || now >= event.revealsAt ? "revealed"
            : now >= event.endsAt ? "ended" : (event.startsAt.map { now < $0 } ?? false) ? "scheduled" : "open"
        return [
            "eventId": .string(event.id), "title": .string(event.title), "hostName": event.hostName.map(JSONValue.string) ?? .null,
            "hostLeft": false, "camera": .string(event.camera), "filmStock": event.filmStock.map(JSONValue.string) ?? .null,
            "exposuresPerRoll": .number(Double(event.exposures)), "phase": .string(phase),
            "startsAt": event.startsAt.map(JSONValue.number) ?? .null, "opensAt": .number(event.startsAt ?? event.createdAt),
            "endsAt": .number(event.endsAt), "revealDelayMs": .number(event.revealDelayMs), "revealsAt": .number(event.revealsAt),
            "albumEndsAt": .number(event.revealsAt + 365 * 86_400_000), "albumNotice": "none", "joiningPaused": .bool(event.paused),
            "webAlbumOn": .bool(phase == "revealed" && event.webAlbum),
        ]
    }

    private func merge(_ base: JSONValue, _ extra: [String: JSONValue]) -> JSONValue {
        guard case .object(var object) = base else { return base }
        for (key, value) in extra { object[key] = value }
        return .object(object)
    }

    /// Answers an event function, or nil when the path is not one.
    func call(_ path: String, _ args: [String: JSONValue], signedIn: Bool, accountName: String?) throws(ServerError) -> JSONValue? {
        let guestID = args["guest"]?["publicId"]?.string
        return try state.withLock { (state) throws(ServerError) -> JSONValue? in
            func member(_ eventID: String) -> Int? {
                if let guestID { return state.members.firstIndex { $0.eventID == eventID && $0.publicId == guestID } }
                if args["guestToken"] != nil {
                    let token = args["guestToken"]?.string ?? ""
                    return state.members.firstIndex { $0.eventID == eventID && "token-\($0.publicId ?? "")" == token }
                }
                return state.members.firstIndex { $0.eventID == eventID && $0.account }
            }
            switch path {
            case "rolls:balance":
                return ["rolls": .number(Double(state.balance))]
            case "hosting:create":
                guard signedIn else { throw .refused(.unauthenticated) }
                let rolls = Int(args["rolls"]?.number ?? 1)
                guard rolls <= state.balance else { throw .refused(.balanceTooLow) }
                state.balance -= rolls
                let id = "event-\(state.events.count + 1)"
                let camera = args["camera"]?.string ?? "disposable"
                let endsAt = args["endsAt"]?.number ?? Self.now
                let delay = args["revealDelayMs"]?.number ?? 0
                let code = "HostedEventCode\(state.events.count + 1)".padding(toLength: 22, withPad: "x", startingAt: 0)
                state.events[id] = Event(id: id, title: args["title"]?.string ?? "", hostName: accountName, camera: camera,
                                         filmStock: args["filmStock"]?.string,
                                         exposures: EventCamera(rawValue: camera)?.exposuresPerRoll ?? 27, rollsSetAside: rolls,
                                         startsAt: args["startsAt"]?.number, createdAt: Self.now, endsAt: endsAt,
                                         revealDelayMs: delay, revealsAt: endsAt + delay, code: code)
                return ["eventId": .string(id), "joinCode": .string(code)]
            case "hosting:view":
                guard let event = state.events[args["eventId"]?.string ?? ""] else { throw .refused(.notTheHost) }
                let guests: [JSONValue] = state.members.filter { $0.eventID == event.id }.map {
                    ["membershipId": .string($0.id), "name": .string($0.name), "exposuresUsed": .number(Double($0.used)),
                     "status": .string($0.status), "isHost": .bool($0.account)]
                }
                return merge(summary(event), [
                    "joinCode": .string(event.code), "joinCodeGeneration": .number(Double(event.generation)),
                    "rolls": ["setAside": .number(Double(event.rollsSetAside)), "taken": .number(Double(event.rollsTaken)),
                              "free": .number(Double(event.rollsSetAside - event.rollsTaken)), "limit": 200],
                    "picturesArrived": .number(Double(state.members.filter { $0.eventID == event.id }.reduce(0) { $0 + $1.stored.count })),
                    "guests": .array(guests), "reports": [], "webAlbum": .bool(event.webAlbum),
                ])
            case "hosting:hosted":
                return .array(state.events.values.filter { $0.hostName == accountName && signedIn }.map(summary))
            case "hosting:setJoiningPaused":
                state.events[args["eventId"]?.string ?? ""]?.paused = args["paused"]?.bool ?? false
                return [:]
            case "hosting:replaceJoinCode":
                guard var event = state.events[args["eventId"]?.string ?? ""] else { throw .refused(.notTheHost) }
                state.retired.insert(event.code)
                event.generation += 1
                event.code = "ReplacedCodeNumber\(event.generation)".padding(toLength: 22, withPad: "x", startingAt: 0)
                state.events[event.id] = event
                return ["joinCode": .string(event.code), "generation": .number(Double(event.generation))]
            case "hosting:addRolls":
                let rolls = Int(args["rolls"]?.number ?? 0)
                guard rolls <= state.balance else { throw .refused(.balanceTooLow) }
                state.balance -= rolls
                state.events[args["eventId"]?.string ?? ""]?.rollsSetAside += rolls
                return [:]
            case "hosting:endEarly":
                let now = Self.now
                state.events[args["eventId"]?.string ?? ""]?.endsAt = now
                state.events[args["eventId"]?.string ?? ""]?.revealsAt = now
                state.events[args["eventId"]?.string ?? ""]?.revealed = true
                return [:]
            case "hosting:setWebAlbum":
                guard let event = state.events[args["eventId"]?.string ?? ""] else { throw .refused(.notTheHost) }
                let on = args["on"]?.bool ?? false
                if on, !(event.revealed || Self.now >= event.revealsAt) { throw .refused(.notRevealed) }
                state.events[event.id]?.webAlbum = on
                return ["on": .bool(on)]
            case "hosting:rename":
                state.events[args["eventId"]?.string ?? ""]?.title = args["title"]?.string ?? ""
                return [:]
            case "hosting:updateTimes":
                if let endsAt = args["endsAt"]?.number { state.events[args["eventId"]?.string ?? ""]?.endsAt = endsAt }
                return [:]
            case "hosting:deleteEvent":
                state.events[args["eventId"]?.string ?? ""]?.deleted = true
                return [:]
            case "hosting:removeGuest":
                if let index = state.members.firstIndex(where: { $0.id == args["membershipId"]?.string }) {
                    state.members[index].status = "removed"
                }
                return [:]
            case "hosting:removePictureAsHost", "joining:removeMyPicture", "reports:report", "joining:reportExposures",
                 "pushTokens:registerGuest", "pushTokens:register", "joining:setGuestName":
                return [:]
            case "joining:preview":
                let code = args["code"]?.string ?? ""
                if state.retired.contains(code) { return ["status": "replaced"] }
                guard let event = state.events.values.first(where: { $0.code == code }) else { return ["status": "unknown"] }
                if event.deleted { return ["status": "unavailable"] }
                let place = member(event.id).map { state.members[$0].status } ?? "none"
                let phase = summary(event)["phase"]?.string ?? "open"
                let status = place == "removed" ? "removed" : place == "joined" ? "member"
                    : phase == "scheduled" ? "notYetOpen" : phase != "open" ? "ended" : event.paused ? "paused"
                    : event.rollsTaken >= event.rollsSetAside ? "full" : "open"
                return ["status": .string(status), "event": summary(event), "place": .string(place), "isHost": false]
            case "joining:join":
                let code = args["code"]?.string ?? ""
                guard let event = state.events.values.first(where: { $0.code == code }) else { throw .refused(.unknownCode) }
                if event.paused { throw .refused(.joiningPaused) }
                var index = member(event.id)
                if index == nil {
                    guard event.rollsTaken < event.rollsSetAside else { throw .refused(.rollsTaken) }
                    state.events[event.id]?.rollsTaken += 1
                    state.members.append(Member(eventID: event.id, id: "member-\(state.members.count + 1)", publicId: guestID,
                                                account: guestID == nil, name: args["guestName"]?.string ?? "Guest"))
                    index = state.members.count - 1
                }
                state.members[index!].status = "joined"
                let joined = state.members[index!]
                return ["event": summary(event), "membershipId": .string(joined.id), "guestName": .string(joined.name),
                        "exposuresUsed": .number(Double(joined.used)), "withdrawnThrough": 0,
                        "guestToken": guestID.map { .string("token-\($0)") } ?? .null,
                        "guestTokenExpiresAt": .number(Self.now + 3_600_000)]
            case "guests:startSession":
                return ["token": .string("token-\(args["publicId"]?.string ?? "")"), "expiresAt": .number(Self.now + 3_600_000)]
            case "joining:standing":
                guard let event = state.events[args["eventId"]?.string ?? ""] else { return ["event": "deleted", "place": "none"] }
                if event.deleted { return ["event": "deleted", "place": "none"] }
                let place = member(event.id).map { state.members[$0].status } ?? "none"
                return ["event": summary(event)["phase"] ?? "open", "place": .string(place), "endsAt": .number(event.endsAt),
                        "revealsAt": .number(event.revealsAt), "exposuresUsed": 0, "withdrawnThrough": 0]
            case "joining:memberView":
                guard let event = state.events[args["eventId"]?.string ?? ""], let index = member(event.id) else {
                    throw .refused(.notAMember)
                }
                let place = state.members[index]
                return ["event": summary(event), "isHost": false, "membershipId": .string(place.id), "guestName": .string(place.name),
                        "status": .string(place.status), "exposuresUsed": .number(Double(place.used)), "withdrawnThrough": 0,
                        "storedExposures": .array(place.stored.map { .number(Double($0)) }), "removedExposures": []]
            case "joining:mine":
                return []
            case "joining:leave":
                if let index = member(args["eventId"]?.string ?? "") { state.members[index].status = "left" }
                return [:]
            case "joining:withdraw":
                return ["withdrawnThrough": args["throughExposure"] ?? 0]
            case "pictures:requestUpload":
                if unreachableUploads.withLock({ $0 }) { throw .unreachable }
                if let index = member(args["eventId"]?.string ?? "") {
                    state.members[index].stored.append(Int(args["exposureNumber"]?.number ?? 0))
                }
                return ["status": "stored"]
            case "pictures:confirmUpload":
                return ["status": "stored"]
            case "reads:album":
                guard let event = state.events[args["eventId"]?.string ?? ""] else { throw .refused(.eventGone) }
                guard event.revealed else { throw .refused(.sealed) }
                return ["camera": .string(event.camera), "isHost": false, "entries": .array(event.album)]
            case "identities:claim":
                return ["moved": [], "kept": []]
            case "identities:deleteGuestIdentity":
                state.members.removeAll { $0.publicId == guestID }
                return ["deleted": true]
            default:
                return nil
            }
        }
    }
}
#endif
