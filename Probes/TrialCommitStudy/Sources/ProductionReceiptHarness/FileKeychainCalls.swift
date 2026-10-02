import EntitlementCore
import Foundation
import Security

/// Ordinary test file outside the disposable app directory. This deliberately
/// makes no Security calls and establishes no physical Keychain guarantees.
public struct FileKeychainCalls: TrialKeychainCalling {
    private let url: URL
    public init(url: URL) { self.url = url }

    public func read(service: String) -> TrialKeychainRead {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return TrialKeychainRead(status: errSecItemNotFound, data: nil)
        }
        do { return TrialKeychainRead(status: errSecSuccess, data: try Data(contentsOf: url)) }
        catch { return TrialKeychainRead(status: errSecNotAvailable, data: nil) }
    }
    public func add(service: String, data: Data) -> OSStatus {
        guard !FileManager.default.fileExists(atPath: url.path) else { return errSecDuplicateItem }
        return write(data)
    }
    public func update(service: String, data: Data) -> OSStatus {
        guard FileManager.default.fileExists(atPath: url.path) else { return errSecItemNotFound }
        return write(data)
    }
    private func write(_ data: Data) -> OSStatus {
        do {
            try data.write(to: url, options: .atomic)
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.synchronize()
            return errSecSuccess
        } catch { return errSecNotAvailable }
    }
}
