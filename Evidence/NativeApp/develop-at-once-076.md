# Develop at once, a Debug-only preview (076)

The captain (2026-10-21): "can you implement a feature where I could develop instantaneously for all the cameras during the development phase, such as right now, so that I could give immediate feedback? Currently, I have to finish the entire roll for each camera except for instant, so it's hard for me to provide immediate feedback for 6x6, disposable, 16 mm, or Super 8 cameras."
Asked the same day, he chose:

- **Instant preview**: every photo or clip of the 6×6 Medium Format, the 1990s Disposable, the 16mm Cinema and the 1960s Super 8 Home Movie shows a developed copy right away, in that Camera's look and the Film Stock chosen at Load Film; the roll stays sealed and develops normally at the end.
- **Xcode builds only**: like the Testing unlock, only Debug builds have it, and Release (TestFlight, App Store) has none of it.
- **On, switch in Settings**: on in a fresh Debug build, turned off in Settings to test the real experience, with a notice so screenshots are not mistaken for the real thing.

Manual steps are P01 to P05 in [manual-validation.md](manual-validation.md#develop-at-once-on-a-real-iphone).

## What changed

- `Packages/RenderCore/Sources/RenderCore/DevelopmentRun.swift`: the treatment Development assigns a capture that has none (its seed from the Film and the capture's number, in the Film's treatment version) is now one public function, `DevelopmentRun.plannedAssignment(film:sequenceNumber:)`, which `assignMissingTreatments` and `markRendered` call instead of building it twice. The seed and version are unchanged.
- `Packages/FilmRuntime/Sources/FilmRuntime/FilmProcessor.swift`: the render of one capture inside `DevelopmentWorker.run` is now `CaptureDevelopment.master` and `CaptureDevelopment.clip`, with the same arguments as before. The clip's Movie orientation, which was force-unwrapped, now throws `FilmDomainError.wrongCameraMedium` if absent; a Movie Film always has one, so no Film develops differently.
- `Packages/FilmRuntime/Sources/FilmRuntime/PreviewDevelopment.swift`, entirely under `#if DEBUG`: develops one saved capture of an open Film into a given folder, through `CaptureDevelopment`, with the capture's assigned treatment if a Development record has one, else `plannedAssignment`. It reads the Film, its Development record and the capture's source and writes nothing but the preview file, in a folder it marks as excluded from backup. It refuses an Instant (whose prints develop as they are saved) and a capture that is not saved.
- `App/Immerse/Sources/DevelopedPreviews.swift`, entirely under `#if DEBUG`:
  - `DevelopedPreviews` holds the switch (`UserDefaults` key `ImmerseDebugDevelopedPreview`, on when absent, `-ImmerseDebugDevelopedPreview NO` for one launch; off in directly constructed Journals, as the Testing unlock is) and the latest capture's preview.
  - On each saved event the capture controller already handles, it renders the Film's newest capture off the main actor at utility priority, then a 240-pixel thumbnail. A newer save cancels and replaces it; a preview that fails shows a note and touches nothing else.
  - Files live only in `Caches/DebugDevelopedPreviews`, which iOS never backs up. They are removed when a preview is closed or replaced, when its Film starts Development (`JournalModel.develop`) or is deleted (`JournalModel.remove`), when the switch is turned off and at every launch. The latest preview stays while the camera is closed and shows again when it opens.
  - Delete Film clears the Film's preview again once the camera has stopped. Stopping it waits for a save it is finishing, and that save's saved event, handled while the deletion waits, started a preview of the Film being deleted, which then outlived it.
  - `DevelopAtOnceNotice` says on the shooting screen that the switch is on, whenever it is, on every Camera it changes and never on the Instant: **Develop at once** with a hammer, read by VoiceOver as "Develop at once is on. Debug build.". It sits in the header's first line beside **Done** (`DoneRowLayout`), off the viewfinder and the shutter bar, and turns with the header in every hold. Beside Done it is shorter than Done, so the header keeps its height and the viewfinder is where it is with the switch off; where the two do not fit on one line, as in the header's shorter lines held on its side on a small iPhone, it goes under Done, which lengthens the turned header across the screen but not its reserved height. Its text is capped at the first accessibility size, as the card's is.
  - `DevelopedPreviewCard` sits in the shooting screen's notice block over the viewfinder, where everything that comes and goes sits, so it never moves the viewfinder and turns with the hold like the other notices. It shows the picture, **Debug preview** and "Photo 2 developed. Tap to view.", with an **x** over its top corner to close it. Its text and picture are capped at the first accessibility size, as the zoom steps are; one custom layout (`PreviewCardLayout`) puts the two lines beside the picture where the heading fits there on one line and below it where it does not, as in the 6×6's viewfinder at the largest sizes on an iPhone SE. Sideways the notice block reads at least 300 points long while it shows. The viewfinder's empty camera glyph hides under it.
  - `DevelopedPreviewSheet` opens it full size: the photo, or the Developed Clip silently on a loop, over **Develop at once - Debug build** and what it means. A clip has no soundtrack, which only the developed Movie gets; the notice says so.
  - `DevelopedPreviewSection` is the Settings switch, **Develop at once - Debug build**, under the Testing unlock's.
- `CaptureController` calls `captureSaved` after its saved event's refresh, under `#if DEBUG`; `JournalModel`, `ImmerseApp`, `CaptureView` and `SettingsView` gain their hooks under `#if DEBUG` too.
- `Scripts/verify-release-excludes-testing-unlock.sh` also requires `DevelopedPreviews`, `PreviewDevelopment`, `ImmerseDebugDevelopedPreview`, "Develop at once", "Debug preview" and the notice's identifier `develop-at-once-notice` in the Debug bundle and their absence from the Release bundle.
- Both generated projects (`App/Immerse/Immerse.xcodeproj`, `Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj`) were regenerated for the new files.

## Why it shows the same thing Development will make

A preview is not a second look.
`PreviewDevelopment` calls the code Development calls (`CaptureDevelopment`), with the seed and treatment version Development gives that capture, the Film's Camera package and Film Stock and, for a clip, its Movie orientation and the white balance recorded with the clip.
`PreviewDevelopmentTests` holds it to that: a photo's preview is byte for byte the developed master, and a clip's decoded frames are the Developed Clip's, compared by a SHA-256 of every visible pixel row of each frame (`frameDigests` in FilmRuntime's tests, which `TreatmentVersionDevelopmentTests` uses too).
The first version compared each frame's `Data.hashValue`, which Foundation takes from a buffer's length and its first 80 bytes only, so those comparisons read the first 20 pixels of each frame; the store snapshot compared files the same way and now compares each file's SHA-256.

