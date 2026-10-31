# The Instant's Flash (082)

On 2026-10-30 the captain asked for flash on the Instant: "please add flash option for instant camera. the flash option is locked at off. instant cameras have flash option also."
Until then only the Disposable offered flash (`CaptureBehavior.offersFlash`), and the Instant's shooting screen showed a greyed-out crossed bolt (`bolt.slash`) right of the shutter that could not be turned on.
The Instant now has the Disposable's flash switch in that place, with the same symbol, accessibility label and Large Content Viewer, and by the same rules: an exposure fires the iPhone's flash only where the switch is on and the active lens has a flash; where the lens has none (the front camera) the switch is not offered, the greyed-out bolt stays and the note "Flash unavailable on this lens" shows over the viewfinder; and a lens switch turns it off.
The same day he asked for a developed flash look too: "immerse - add harsh flash look for instant too".
Shown renders made with the Disposable's flash pass, he asked for it "stronger", and shown that stronger values of that pass only darkened the edges, "real flash - brighter subject" (see "The captain's approval").
An Instant exposure the flash lit now develops with a flash snapshot's light (`FilmLook.FlashLight`): the subject in the middle lit clearly brighter, close to blowing out on a near face, the background falling away dark, and a little extra print contrast, on the picture only; the white card is mounted after the treatment and is the same white on every print.
Shown it at two strengths, the captain chose the moderate one, "C", on 2026-10-30.
It is a new treatment version, 5 (`film-look-5`), which differs from version 4 in that alone: a Film loaded with this build records version 5, and an Instant Film loaded before keeps the version it recorded, so its flash fires and lights the scene but its prints develop with no flash look.

Firstmate's stated defaults, checked against the code and the PRD:

- Every open Instant Film gets the switch, those loaded before this build included.
  `CaptureBehavior` derives flash from the Camera, never from the stored `CameraPackage`, and PRD 2.1 section 6 keeps flash among the capture controls that Load Film does not freeze, so no stored data changes.
- The choice stays as set while the camera stops and starts again around each Instant print.
  It did already: the restart is `open` on the same Film, which keeps `flash`, and only a lens switch cleared it.
  This build keeps it so and holds it in a test.
- No low-light cue: the cue is for the Disposable's fixed exposure, and the Instant keeps the phone's automatic exposure (`showsLowLightCue` stays false, so the controller never meters for it).
- The first default, that the Instant's Developed Treatment and treatment version would not change, was superseded the same day by the captain's ask for the flash look.
  Development already read whether the flash fired from the capture's Exif, and a treatment with a flash look already used it (the Disposable's), so the look needed only the Instant's values and a version to hold them.

