import Foundation

/// Convex's HTTP API: one POST per function call to `/api/query`, `/api/mutation` or `/api/action`, with the signed-in
/// person's Clerk session token as a bearer token when there is one.
///
/// Chosen over Convex's Swift client for Stage 1 because it adds nothing to the app's size: the Swift client carries a
/// Rust core of about 5.3 MB, which would matter most in the 15 MB mini-app of Stage 3. It gives up live subscriptions,
/// which Stage 1 does not use; `ServerFunctions` lets a later stage put the Swift client behind the same calls.
public struct ConvexHTTPClient: ServerFunctions {
    public typealias TokenSource = @Sendable () async -> String?

    private let deploymentURL: URL
    private let session: URLSession
    private let sessionToken: TokenSource

    /// - Parameter sessionToken: the current Clerk session token, or nil when nobody is signed in.
    public init(deploymentURL: URL, session: URLSession = .shared, sessionToken: @escaping TokenSource) {
        self.deploymentURL = deploymentURL
        self.session = session
        self.sessionToken = sessionToken
    }

    private struct Body: Encodable {
        let path: String
        let args: [String: JSONValue]
        let format = "json"
    }

    private struct Reply: Decodable {
        let status: String?
        let value: JSONValue?
        let errorMessage: String?
        let errorData: JSONValue?
    }

    public func call(_ kind: FunctionKind, _ path: String, _ args: [String: JSONValue]) async throws(ServerError) -> JSONValue {
        var request = URLRequest(url: deploymentURL.appending(path: "api/\(kind.rawValue)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await sessionToken() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        do {
            request.httpBody = try JSONEncoder().encode(Body(path: path, args: args))
        } catch {
            throw .failed("The request could not be encoded")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .unreachable
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let reply = try? JSONDecoder().decode(Reply.self, from: data)
        if (200..<300).contains(status), let reply, reply.status == "success" { return reply.value ?? .null }
        if let code = reply?.errorData?["code"]?.string { throw .refused(RefusalCode(code)) }
        // A session token that fails Convex's verification is refused before any function runs.
        if status == 401 || status == 403 { throw .refused(.unauthenticated) }
        if status >= 500 || status == 0 { throw .unreachable }
        throw .failed(reply?.errorMessage ?? "HTTP \(status)")
    }
}
