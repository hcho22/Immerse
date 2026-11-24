import Foundation

/// Who is acting in an event: the signed-in Account, or the phone's guest identity (v2 PRD section 9.2).
public enum EventCaller: Equatable, Sendable {
    case account
    case guest(GuestIdentity)
}

/// The guest tokens this phone holds, one per event, each good for an hour (section 9.2). A token that ran out or was
/// refused is replaced with a new one from the guest identity's secret.
public actor GuestSessions {
    private let functions: any ServerFunctions
    private var tokens: [String: (token: String, expiresAt: Date)] = [:]

    public init(functions: any ServerFunctions) {
        self.functions = functions
    }

    /// A current token for the event, from the cache or a new session.
    public func token(eventID: String, identity: GuestIdentity) async throws(ServerError) -> String {
        if let held = tokens[eventID], held.expiresAt.timeIntervalSinceNow > 60 { return held.token }
        let reply = try await functions.call(.mutation, "guests:startSession", [
            "publicId": .string(identity.publicId), "secret": .string(identity.secret), "eventId": .string(eventID),
        ])
        guard let token = reply["token"]?.string, let expires = reply["expiresAt"]?.number else {
            throw .failed("The guest token could not be read")
        }
        tokens[eventID] = (token, Date(milliseconds: expires))
        return token
    }

    func keep(_ token: String, expiresAt: Date, eventID: String) {
        tokens[eventID] = (token, expiresAt)
    }

    public func forget(eventID: String) {
        tokens[eventID] = nil
    }
}

/// Group Films on the server (v2 PRD sections 5.2 to 5.9): the Host's functions, joining, the member's view and actions,
/// the album, reports, claiming and deleting the guest identity. Every call is checked again on the server; the app only
/// shows what the server allows.
public struct EventServer: Sendable {
    private let functions: any ServerFunctions
    public let sessions: GuestSessions

    public init(functions: any ServerFunctions, sessions: GuestSessions? = nil) {
        self.functions = functions
        self.sessions = sessions ?? GuestSessions(functions: functions)
    }

    // MARK: The Host

    /// Load Film (V2-FR-13). `requestID` makes a repeated request make one event.
    public func loadFilm(_ setup: EventSetup, requestID: String) async throws(ServerError) -> LoadedEvent {
        var args: [String: JSONValue] = [
            "requestId": .string(requestID),
            "title": .string(setup.title),
            "camera": .string(setup.camera.rawValue),
            "rolls": .number(Double(setup.rolls)),
            "endsAt": .number(setup.endsAt.milliseconds),
            "revealDelayMs": .number((setup.revealDelay * 1000).rounded()),
            "treatmentVersion": .string(setup.treatmentVersion),
        ]
        if let filmStock = setup.filmStock { args["filmStock"] = .string(filmStock.rawValue) }
        if let startsAt = setup.startsAt { args["startsAt"] = .number(startsAt.milliseconds) }
        return try await functions.call(.mutation, "hosting:create", args).decoded()
    }

    public func hostView(eventID: String) async throws(ServerError) -> HostEventView {
        try await functions.call(.query, "hosting:view", ["eventId": .string(eventID)]).decoded()
    }

    public func hostedEvents() async throws(ServerError) -> [EventSummary] {
        try await functions.call(.query, "hosting:hosted", [:]).decoded()
    }

    /// How the Start Time moves: to a later time, or cleared so the event opens now.
    public enum StartChange: Equatable, Sendable {
        case at(Date)
        case now
    }

    public func updateTimes(eventID: String, start: StartChange? = nil, endsAt: Date? = nil,
                            revealDelay: TimeInterval? = nil) async throws(ServerError) {
        var args: [String: JSONValue] = ["eventId": .string(eventID)]
        switch start {
        case .at(let date): args["startsAt"] = .number(date.milliseconds)
        case .now: args["startsAt"] = .null
        case nil: break
        }
        if let endsAt { args["endsAt"] = .number(endsAt.milliseconds) }
        if let revealDelay { args["revealDelayMs"] = .number((revealDelay * 1000).rounded()) }
        _ = try await functions.call(.mutation, "hosting:updateTimes", args)
    }

    public func setJoiningPaused(eventID: String, paused: Bool) async throws(ServerError) {
        _ = try await functions.call(.mutation, "hosting:setJoiningPaused", ["eventId": .string(eventID), "paused": .bool(paused)])
    }