Manual steps are E01 to E03 in [manual-validation.md](manual-validation.md#the-instants-flash-on-a-real-iphone).

## What changed

- `Packages/NativeAdapters/Sources/NativeAdapters/CaptureBehavior.swift`: the Instant's behavior offers flash.
- `App/Immerse/Sources/CaptureController.swift`:
  - `firesFlash(for:)` is what an exposure asks of the backend: the switch on, a lens with flash, and a Camera that offers it. Before, the shutter sent the switch and the lens's flash without asking whether the Camera offered flash.
  - The flash turns off whenever the running lens changes side (`position`'s `didSet`), which covers Switch Camera, as before, and an `open` that falls back to the rear camera because the one in use is gone.
  - It also turns off when another Film's shooting screen starts (`beginShootingSession(filmID:)`, in the screen's `onAppear`, before its camera opens), and again when that Film's camera attaches in `open`.
    Before this, the controller, which outlives each shooting screen, kept the flash from one Film to the next: a Disposable's flash left on would have fired on the next Instant exposure with no switch to show it, and with the switch it would show as on in a Film where the person never set it.
    Turning it off only in `open` left the last Film's choice on the new screen until the old camera had finished its saves and shut down, and for good if the camera was then denied, so the screen's start turns it off first.
    The same Film's camera, reopened, keeps it, as the Disposable's always did.
- `Packages/RenderCore/Sources/RenderCore/FilmLook.swift`: `TreatmentVersion.five`, "film-look-5"; a `Treatment` can carry a `FlashLight` (stops added at the subject, stops at the corners, how far the full strength holds, extra print contrast), which `FilmLook.instant` does at the strength the captain chose, `FlashLight(subject: 1.3, background: -2, spread: 0.05, contrast: 0.1)`; version 4's Instant is frozen as `instantVersion4`, the same table without it. Every other Camera and Film Stock is the same table in versions 4 and 5, the Disposable's `Flash` included.
- `Packages/RenderCore/Sources/RenderCore/DevelopedTreatment.swift`: renders version 5 as it renders 3 and 4, and on a flash-lit exposure with a `FlashLight` adds the flash's light in linear light before the film and print curve: the picture is multiplied twice by a radial falloff from 1 in the middle to half the way to the corner's stops, so the light falls as the square of the distance beyond a small plateau, then raised by the subject's stops with `CIExposureAdjust`. The Disposable's `Flash` pass and its contrast are untouched.
- `Packages/FilmDomain/Sources/FilmDomain/CameraPackage.swift`: `CameraCatalog.treatmentVersion` is "film-look-5", so every Film loaded from this build records it. On every Camera but the Instant it develops exactly as version 4, and on the Instant it differs only for an exposure the flash lit.
- `App/Immerse/Sources/CaptureView.swift`: the choice of what sits right of the shutter (`flashPlace`) and the lens notes (`lensNotes`) are static functions of the Camera's behavior and the lens's report, so tests read them directly; what they show is unchanged.
- `App/Immerse/Sources/FilmPresentation.swift`: the Instant's controls line on Load Film names the flash, as the Disposable's does: "Auto focus with tap to focus; optional flash; square picture on a white card".
  Its look line stays as it was, which the captain chose on 2026-10-13 ("leave it").
- Tests:
  - `CaptureBehaviorTests`: the Instant's behavior is the square viewfinder and automatic exposure with flash, in every focus setting with no low-light cue, and only the Disposable and the Instant offer flash.
  - `CaptureControllerIntegrationTests` (hosted): `testInstantFlashFiresOnlyWhenOnAndAvailableAndLastsAcrossAPrint` takes an Instant Film through its switch off and on, a lens without flash, a Movie Camera, a print's stop and restart (the switch still on), a dim scene (no cue), a lens switch and another Film (the switch off after each); `testAnotherFilmsShootingScreenStartsWithTheFlashOffBeforeItsCameraOpens` starts the shooting session for the same Film (the switch still on) and then for another, with no open (the switch off at once); `testTheShutterBarOffersTheFlashSwitchWhereTheCameraAndTheLensHaveFlash` checks, for every Camera, the switch where the Camera and the lens have flash, the greyed-out bolt or empty room elsewhere, and the note exactly on the Disposable and the Instant on a lens without flash; the Instant joins the capture-screen screenshots.
  - `FilmLookTests`: today's version is 5 and versions 1 to 5 render (`testDevelopmentAssignsTheTreatmentVersionTheFilmsPackageRecorded`); version 5's tables equal version 4's for every Camera and Film Stock but the Instant, whose differ only in its `FlashLight`, which lights the subject and darkens the background (`testVersionFiveAddsAFlashLightToTheInstantAndChangesNothingElse`); a flash-lit Instant render in version 5 is more than 25 levels brighter in the middle and more than 15 darker at the corner than the unlit one and is byte for byte the unlit one in versions 1 to 4, and an unlit one is the same in versions 4 and 5 (`testTheInstantsFlashLookArrivesWithVersionFiveAndOnlyForAFlashLitExposure`, compared within one run); version 4's Instant table is now `instantVersion4`; the Disposable's flash-lit and unlit renders are the same bytes in versions 4 and 5 and as its version 4 table developed directly (`testTheDisposableDevelopsAsBeforeInVersionFive`).
  - `InstantVersionTests.testTheInstantsFlashLookLeavesTheCardWhite`: a developed print whose capture's Exif says the flash fired is darker at the picture's corner than the unlit one, while its card, sampled 16 pixels clear of the picture on every side, is white and the same pixel for pixel; the fixture, taken without flash, develops alike in versions 4 and 5.
  - `TreatmentVersionDevelopmentTests.testOnlyAnInstantPackLoadedTodayDevelopsAFlashLitPrintWithTheFlashLook`, through the production processor: an Instant pack locked under version 4 develops a flash-lit exposure byte for byte as the unlit one; a pack loaded today records version 5 and develops it with the flash look; unlit exposures are the same under both. The tests that named version 4 as today's now name version 5.
  - `FilmStockRenderTests`: version 4 joins the earlier versions a capture can still be assigned.
  - `JournalIntegrationTests.testLoadFilmCopyFollowsPRD21AndNeverNamesAFormatReference`: a Camera's controls line names the optional flash exactly where `CaptureBehavior` offers the flash switch; `FilmStockUITests.testNoOtherCameraOffersAFilmStock` reads the Instant's new line on its Load Film screen.
- Requirements: PRD 2.1 (its document guide's "Decision of 2026-10-30", section 6.1's Instant row and FR-04, each with a note marked "2026-10-30"), the tracker (CAM-03, two Captain decisions rows and the change log), the evidence map's CAM-03 row and the rows that name the treatment versions, the acceptance evidence's FR-01 A02 and A05, the glossary (`sources/CONTEXT.md`: the Instant's catalog entry and a Relationships rule on how its flash develops, with a note marked "2026-10-30"), and the manual plan's E section with its note on the common steps. PRD 1.5 stays as history.

## What it leaves alone

The Disposable's flash, its flash look, its low-light cue and their tests; the 6×6 and the Movie Cameras, which offer no flash and develop as before; the Instant's automatic exposure and its look on an exposure without flash; every earlier treatment version; every stored Film and Camera package; and the front camera's note.
No persistence, entitlement or migration code changed.

Reverting: before a build with version 5 reaches a phone that keeps its data, a revert restores everything, the greyed-out bolt included.
After one has, Instant Films loaded with it record "film-look-5", and a build that no longer knows that version refuses to develop them rather than develop them with another look, as with version 4 (`instant-study-and-toning-061.md`).
So once version 5 has shipped, a wrong flash look is put right by a version 6 with version 5 kept renderable, and taking the switch away means keeping version 5 in `RenderCore`.

## The captain's approval

Six of the look boards' scenes (`Evidence/AssetReview/looks/SOURCES.md`: two lit by on-camera flash, two portraits, a night street and a bright beach) went to the captain three times, developed through the app's Instant path with the same seed for every Instant print of a scene, beside the print without flash and the Disposable's flash print. The renders were made outside the repository and are not kept in it.
Brightness below is the mean, 0 to 255, of the middle of the picture (its central 18 percent) and of its top-left corner.

1. The Disposable's own pass and values, `Flash(falloff: 0.9, contrast: 0.1)`: the Instant's flash print read barely different from the unlit one. His answer: "stronger".
2. The same pass at falloff 1.6 and contrast 0.2, and at 2.4 and 0.3: the corners fell by 31 to 45 levels at the stronger, but the middle stayed within about 7 levels of the unlit print and on the flash-lit portraits ended a little darker. His answer, choosing "Build a real Instant flash: brighter, hotter subject plus dark edges": "real flash - brighter subject".
3. The `FlashLight` step at two strengths: C `FlashLight(subject: 1.3, background: -2, spread: 0.05, contrast: 0.1)`, and D, `FlashLight(subject: 2, background: -3, spread: 0.05, contrast: 0.15)`. The middle is 24 to 50 levels brighter at C and 42 to 74 at D, and the corner 14 to 39 levels darker at C and 17 to 46 at D. At every strength the card matched the unlit print's pixel for pixel. His answer: "C". D stays here as history only; the app has C.

Why the Disposable's pass could not do it on the Instant: its hot center is a `CIRadialGradient` whose middle level, 2 to the power of a third of the falloff, is above 1, and Core Image clamps a gradient's colors to 1, so that pass only ever darkens toward the corners and never brightens the middle; the extra print contrast then pulls the middle tones down. On the Disposable that is the look the captain approved on its board, and it stays as it is. The Instant's step keeps its mask at or below 1 and raises the exposure with `CIExposureAdjust`, which nothing caps, before the film and the faded print curve.

## Outcomes

Run on 2026-10-30 on this Intel Mac with Xcode 26.5, the hosted tests on a new iPhone 17 Pro simulator on iOS 26.2, quieted with `Scripts/quiet-simulator.sh`:

- `swift test --package-path Packages/NativeAdapters --filter CaptureBehaviorTests`: 14 tests pass.
- `swift test --package-path Packages/RenderCore`, `FilmLookTests`, `InstantVersionTests`, `FilmStockRenderTests` and `LegacyLookTests`: 39 tests pass with the `FlashLight` step at C. On the way, `testVersionThreeKeepsTheInstantAsItWasBeforeTheStudy` was moved from `FilmLook.instant` to `instantVersion4` (it compared version 4 with today's table, which now has the flash), and the card test asks for the corner's falloff, since with the first values the middle of the fixture moved about 1 level. Byte comparisons inside one run hold on any Mac; only CI's arm64 runner proves the rest of the render suite there.
- `swift test --package-path Packages/FilmRuntime --filter TreatmentVersionDevelopmentTests`: 5 tests pass.
- `CaptureControllerIntegrationTests`: all 23 tests pass, the three new ones among them, rerun on 2026-10-31 on the same iOS 26.2 simulator after the flash's reset moved to the shooting screen's start, with `CaptureSidewaysTests.testTheHoldLastsWhileAPrintIsOverTheScreenAndEndsWithIt`, which also passes.
- `CaptureSidewaysTests`: all 33 tests pass, before the version 5 change, which touches no screen; its Instant screenshots show the flash switch right of the shutter, where they showed the greyed-out bolt.

The simulator has no camera, so nothing here fires a flash or lights a print: the switch's state and what the exposure asks of the backend are all a simulator shows.
Whether the iPhone's flash fires, how the flash look reads on real flash-lit prints, and the switch on the front camera of a real iPhone are E01 to E03.
