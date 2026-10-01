import CryptoKit
import Foundation
import Synchronization

final class ScenarioEvidence: Sendable {
    let directory: URL
    private let lock = Mutex(0)
    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func persist<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(value).write(to: url, options: .atomic)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    func record(_ event: String, _ fields: [String: String] = [:]) {
        lock.withLock { sequence in
            sequence += 1
            var row = fields
            row["event"] = event
            row["utc"] = ISO8601DateFormatter().string(from: Date())
            row["process"] = String(ProcessInfo.processInfo.processIdentifier)
            row["processSequence"] = String(sequence)
            do {
                let url = directory.appendingPathComponent("events.jsonl")
                if !FileManager.default.fileExists(atPath: url.path) {
                    try Data().write(to: url, options: .withoutOverwriting)
                }
                let handle = try FileHandle(forWritingTo: url)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: JSONSerialization.data(withJSONObject: row, options: .sortedKeys) + Data([10]))
                try handle.synchronize()
            } catch {
                // Evidence loss must stop this harness, never turn a scenario green.
                fatalError("Receipt harness evidence write failed: \(error)")
            }
        }
    }
}