    /// Replaces the code the Host saw (its `generation`), returning the new code and generation.
    public func replaceJoinCode(eventID: String, generation: Int) async throws(ServerError) -> (code: String, generation: Int) {
        let reply = try await functions.call(.mutation, "hosting:replaceJoinCode", [
            "eventId": .string(eventID), "generation": .number(Double(generation)),
        ])
        guard let code = reply["joinCode"]?.string, let next = reply["generation"]?.number else {
            throw .failed("The new code could not be read")
        }
        return (code, Int(next))
    }

    public func addRolls(eventID: String, rolls: Int, requestID: String) async throws(ServerError) {
        _ = try await functions.call(.mutation, "hosting:addRolls", [
            "eventId": .string(eventID), "rolls": .number(Double(rolls)), "requestId": .string(requestID),
        ])
    }

    public func endEarly(eventID: String) async throws(ServerError) {
        _ = try await functions.call(.mutation, "hosting:endEarly", ["eventId": .string(eventID)])
    }

    public func rename(eventID: String, title: String) async throws(ServerError) {
        _ = try await functions.call(.mutation, "hosting:rename", ["eventId": .string(eventID), "title": .string(title)])
    }

    /// Switches the view-only web album on, after the reveal, or off (V2-FR-47).
    public func setWebAlbum(eventID: String, on: Bool) async throws(ServerError) {
        _ = try await functions.call(.mutation, "hosting:setWebAlbum", ["eventId": .string(eventID), "on": .bool(on)])
    }

    public func deleteEvent(eventID: String) async throws(ServerError) {
        _ = try await functions.call(.mutation, "hosting:deleteEvent", ["eventId": .string(eventID)])
    }

    public func removeGuest(eventID: String, membershipID: String) async throws(ServerError) {
        _ = try await functions.call(.mutation, "hosting:removeGuest", [
            "eventId": .string(eventID), "membershipId": .string(membershipID),
        ])
    }

    public func removePictureAsHost(eventID: String, pictureID: String) async throws(ServerError) {
        _ = try await functions.call(.mutation, "hosting:removePictureAsHost", [
            "eventId": .string(eventID), "pictureId": .string(pictureID),
        ])
    }

    /// The signed-in Host's balance of Rolls (V2-FR-61).
    public func balance() async throws(ServerError) -> Int {
        let reply = try await functions.call(.query, "rolls:balance", [:])
        guard let rolls = reply["rolls"]?.number else { throw .failed("The balance could not be read") }
        return Int(rolls)
    }

    // MARK: Joining and the member's place

    public func preview(code: String, as caller: EventCaller) async throws(ServerError) -> JoinPreview {
        var args: [String: JSONValue] = ["code": .string(code)]
        if case .guest(let identity) = caller { args["guest"] = identity.json }
        return try await functions.call(.query, "joining:preview", args).decoded()
    }

    /// Joins, or rejoins, through a Join Code (V2-FR-21, V2-FR-56). A guest's token for the event is kept for its calls.
    public func join(code: String, guestName: String, as caller: EventCaller) async throws(ServerError) -> JoinedPlace {
        var args: [String: JSONValue] = ["code": .string(code), "guestName": .string(guestName)]
        if case .guest(let identity) = caller { args["guest"] = identity.json }
        let place: JoinedPlace = try await functions.call(.mutation, "joining:join", args).decoded()
        if let token = place.guestToken, let expires = place.tokenExpiresAt {
            await sessions.keep(token, expiresAt: expires, eventID: place.event.eventId)
        }
        return place
    }

    public func standing(eventID: String, as caller: EventCaller) async throws(ServerError) -> EventStanding {
        var args: [String: JSONValue] = ["eventId": .string(eventID)]
        if case .guest(let identity) = caller { args["guest"] = identity.json }
        return try await functions.call(.query, "joining:standing", args).decoded()
    }

    public func memberView(eventID: String, as caller: EventCaller) async throws(ServerError) -> MemberView {
        try await asMember(.query, "joining:memberView", eventID: eventID, caller: caller).decoded()
    }

    /// The events the signed-in person joined, for the Film Library on any iPhone they sign in on (V2-FR-04).
    public func joinedEvents() async throws(ServerError) -> [JoinedEvent] {
        try await functions.call(.query, "joining:mine", [:]).decoded()
    }

