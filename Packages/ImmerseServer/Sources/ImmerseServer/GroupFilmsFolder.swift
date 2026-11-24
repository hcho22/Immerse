import Foundation

/// Where an iPhone keeps its Group Films (v2 PRD V2-FR-19, V2-FR-34): the places it holds, its Rolls and their pictures,
/// and the upload queue.
///
/// The mini-app and the full app keep them in the same folder, in the App Group container the two share (Apple: "Store
/// App Clip data and assets in a shared container and access them in your full app"). So a guest who installs the full
/// app after joining in the mini-app finds the same event, Roll, remaining exposures and waiting pictures with nothing
/// copied, nothing lost and nothing sent twice: the full app opens the folder the mini-app wrote. A build with no App
/// Group, such as every build without the server configuration, keeps the folder in its own Application Support, as
/// Stage 2 did.
///
/// Only one of the two writes at a time. iOS gives every link to the full app once it is installed, so the mini-app
/// should never run again; if it does (it was still open when the full app first ran), it finds the full app's mark
/// here and hands the guest over instead of writing.
public struct GroupFilmsFolder: Equatable, Sendable {
    public let url: URL
    /// Whether the folder is in the container shared with the mini-app.
    public let isShared: Bool

    public init(url: URL, isShared: Bool) {
        self.url = url
        self.isShared = isShared
    }

    private static let folderName = "GroupFilms"

    /// The folder for this build: in the App Group's container when the build names a group it is entitled to, otherwise
    /// in the app's own Application Support.
    public static func locate(appGroup: String?, fileManager: FileManager = .default) throws -> GroupFilmsFolder {
        if let appGroup, let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            let folder = GroupFilmsFolder(url: container.appending(path: folderName, directoryHint: .isDirectory), isShared: true)
            try folder.adopt(local: try localFolder(fileManager), fileManager: fileManager)
            return folder
        }
        return GroupFilmsFolder(url: try localFolder(fileManager), isShared: false)
    }

    private static func localFolder(_ fileManager: FileManager) throws -> URL {
        try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: folderName, directoryHint: .isDirectory)
    }

    /// A build that gains the App Group moves what it kept in its own folder into the shared one, once, and only when the
    /// shared one holds nothing yet. The move is one rename on the same volume: it happens whole or not at all.
    func adopt(local: URL, fileManager: FileManager = .default) throws {
        guard fileManager.fileExists(atPath: local.path), !fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: local, to: url)
    }

    private var takeOverMark: URL { url.appending(path: "full-app-took-over") }

    /// Whether the full app has run here. The mini-app reads it and hands over rather than write beside the full app.
    public var fullAppTookOver: Bool {
        FileManager.default.fileExists(atPath: takeOverMark.path)
    }

    /// The full app marks the folder as its own each time it starts. Marking it again changes nothing.
    public func markTakenOverByFullApp() throws {
        guard !fullAppTookOver else { return }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data().write(to: takeOverMark, options: .atomic)
    }
}
