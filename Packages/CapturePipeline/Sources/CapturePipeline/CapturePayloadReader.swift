import Foundation

public protocol CapturePayloadReading {
    func data(for url: URL) throws -> Data
}

public struct FileCapturePayloadReader: CapturePayloadReading {
    public init() {}

    public func data(for url: URL) throws -> Data {
        try Data(contentsOf: url)
    }
}
