import Foundation

/// The three photo Cameras a Group Film can use (v2 PRD V2-FR-10), as the server names them.
public enum EventCamera: String, Codable, CaseIterable, Sendable {
    case disposable
    case sixBySix = "6x6"
    case instant

    /// Each Camera's normal roll (V2-FR-25).
    public var exposuresPerRoll: Int {
        switch self {
        case .disposable: 27
        case .sixBySix: 12
        case .instant: 10
        }
    }
}

/// The Film Stock a 6×6 Group Film is loaded with, for everyone (V2-FR-10, ADR 0014).
public enum EventFilmStock: String, Codable, Sendable {
    case color
    case blackAndWhite
}

/// An event's state now (v2 PRD section 6.1), as the server reads it from the event's times.
public enum EventPhase: String, Codable, Sendable {
    case scheduled, open, ended, revealed, gone, deleted
}

/// Which of the album's end notices shows (V2-FR-48).
public enum AlbumNotice: String, Codable, Sendable {
    case none, month, week
}

/// What every member may know of an event (V2-FR-21, V2-FR-11): never a picture.
public struct EventSummary: Codable, Equatable, Sendable {
    public let eventId: String
    public let title: String
    public let hostName: String?
    public let hostLeft: Bool
    public let camera: EventCamera
    public let filmStock: EventFilmStock?
    public let exposuresPerRoll: Int
    public let phase: EventPhase
    private let startsAtMs: Double?
    private let opensAtMs: Double
    private let endsAtMs: Double
    public let revealDelayMs: Double
    private let revealsAtMs: Double
    private let albumEndsAtMs: Double
    public let albumNotice: AlbumNotice
    public let joiningPaused: Bool
    /// Whether the album is on the web now (V2-FR-47). Absent in what a phone kept before Stage 3, which reads as off.
    private let webAlbumOn: Bool?

    /// Whether the Host shares the revealed album on the web, where anyone with the link can see and save it.
    public var isOnTheWeb: Bool { webAlbumOn ?? false }

    enum CodingKeys: String, CodingKey {
        case eventId, title, hostName, hostLeft, camera, filmStock, exposuresPerRoll, phase, revealDelayMs, albumNotice
        case joiningPaused, webAlbumOn
        case startsAtMs = "startsAt", opensAtMs = "opensAt", endsAtMs = "endsAt", revealsAtMs = "revealsAt"
        case albumEndsAtMs = "albumEndsAt"
    }

    public var startsAt: Date? { startsAtMs.map(Date.init(milliseconds:)) }
    public var opensAt: Date { Date(milliseconds: opensAtMs) }
    public var endsAt: Date { Date(milliseconds: endsAtMs) }
    public var revealsAt: Date { Date(milliseconds: revealsAtMs) }
    public var albumEndsAt: Date { Date(milliseconds: albumEndsAtMs) }
}

extension Date {
    init(milliseconds: Double) { self.init(timeIntervalSince1970: milliseconds / 1000) }
    var milliseconds: Double { (timeIntervalSince1970 * 1000).rounded() }
}

/// A person's place in an event: none, in it, left on their own, or removed by the Host.
public enum EventPlace: String, Codable, Sendable {
    case none, joined, left, removed
}

/// What a Join Code's link shows (V2-FR-18, V2-FR-21).
public struct JoinPreview: Decodable, Equatable, Sendable {
    public enum Status: String, Decodable, Sendable {
        /// Anyone can join now.
        case open
        /// The person is already in the event.
        case member
        /// The event opens at its Start Time.
        case notYetOpen
        /// Joining is paused for now.
        case paused
        /// Every Roll has been taken.
        case full
        /// Shooting has ended.
        case ended
        /// The Host removed this person from the event.
        case removed
        /// The code was replaced; this link no longer works.
        case replaced
        /// The event was deleted, or its album has ended.
        case unavailable
        /// No event has this code.
        case unknown
    }

    public let status: Status
    public let event: EventSummary?
    public let place: EventPlace?
    public let isHost: Bool?
}

/// The reply to joining: what the phone needs to shoot offline (V2-FR-31), and a guest's token for the event.
public struct JoinedPlace: Decodable, Equatable, Sendable {
    public let event: EventSummary
    public let membershipId: String
    public let guestName: String
    public let exposuresUsed: Int
    public let withdrawnThrough: Int
    public let guestToken: String?
    private let guestTokenExpiresAt: Double?

    public var tokenExpiresAt: Date? { guestTokenExpiresAt.map(Date.init(milliseconds:)) }
}

/// Where a person stands in an event, for the phone to act on what happened while it was offline (V2-FR-53, V2-FR-55).
public struct EventStanding: Decodable, Equatable, Sendable {
    /// The event's phase, or "deleted" or "gone".
    public let event: EventPhase
    public let place: EventPlace
    private let endsAt: Double?
    private let revealsAt: Double?
    public let exposuresUsed: Int?
    public let withdrawnThrough: Int?

    public var endsAtDate: Date? { endsAt.map(Date.init(milliseconds:)) }
    public var revealsAtDate: Date? { revealsAt.map(Date.init(milliseconds:)) }
}

