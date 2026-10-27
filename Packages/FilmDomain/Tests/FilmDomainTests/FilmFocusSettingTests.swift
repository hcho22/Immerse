import XCTest
@testable import FilmDomain

final class FilmFocusSettingTests: XCTestCase {
    func testEachFilmStartsOnAutoAndOnlyOffersItsCameraModes() throws {
        let disposable = try Film(camera: CameraCatalog.disposable1990s, title: "Roll")
        XCTAssertEqual(disposable.effectiveFocusSetting, .auto)
        XCTAssertEqual(disposable.camera.focusSettings, [.auto, .fixed])
        var fixed = disposable
        try fixed.setFocusSetting(.fixed)
        XCTAssertEqual(fixed.effectiveFocusSetting, .fixed)
        XCTAssertThrowsError(try fixed.setFocusSetting(.manual)) {
            XCTAssertEqual($0 as? FilmDomainError, .focusSettingNotOffered)
        }

        let sixBySix = try Film(camera: CameraCatalog.mediumFormat6x6, title: "Square", filmStock: .color)
        XCTAssertEqual(CameraCatalog.mediumFormat6x6.focusSettings, [.auto, .manual])
        var manual = sixBySix
        try manual.setFocusSetting(.manual)
        XCTAssertEqual(manual.effectiveFocusSetting, .manual)
        XCTAssertThrowsError(try manual.setFocusSetting(.fixed)) {
            XCTAssertEqual($0 as? FilmDomainError, .focusSettingNotOffered)
        }

        XCTAssertEqual(CameraCatalog.super8HomeMovie.focusSettings, [.auto, .fixed])
        XCTAssertEqual(CameraCatalog.cinema16mm.focusSettings, [.auto])

        for camera in [CameraCatalog.instant1970s, CameraCatalog.cinema16mm] {
            XCTAssertEqual(camera.focusSettings, [.auto])
            let film = try Film(camera: camera, title: "Auto", movieOrientation: camera.medium == .movie ? .portrait : nil,
                                filmStock: camera.defaultFilmStock)
            var changed = film
            XCTAssertThrowsError(try changed.setFocusSetting(.fixed)) {
                XCTAssertEqual($0 as? FilmDomainError, .focusSettingNotOffered)
            }
        }
    }

    func testOlderFilmWithoutFocusSettingOpensOnAuto() throws {
        let earlier = #"{"camera":{"capacity":{"exposures":{"_0":12}},"displayName":"1960s 6x6 Medium Format","id":"mediumFormat6x6","medium":"photo","revealRule":"rollLevelDevelopment","supportsBuiltInSoundtrack":false},"captures":[],"completionState":{"open":{}},"developmentState":"notStarted","id":"0F6D1E2A-6C1B-4B8E-9C11-5A0E7E2B9D41","isArchived":false,"loadedAt":811692800,"title":"6x6 - Roll #01"}"#
        let film = try JSONDecoder().decode(Film.self, from: Data(earlier.utf8))
        XCTAssertNil(film.focusSetting, "An older Film is not rewritten when decoded")
        XCTAssertEqual(film.effectiveFocusSetting, .auto)

        var changed = film
        try changed.setFocusSetting(.manual)
        let saved = try JSONDecoder().decode(Film.self, from: JSONEncoder().encode(changed))
        XCTAssertEqual(saved.focusSetting, .manual)
    }
}
