import FilmDomain
@testable import FilmPersistence
import XCTest

/// The Film store says when it cannot be written for want of space, so the app tells the person to free space then, and
/// only then (Evidence/NativeApp/development-stop-079.md). SQLite's own limit on the store's pages stands in for a full
/// disk: past it SQLite answers as it does to a full disk, "database or disk is full".
final class StoreOutOfSpaceTests: XCTestCase {
    func testAStoreThatCannotGrowSaysItIsOutOfSpaceAndKeepsWhatItHeld() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StoreOutOfSpace-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try FilmRepository(rootURL: root)
        let film = try repository.createFilm(camera: CameraCatalog.disposable1990s, title: "Synthetic roll")
        try repository.database.execute("PRAGMA wal_checkpoint(TRUNCATE);")
        try repository.database.execute("PRAGMA max_page_count = 1;")
        do {
            try repository.database.setValue(filmID: film.id, key: "filler", data: Data(repeating: 7, count: 1_000_000))
            XCTFail("A store that cannot grow took a megabyte")
        } catch let error as PersistenceError {
            XCTAssertEqual(error, .outOfSpace)
        }
        XCTAssertEqual(try repository.film(id: film.id).title, "Synthetic roll", "What the store held is kept")
        XCTAssertNil(try repository.database.value(filmID: film.id, key: "filler"))
    }
}