    public func reportExposures(eventID: String, used: Int, as caller: EventCaller) async throws(ServerError) {
        _ = try await asMember(.mutation, "joining:reportExposures", eventID: eventID, caller: caller,
                               ["exposuresUsed": .number(Double(used))])
    }

    public func leave(eventID: String, as caller: EventCaller) async throws(ServerError) {
        _ = try await asMember(.mutation, "joining:leave", eventID: eventID, caller: caller)
    }

    public func setGuestName(eventID: String, name: String, as caller: EventCaller) async throws(ServerError) {
        _ = try await asMember(.mutation, "joining:setGuestName", eventID: eventID, caller: caller, ["guestName": .string(name)])
    }

    /// Withdraw Before Reveal (V2-FR-50), naming the last exposure the phone had used.
    public func withdraw(eventID: String, throughExposure: Int, as caller: EventCaller) async throws(ServerError) {
        _ = try await asMember(.mutation, "joining:withdraw", eventID: eventID, caller: caller,
                               ["throughExposure": .number(Double(throughExposure))])
    }

    public func removeMyPicture(eventID: String, exposureNumber: Int, as caller: EventCaller) async throws(ServerError) {
        _ = try await asMember(.mutation, "joining:removeMyPicture", eventID: eventID, caller: caller,
                               ["exposureNumber": .number(Double(exposureNumber))])
    }

    public func report(eventID: String, pictureID: String, reason: ReportReason, as caller: EventCaller) async throws(ServerError) {
        _ = try await asMember(.mutation, "reports:report", eventID: eventID, caller: caller,
                               ["pictureId": .string(pictureID), "reason": .string(reason.rawValue)])
    }

    /// The revealed album (V2-FR-43, V2-FR-45).
    public func album(eventID: String, as caller: EventCaller) async throws(ServerError) -> Album {
        try await asMember(.action, "reads:album", eventID: eventID, caller: caller).decoded()
    }

    /// The guest's token for an event, for the upload path.
    public func guestToken(eventID: String, as caller: EventCaller) async throws(ServerError) -> String? {
        guard case .guest(let identity) = caller else { return nil }
        return try await sessions.token(eventID: eventID, identity: identity)
    }

    // MARK: The guest identity

    /// Claim Guest Identity (V2-FR-04): the places the identity held move to the signed-in Account, except where the Account
    /// already holds one in the same event.
    public func claim(_ identity: GuestIdentity) async throws(ServerError) -> (moved: [String], kept: [String]) {
        let reply = try await functions.call(.mutation, "identities:claim", ["guest": identity.json])
        let ids = { (key: String) in reply[key]?.array?.compactMap(\.string) ?? [] }
        return (ids("moved"), ids("kept"))
    }

    /// Delete Guest Identity (V2-FR-57).
    public func deleteGuestIdentity(_ identity: GuestIdentity) async throws(ServerError) {
        _ = try await functions.call(.mutation, "identities:deleteGuestIdentity", ["guest": identity.json])
    }

    public func registerGuestPushToken(_ token: Data, installationID: String, environment: PushEnvironment,
                                       identity: GuestIdentity) async throws(ServerError) {
        _ = try await functions.call(.mutation, "pushTokens:registerGuest", [
            "installationId": .string(installationID),
            "token": .string(token.map { String(format: "%02x", $0) }.joined()),
            "environment": .string(environment.rawValue),
            "guest": identity.json,
        ])
    }

    /// A call as a member: with the signed-in session, or with the guest's token, replaced once if the server refused it.
    private func asMember(_ kind: FunctionKind, _ path: String, eventID: String, caller: EventCaller,
                          _ extra: [String: JSONValue] = [:]) async throws(ServerError) -> JSONValue {
        var args = extra
        args["eventId"] = .string(eventID)
        guard case .guest(let identity) = caller else { return try await functions.call(kind, path, args) }
        args["guestToken"] = .string(try await sessions.token(eventID: eventID, identity: identity))
        do {
            return try await functions.call(kind, path, args)
        } catch .refused(.guestTokenRefused) {
            await sessions.forget(eventID: eventID)
            args["guestToken"] = .string(try await sessions.token(eventID: eventID, identity: identity))
            return try await functions.call(kind, path, args)
        }
    }
}
