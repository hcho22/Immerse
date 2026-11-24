import FilmDomain
import FilmPersistence
import Foundation
import ImageIO
import RenderCore
import UniformTypeIdentifiers

/// One picture of an event Roll developed on the phone that took it (v2 PRD V2-FR-33), and the smaller viewing copy the
/// phone uploads beside it (section 9.4).
///
/// A Disposable or 6×6 picture develops soon after it is saved, so it can upload before the End Time, without being
/// shown to anyone, its shooter included: it renders through Development's own call (`CaptureDevelopment`) with the
/// treatment Development assigns the capture, so it is byte for byte what the Roll's Development would make, and it
/// leaves the Roll's store unchanged and the capture sealed. An Instant print has already developed at the camera, as
/// in a personal Instant Film, and its print is read back. There is no other render path, and no server-side one.
public enum EventPictureDevelopment {
    /// The developed JPEG of saved capture `sequenceNumber` of the event Roll at `root`.
    public static func developed(root: URL, filmID: UUID, sequenceNumber: Int) throws -> Data {
        let repository = try FilmRepository(rootURL: root)
        guard try repository.filmAccess(filmID: filmID).isGroupRoll else { throw PersistenceError.notAnEventRoll }
        let film = try repository.film(id: filmID)
        guard film.camera.medium == .photo else { throw FilmDomainError.wrongCameraMedium }
        guard film.captures.contains(where: { $0.sequenceNumber == sequenceNumber && !$0.isDiscarded }) else {
            throw PersistenceError.captureNotFound
        }
        if let master = try repository.mediaAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .master) {
            return try Data(contentsOf: master.url)
        }
        guard film.camera.revealRule != .instantPerExposure else { throw PersistenceError.missingVerifiedMaster }
        guard let source = try repository.mediaAsset(filmID: filmID, sequenceNumber: sequenceNumber, kind: .source) else {
            throw PersistenceError.captureNotFound
        }
        let run = try repository.developmentRun(filmID: filmID) ?? DevelopmentRun(film: film)
        let treatment = run.assignments[sequenceNumber]
            ?? DevelopmentRun.plannedAssignment(film: film, sequenceNumber: sequenceNumber)
        guard run.rendersAssignedTreatment(treatment) else { throw PersistenceError.treatmentConflict }
        return try CaptureDevelopment.master(source: source.url, film: film, treatment: treatment, run: run)
    }

    /// The viewing copy's longest side, in pixels: enough for the album's grid and a full-screen look on any iPhone,
    /// a small part of the full picture's size; saving downloads the full picture.
    public static let viewingCopyLongestSide = 1600

    public enum ViewingCopyError: Error, Equatable { case unreadable, unwritable }

    /// A smaller JPEG of a developed picture, made on the phone, carrying no metadata, so a copy shared on carries no
    /// name or place (V2-FR-46).
    public static func viewingCopy(of developed: Data, longestSide: Int = viewingCopyLongestSide) throws -> Data {
        guard let source = CGImageSourceCreateWithData(developed as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: longestSide,
              ] as CFDictionary) else { throw ViewingCopyError.unreadable }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ViewingCopyError.unwritable
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ViewingCopyError.unwritable }
        return output as Data
    }
}
