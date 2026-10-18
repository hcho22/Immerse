@preconcurrency import AVFoundation
import Foundation

extension AVAssetReader {
    /// What a reader that did not finish says, for a failure message: its status and the error AVFoundation gave, with
    /// the domain, code, reason and every error underneath it, since the status alone names no cause. RenderCore's tests
    /// keep the same helper (`RenderTestSupport.swift`), held to its content by their `ReaderFailureTests`.
    func failureDescription(framesRead: Int) -> String {
        var lines = ["reader status \(status.name) (\(status.rawValue)) after \(framesRead) frames"]
        var error = self.error as NSError?
        var depth = 0
        while let current = error {
            lines.append("\(depth == 0 ? "error" : "underlying error"): \(current.domain) \(current.code), "
                + "\"\(current.localizedDescription)\""
                + (current.localizedFailureReason.map { ", reason \"\($0)\"" } ?? ""))
            error = current.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        if depth == 0 { lines.append("no error recorded") }
        return lines.joined(separator: "; ")
    }
}

private extension AVAssetReader.Status {
    var name: String {
        switch self {
        case .unknown: "unknown"
        case .reading: "reading"
        case .completed: "completed"
        case .failed: "failed"
        case .cancelled: "cancelled"
        @unknown default: "new"
        }
    }
}
