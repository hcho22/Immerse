import CryptoKit
import Foundation

enum Checksum {
    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(contentsOf url: URL) throws -> String {
        try sha256Hex(Data(contentsOf: url))
    }
}