## What it leaves alone

- The capture save: the preview starts only after the saved event, which comes after the Trial owner has committed the capture, and nothing the preview does reaches the save, the counts, the Trial or the Film record.
- The roll: captures stay sealed, no Development record is written, the Film stays open, and `PreviewDevelopmentTests` shows a copy of the store taken before any preview develops to the same masters, Developed Clips and Developed Movie as the previewed store.
- Backup, restore, export and source cleanup: no preview is in the Film store, so none of them sees one.
- The Instant: its prints develop and reveal as before, and it never gets a preview.
- Release: none of it is compiled.

FR-04 rules out a viewfinder that previews the developed result for the product.
This Debug-only card is that, by the captain's choice for his own testing, which is why it is on a switch and marked; the manual plan turns it off for every scenario outside P01 to P05.

## Tests and outcomes

Run on 2026-10-21 on this Intel Mac and on new simulators made for this task.

| Scenario | Expected | Observed | Result | Evidence |
| --- | --- | --- | --- | --- |
| Preview is what Development makes, each Camera | Photo previews byte-identical to the developed master, clip previews frame-identical to the Developed Clip, for the Disposable, the 6×6 and 16mm in black and white, the Super 8, and the 6×6 and 16mm in color where the table reader runs | All equal; the color stocks ran (the Mac's Core Image made the table reader) | Pass | `PreviewDevelopmentTests.testEachCamerasPreviewIsItsDevelopmentAndTheRollDevelopsAsIfNeverPreviewed` (`swift test --package-path Packages/FilmRuntime --filter PreviewDevelopmentTests`) |
| Roll stays sealed, final Development unchanged | Store files, Film records and Development records unchanged by previews; the previewed roll develops as a copy never previewed | Unchanged; masters, Developed Clips and Developed Movies equal the copy's | Pass | same test |
| Instant and unsaved capture | No preview, nothing written | Refused, no folder made, the print stays sealed | Pass | `PreviewDevelopmentTests.testAnInstantPrintAndACaptureThatIsNotSavedHaveNoPreview` |
| Switch default and persistence | On in a Debug build, holds across launches; off in directly constructed Journals | As expected | Pass | `DevelopedPreviewsTests.testSwitchStartsOnInADebugBuildAndPersistsAcrossLaunches` |
| Each of the four Cameras through the capture save path | A preview after each save, the newest replacing the one before, the roll sealed, counts and Trial as without previews; Delete Film removes the preview | As expected; the Disposable on the Trial consumed it at the first save, the others on a subscription left it unused | Pass | `DevelopedPreviewsTests.testEach…WhileTheRollStaysSealed` (four tests) |
| Instant unchanged | Print develops and reveals; no preview, no files | As expected | Pass | `DevelopedPreviewsTests.testAnInstantPrintDevelopsAsBeforeAndHasNoPreview` |
| Switch off, and on-then-off mid-roll | Off: no preview work or files; turning it off removes every preview and the next save has none | As expected | Pass | `DevelopedPreviewsTests.testSwitchedOffNoPreviewIsMadeAndTurningItOffMidRollClearsAndStopsThem` |
| Close and develop | Closing removes the file; developing the roll removes its preview and develops every capture | As expected | Pass | `DevelopedPreviewsTests.testClosingThePreviewOrDevelopingTheRollRemovesIt` |
| Forced render failure | The card says it could not develop; the capture stays saved and sealed, "Saved" shows, no alert | As expected (the cache folder's place was taken by a file) | Pass | `DevelopedPreviewsTests.testAFailedPreviewShowsANoteAndTheCaptureStaysSaved` |
| The card and the full-size view | Readable and inside the viewfinder upright and sideways, default and largest text, light and dark, iPhone 17 Pro and iPhone SE (3rd generation) | See [Screens](#screens) | Pass on review | `DevelopedPreviewsTests.testThe…PreviewShowsOverTheViewfinderAndFullSize` (four tests, screenshots kept) |
| Settings switch in the app | On, off and on again hold across relaunches; the launch argument turns it off for one launch and leaves the saved switch | As expected, on an iOS 26.5 iPhone 17 Pro simulator | Pass | `DevelopedPreviewUITests` |
| Settings text sizes | The two new lines grow at every size from XS to AX XXXL and are never clipped, in landscape | As expected, light appearance | Pass | `ContentSizeTests.testLandscapeSettingsTopTextAt…` (12 tests) |
| Settings neighbours | The Testing unlock and Settings flows and audits unchanged | `TestingUnlockUITests` (2) and `JournalFlowTests` passed, the audit's expected failure included | Pass | same run |
| Everything else hosted | No hosted test changes | All 91 hosted tests passed on an iOS 26.2 iPhone 17 Pro simulator; `DevelopedPreviewsTests` passed again on an iPhone SE (3rd generation) | Pass | `ImmerseTests` |
| Packages | Development's refactor changes nothing | `swift test` passed for FilmRuntime (all, none skipped) and RenderCore (118, its one existing skip) | Pass | `swift test --package-path Packages/FilmRuntime`, `Packages/RenderCore` |
| Harness | The harness, which compiles the app's sources, still builds | Built for testing | Pass | `xcodebuild … PopulatedJournalHarness … build-for-testing` |
| Release | None of the preview's names or copy in Release; all of them in Debug | Debug present, Release absent | Pass | `sh Scripts/verify-release-excludes-testing-unlock.sh` |
| Physical iPhone | The captain's look and feel, timing and heat | Not run: no device action is authorized for this task | Untested | P01 to P05 |

## Screens

The four screenshot tests keep each Camera's shooting screen with a preview, upright and held on its side, at the default and the largest text size, in light and dark, and its full-size view in light and dark.
A few of them, from the last run (synthetic test pictures; the simulator has no camera):

- iPhone SE (3rd generation), 6×6 upright at the default size: [light](develop-at-once-076/se-6x6-upright-default-light.png), [dark](develop-at-once-076/se-6x6-upright-default-dark.png); at the largest size, [upright](develop-at-once-076/se-6x6-upright-largest-light.png) and [sideways](develop-at-once-076/se-6x6-sideways-largest-light.png); a 16mm clip [full size](develop-at-once-076/se-16mm-full-size-light.png).
- iPhone 17 Pro: the [Disposable upright, dark](develop-at-once-076/pro-disposable-upright-default-dark.png), the [16mm sideways](develop-at-once-076/pro-16mm-sideways-default-light.png), the [Super 8 upright](develop-at-once-076/pro-super8-upright-default-light.png), a 6×6 photo [full size, dark](develop-at-once-076/pro-6x6-full-size-dark.png) and the [Settings switch](develop-at-once-076/pro-settings-switch-on.png).

Faults found in them and fixed before these results:

- The screen's disappearance cleared the preview, so the camera's own close, and each test window's, lost it. The preview now stays until it is closed, replaced, developed, deleted, switched off or the app relaunches.
- The full-size view waited forever for a preview file that was gone; it now says so.
- At the largest text the picture grew past the card's text cap, and the empty camera glyph showed through under the card.
- On an iPhone SE the 6×6's viewfinder is about 218 points wide, and the card's heading broke as "pre-/view" beside the picture, and at the largest text the card was cut off at the viewfinder's foot. The close button moved over the card's corner and `PreviewCardLayout` moves the lines below the picture where the heading does not fit beside it.
- The Settings switch first read "Develop each capture - Debug build", which wrapped as "Develop each capture -" over "Debug build" at the default size on an iPhone 17 Pro; it is "Develop at once - Debug build", on one line like the Testing unlock's.

## Not proven without a phone

The simulator has no camera, so no real capture has been previewed: the hosted tests feed the real save path with a staged photo or clip, exactly as the backend leaves one.
How long a full-size 6×6 photo or a long 16mm clip takes to develop on an iPhone, whether the camera stays smooth while it does, and the heat it makes are unmeasured; P01 and P05 ask for them.
This Mac is Intel and CI's are Apple silicon; the byte-equality tests compare renders made in the same run, so they hold on either.
