import CryptoKit
import Foundation

/// A developed picture waiting on the phone to be sent (V2-FR-34, V2-FR-35).
public struct PictureToSend: Sendable {
    public let eventID: String
    public let exposureNumber: Int
    public let captureTime: Date
    public let contentType: String
    public let fileURL: URL
    /// The smaller viewing copy the phone made of the developed picture (v2 PRD section 9.4), a JPEG, if any.
    public let viewFileURL: URL?
    /// The guest's token for this event; nil when the shooter is signed in.
    public let guestToken: String?

    public init(eventID: String, exposureNumber: Int, captureTime: Date, contentType: String = "image/jpeg", fileURL: URL,
                viewFileURL: URL? = nil, guestToken: String? = nil) {
        self.eventID = eventID
        self.exposureNumber = exposureNumber
        self.captureTime = captureTime
        self.contentType = contentType
        self.fileURL = fileURL
        self.viewFileURL = viewFileURL
        self.guestToken = guestToken
    }
}

/// What the phone does with its copy once a send ends.
public enum SendOutcome: Equatable, Sendable {
    /// The server confirmed the picture whole, by size and checksum: the phone may delete its copy.
    case stored
    /// The server will never take this picture (withdrawn or removed, its shooter removed, taken after the End Time, or
    /// the event gone): the phone deletes it and tells the shooter (V2-FR-34).
    case refused(RefusalCode)
}

/// Sends one developed picture through the upload path of v2 PRD section 9.3: a one-time address from the server, the
/// file straight to R2 with URLSession, then the server's confirmation by size and checksum. A failure that leaves the
/// picture unconfirmed throws, and the phone keeps the picture and sends it again later; every step is safe to repeat.
public struct PictureUploader: Sendable {
    private let functions: any ServerFunctions
    private let session: URLSession
    /// How many times one send asks for a fresh address when storage turns the upload away or the server finds the
    /// object missing or different.
    private let attempts: Int

    public init(functions: any ServerFunctions, session: URLSession = .shared, attempts: Int = 3) {
        self.functions = functions
        self.session = session
        self.attempts = attempts
    }

    public enum UploadError: Error, Equatable, Sendable {
        case server(ServerError)
        case unreadableFile
        /// Storage or the server kept turning the picture away; it stays on the phone.
        case notConfirmed
    }

    /// The file's size and base64 SHA-256, read in chunks so a large picture is never held whole in memory.
    public static func fingerprint(of fileURL: URL) throws -> (size: Int, sha256: String) {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        var size = 0
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
            size += chunk.count
        }
        return (size, Data(hasher.finalize()).base64EncodedString())
    }

    public func send(_ picture: PictureToSend) async throws(UploadError) -> SendOutcome {
        let fingerprint: (size: Int, sha256: String)
        let viewFingerprint: (size: Int, sha256: String)?
        do {
            fingerprint = try Self.fingerprint(of: picture.fileURL)
            viewFingerprint = try picture.viewFileURL.map(Self.fingerprint(of:))
        } catch { throw .unreadableFile }
        var base: [String: JSONValue] = [
            "eventId": .string(picture.eventID),
            "exposureNumber": .number(Double(picture.exposureNumber)),
        ]
        if let token = picture.guestToken { base["guestToken"] = .string(token) }
        var request = base
        request["captureTime"] = .number((picture.captureTime.timeIntervalSince1970 * 1000).rounded())
        request["contentType"] = .string(picture.contentType)
        request["size"] = .number(Double(fingerprint.size))
        request["sha256"] = .string(fingerprint.sha256)
        if let viewFingerprint {
            request["view"] = ["size": .number(Double(viewFingerprint.size)), "sha256": .string(viewFingerprint.sha256)]
        }

        for _ in 0..<attempts {
            let address: JSONValue
            do {
                address = try await functions.call(.action, "pictures:requestUpload", request)
            } catch {
                if let refusal = Self.finalRefusal(error) { return .refused(refusal) }
                throw .server(error)
            }
            if address["status"]?.string == "stored" { return .stored }
            guard let main = Self.request(address), let view = Self.viewRequest(address, expected: picture.viewFileURL != nil) else {
                throw .server(.failed("The upload address could not be read"))
            }
            // Turned away (an address that ran out, a body storage refused): ask for fresh addresses.
            guard try await put(main, from: picture.fileURL) else { continue }
            if let viewRequest = view, let viewFile = picture.viewFileURL {
                guard try await put(viewRequest, from: viewFile) else { continue }
            }
            let confirmation: JSONValue
            do {
                confirmation = try await functions.call(.action, "pictures:confirmUpload", base)
            } catch {
                if let refusal = Self.finalRefusal(error) { return .refused(refusal) }
                throw .server(error)
            }
            if confirmation["status"]?.string == "stored" { return .stored }
            // "missing" or "mismatch": send it again.
        }
        throw .notConfirmed
    }

    /// The PUT an upload address describes.
    private static func request(_ address: JSONValue) -> URLRequest? {
        guard let urlText = address["url"]?.string, let url = URL(string: urlText) else { return nil }
        var put = URLRequest(url: url)
        put.httpMethod = "PUT"
        if case .object(let headers) = address["headers"] ?? .null {
            for (name, value) in headers { if let value = value.string { put.setValue(value, forHTTPHeaderField: name) } }
        }
        return put
    }

    /// The viewing copy's PUT, when the picture has one: `.some(nil)` when it has none, nil when one was expected and
    /// the reply lacks it.
    private static func viewRequest(_ address: JSONValue, expected: Bool) -> URLRequest?? {
        guard expected else { return .some(nil) }
        guard let view = address["view"], let request = request(view) else { return nil }
        return .some(request)
    }

    /// Sends a file to an upload address. False when storage turned it away.
    private func put(_ request: URLRequest, from file: URL) async throws(UploadError) -> Bool {
        do {
            let (_, response) = try await session.upload(for: request, fromFile: file)
            return (200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch {
            throw .server(.unreachable)
        }
    }

    /// The refusals after which the server will never take the picture: withdrawn or removed, its shooter removed, taken
    /// after the End Time, or the event gone (V2-FR-34).
    static func finalRefusal(_ error: ServerError) -> RefusalCode? {
        guard case .refused(let code) = error else { return nil }
        switch code {
        case .pictureRemoved, .afterEndTime, .eventGone, .notAMember, .exposureTaken, .removedFromEvent: return code
        default: return nil
        }
    }
}
