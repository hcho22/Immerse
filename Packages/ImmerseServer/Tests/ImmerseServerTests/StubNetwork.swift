import Foundation
import Synchronization

/// A network stand-in: every request a test's URLSession makes is recorded and answered by the test's handler.
final class StubNetwork: URLProtocol, @unchecked Sendable {
    struct Recorded: Sendable {
        let method: String
        let url: URL
        let headers: [String: String]
        let body: Data
    }

    typealias Handler = @Sendable (Recorded) -> (status: Int, body: Data)

    private static let state = Mutex<(handler: Handler?, recorded: [Recorded])>((nil, []))

    static func session(handler: @escaping Handler) -> URLSession {
        state.withLock { $0 = (handler, []) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubNetwork.self]
        return URLSession(configuration: configuration)
    }

    static var recorded: [Recorded] { state.withLock { $0.recorded } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 65_536)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(buffer, count: count)
            }
            stream.close()
        }
        let recorded = Recorded(method: request.httpMethod ?? "GET", url: request.url!,
                                headers: request.allHTTPHeaderFields ?? [:], body: body)
        let handler = Self.state.withLock { state -> Handler? in
            state.recorded.append(recorded)
            return state.handler
        }
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let (status, data) = handler(recorded)
        if status == 0 {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func json(_ object: Any) -> Data { try! JSONSerialization.data(withJSONObject: object) }

func success(_ value: Any) -> (status: Int, body: Data) { (200, json(["status": "success", "value": value, "logLines": []])) }

func refusal(_ code: String) -> (status: Int, body: Data) {
    (200, json(["status": "error", "errorMessage": code, "errorData": ["code": code, "message": code], "logLines": []]))
}

/// The Convex function a recorded HTTP API request called, and its arguments.
func convexCall(_ recorded: StubNetwork.Recorded) -> (path: String, args: [String: Any])? {
    guard let object = try? JSONSerialization.jsonObject(with: recorded.body) as? [String: Any],
          let path = object["path"] as? String else { return nil }
    return (path, object["args"] as? [String: Any] ?? [:])
}
