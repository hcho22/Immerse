import CryptoKit
import FilmDomain
import Foundation

public enum MediaCatalogError: Error, Equatable, Sendable {
    case invalidManifest, invalidPath, unapprovedRights, checksumMismatch, assetNotFound, incompatibleAsset
}

public enum SoundtrackReselectionPolicy: String, Codable, Sendable {
    case initialChoiceOnly, allowed
}

public struct MediaRights: Codable, Equatable, Sendable {
    public enum Clearance: String, Codable, Sendable { case productionApproved, syntheticTestOnly }
    public let clearance: Clearance
    public let creator: String
    public let source: String
    public let acquiredAt: String
    public let approvalReference: String
    public let licensePath: String
    public let licenseSHA256: String
    public let permitsBundling: Bool
    public let permitsMovieExport: Bool
    public let attribution: String
}

public struct CatalogMediaAsset: Codable, Equatable, Identifiable, Sendable {
    public enum Purpose: String, Codable, Sendable { case cameraSample, instrumental }
    public enum Kind: String, Codable, Sendable { case photo, movie, audio }
    public let id: String
    public let title: String
    public let cameraIDs: [CameraID]
    public let purpose: Purpose
    public let kind: Kind
    public let resourcePath: String
    public let sha256: String
    public let rights: MediaRights
}

public struct MediaCatalogManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let soundtrackReselection: SoundtrackReselectionPolicy?
    public let assets: [CatalogMediaAsset]
}

public struct VerifiedCatalogAsset: Sendable {
    public let metadata: CatalogMediaAsset
    public let url: URL
    public let license: Data

    fileprivate init(metadata: CatalogMediaAsset, url: URL, license: Data) {
        self.metadata = metadata
        self.url = url
        self.license = license
    }

    public func data() throws -> Data {
        let data = try Data(contentsOf: url)
        guard BundleMediaCatalog.digest(data) == metadata.sha256 else { throw MediaCatalogError.checksumMismatch }
        return data
    }
}

public struct BundleMediaCatalog: Sendable {
    public let manifest: MediaCatalogManifest
    private let root: URL

    public init(rootURL: URL, manifestData: Data) throws {
        try self.init(rootURL: rootURL, manifestData: manifestData, allowSyntheticFixtures: false)
    }

    // Only @testable package tests can admit fixtures; the app always uses the public initializer.
    init(rootURL: URL, manifestData: Data, allowSyntheticFixtures: Bool) throws {
        let manifest = try JSONDecoder().decode(MediaCatalogManifest.self, from: manifestData)
        guard manifest.schemaVersion == 1,
              Set(manifest.assets.map(\.id)).count == manifest.assets.count else { throw MediaCatalogError.invalidManifest }
        root = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        self.manifest = manifest
        for asset in manifest.assets {
            guard !asset.id.isEmpty, !asset.title.isEmpty, !asset.cameraIDs.isEmpty,
                  Set(asset.cameraIDs).count == asset.cameraIDs.count,
                  Self.isDigest(asset.sha256), Self.isDigest(asset.rights.licenseSHA256) else {
                throw MediaCatalogError.invalidManifest
            }
            let rights = asset.rights
            guard rights.permitsBundling,
                  rights.clearance == .productionApproved || allowSyntheticFixtures,
                  [rights.creator, rights.source, rights.acquiredAt, rights.approvalReference].allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw MediaCatalogError.unapprovedRights
            }
            if asset.purpose == .instrumental {
                guard asset.kind == .audio, rights.permitsMovieExport,
                      asset.cameraIDs.allSatisfy({ CameraCatalog.package(for: $0).supportsBuiltInSoundtrack }) else {
                    throw MediaCatalogError.incompatibleAsset
                }
            } else {
                guard asset.kind != .audio, asset.cameraIDs.allSatisfy({
                    (CameraCatalog.package(for: $0).medium == .photo) == (asset.kind == .photo)
                }) else { throw MediaCatalogError.incompatibleAsset }
            }
            _ = try resolve(id: asset.id)
        }
    }

    public func assets(for camera: CameraID, purpose: CatalogMediaAsset.Purpose) -> [CatalogMediaAsset] {
        manifest.assets.filter { $0.cameraIDs.contains(camera) && $0.purpose == purpose }
    }

    public func resolve(id: String) throws -> VerifiedCatalogAsset {
        guard let asset = manifest.assets.first(where: { $0.id == id }) else { throw MediaCatalogError.assetNotFound }
        let url = try localURL(asset.resourcePath)
        let license = try Data(contentsOf: localURL(asset.rights.licensePath))
        guard !license.isEmpty, Self.digest(license) == asset.rights.licenseSHA256 else {
            throw MediaCatalogError.checksumMismatch
        }
        let verified = VerifiedCatalogAsset(metadata: asset, url: url, license: license)
        _ = try verified.data()
        return verified
    }

    private func localURL(_ path: String) throws -> URL {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains(":"),
              !path.split(separator: "/").contains("..") else { throw MediaCatalogError.invalidPath }
        let url = root.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path.hasPrefix(root.path + "/") else { throw MediaCatalogError.invalidPath }
        return url
    }

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func isDigest(_ string: String) -> Bool {
        string.count == 64 && string.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