/// The event as a member sees it (V2-FR-35, V2-FR-38, V2-FR-48).
public struct MemberView: Decodable, Equatable, Sendable {
    public let event: EventSummary
    public let isHost: Bool
    public let membershipId: String
    public let guestName: String
    public let status: EventPlace
    public let exposuresUsed: Int
    public let withdrawnThrough: Int
    /// The member's own exposures the server holds whole.
    public let storedExposures: [Int]
    public let removedExposures: [Int]
}

/// One of the events a signed-in person joined (V2-FR-04).
public struct JoinedEvent: Decodable, Equatable, Sendable {
    public let event: EventSummary
    public let membershipId: String
    public let guestName: String
    public let exposuresUsed: Int
    public let status: EventPlace
    public let isHost: Bool
}

/// The Host's view (V2-FR-29): counts, never pictures, before the reveal.
public struct HostEventView: Decodable, Equatable, Sendable {
    public struct Rolls: Decodable, Equatable, Sendable {
        public let setAside: Int
        public let taken: Int
        public let free: Int
        public let limit: Int
    }

    public struct Guest: Decodable, Equatable, Sendable, Identifiable {
        public let membershipId: String
        public let name: String
        public let exposuresUsed: Int
        public let status: EventPlace
        public let isHost: Bool
        public var id: String { membershipId }
    }

    public struct Report: Decodable, Equatable, Sendable, Identifiable {
        public let reportId: String
        public let pictureId: String
        public let reason: ReportReason
        private let at: Double
        public var id: String { reportId }
        public var reportedAt: Date { Date(milliseconds: at) }
    }

    public let summary: EventSummary
    public let joinCode: String?
    public let joinCodeGeneration: Int?
    public let rolls: Rolls?
    public let picturesArrived: Int
    public let guests: [Guest]
    public let reports: [Report]
    /// The Host's switch for the view-only web album (V2-FR-47), which shows the album only once the event has revealed.
    public let webAlbum: Bool

    enum CodingKeys: String, CodingKey { case joinCode, joinCodeGeneration, rolls, picturesArrived, guests, reports, webAlbum }

    public init(from decoder: Decoder) throws {
        summary = try EventSummary(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        joinCode = try container.decodeIfPresent(String.self, forKey: .joinCode)
        joinCodeGeneration = try container.decodeIfPresent(Int.self, forKey: .joinCodeGeneration)
        rolls = try container.decodeIfPresent(Rolls.self, forKey: .rolls)
        picturesArrived = try container.decode(Int.self, forKey: .picturesArrived)
        guests = try container.decode([Guest].self, forKey: .guests)
        reports = try container.decode([Report].self, forKey: .reports)
        webAlbum = try container.decodeIfPresent(Bool.self, forKey: .webAlbum) ?? false
    }
}

/// Why a member reports a picture (V2-FR-54).
public enum ReportReason: String, Codable, CaseIterable, Sendable {
    case sexual, violence, harassment, privacy, other
}

/// One place in the revealed album (V2-FR-45): a picture with its read addresses, or a numbered gap.
public enum AlbumEntry: Decodable, Equatable, Sendable, Identifiable {
    case picture(AlbumPicture)
    case gap(number: Int)

    public var id: Int { number }
    public var number: Int {
        switch self {
        case .picture(let picture): picture.number
        case .gap(let number): number
        }
    }

    private enum Keys: String, CodingKey { case number, removed }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        if try container.decode(Bool.self, forKey: .removed) {
            self = .gap(number: try container.decode(Int.self, forKey: .number))
        } else {
            self = .picture(try AlbumPicture(from: decoder))
        }
    }
}

/// A picture in the revealed album, with one-minute read addresses for its viewing copy and the full picture.
public struct AlbumPicture: Decodable, Equatable, Sendable, Identifiable {
    public var id: String { pictureId }
    public let number: Int
    public let pictureId: String
    public let exposureNumber: Int
    public let shooterName: String
    private let captureTime: Double
    public let contentType: String
    public let size: Int
    public let sha256: String
    public let url: URL
    public let viewUrl: URL
    private let expiresAt: Double
    /// The caller took it: they may remove it, and do not report it.
    public let mine: Bool

    public var capturedAt: Date { Date(milliseconds: captureTime) }
    public var addressesExpireAt: Date { Date(milliseconds: expiresAt) }
}

/// The revealed album.
public struct Album: Decodable, Equatable, Sendable {
    public let camera: EventCamera
    public let isHost: Bool
    public let entries: [AlbumEntry]
}

/// The settings of Load Film (V2-FR-12, V2-FR-13).
public struct EventSetup: Equatable, Sendable {
    public var title: String
    public var camera: EventCamera
    public var filmStock: EventFilmStock?
    public var rolls: Int
    public var startsAt: Date?
    public var endsAt: Date
    public var revealDelay: TimeInterval
    public var treatmentVersion: String

    public init(title: String, camera: EventCamera, filmStock: EventFilmStock?, rolls: Int, startsAt: Date?, endsAt: Date,
                revealDelay: TimeInterval, treatmentVersion: String) {
        self.title = title
        self.camera = camera
        self.filmStock = filmStock
        self.rolls = rolls
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.revealDelay = revealDelay
        self.treatmentVersion = treatmentVersion
    }
}

/// An event made by Load Film: its id and its Join Code.
public struct LoadedEvent: Decodable, Equatable, Sendable {
    public let eventId: String
    public let joinCode: String
}
