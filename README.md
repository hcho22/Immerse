# Immerse

Immerse is an iPhone camera app that brings back the patience of shooting film.
You load a Film into one of five period Cameras, capture without seeing results, and develop the whole Film to reveal it in a personal Film Journal.
"Immerse" is a working title: the final brand, product name and user-facing terminology are still open (DEC-01).

This README describes the app as it exists on `main` today.
Where the product documents and the code differ, it describes the code and notes the gap.

## What the current build does

### Cameras

The catalog is fixed in code in [`Packages/FilmDomain/Sources/FilmDomain/CameraPackage.swift`](Packages/FilmDomain/Sources/FilmDomain/CameraPackage.swift).

| Camera | Medium | Capacity | Reveal | Controls and look on the Load Film screen |
| --- | --- | --- | --- | --- |
| 1990s Disposable | Photo | 27 exposures | Sealed until the whole Film is developed | Fixed focus, fixed exposure, optional flash and a live low-light cue; borderless 3:2 picture, warm, saturated color, heavy grain, harsh flash and soft edges |
| 1970s Instant | Photo | 10 exposures | One print revealed after each exposure | Square picture on a white card; warm, faded color, soft contrast and soft detail |
| 6×6 Medium Format | Photo | 12 exposures | Sealed until the whole Film is developed | Square framing, a viewfinder that shows the scene reversed left to right, deliberate focus and exposure with optical-only focus; Film Stock chosen at Load Film; borderless square picture; color: natural, warm color, very fine grain and gentle contrast; black and white: high contrast and distinct grain |
| 1960s Super 8 Home Movie | Movie | 3:20 (200 seconds) | One silent Movie after Development | Handheld, fixed focus, automatic exposure, 18 frames per second; muted color, a warm glow, fine grain, an unsteady frame, flicker, dust and hair |
| 16mm Cinema | Movie | 2:47 (167 seconds) | One silent Movie after Development | Deliberate framing, 24 frames per second; Film Stock chosen at Load Film; visible grain, a highlight glow (red on color, neutral on black and white), minor jitter and weave, soft dark edges |

A developed Instant print is a 2048 x 2048 picture on a clean white card (2282 x 2774 in all), in the proportions of the original 1970s integral print.
The card is part of the developed master, so the Journal, the Darkroom and Save Developed to Photos all show it.
Darkroom adjustments (print exposure, contrast, filtration, Dodge/Burn) reach the picture only and leave the card white, and an Instant print has no crop.
Films loaded before a package changes keep the package they locked, so a 16mm Film loaded earlier keeps its old name and 165 seconds.
The 6×6 Medium Format and the 16mm Cinema load on a color or black-and-white Film Stock (ADR 0014), chosen at Load Film and fixed for the Film; Films loaded before Film Stock existed have none and develop in color.
A black-and-white Film develops as its own monochrome treatment, prints and Developed Movie alike, and its prints take chemical toning in the Darkroom ([`Evidence/NativeApp/prd-2-slice-3-film-stock.md`](Evidence/NativeApp/prd-2-slice-3-film-stock.md)).

Each Camera and Film Stock develops with a look of its own, with that Camera's imperfections (treatment version `film-look-4`, [`Evidence/NativeApp/prd-2-slice-4-looks.md`](Evidence/NativeApp/prd-2-slice-4-looks.md)).
The captain approved every Camera's look on a side-by-side review board.
After a study of preserved 1970s prints he chose the Instant's contrast, which is what version 4 changes, and kept its print-to-print variation as it was ([`Evidence/NativeApp/instant-study-and-toning-061.md`](Evidence/NativeApp/instant-study-and-toning-061.md)).
A Film loaded before those looks keeps developing with the earlier treatment version it started with.

Gap: this table is the build, and it differs from the text of PRD version 2.1 where the captain chose otherwise on a review board ([ADR 0016](2026-09-29-film-camera-experience-v1/adr/0016-the-captains-exceptions-to-fresh-not-aged.md)).
The Instant develops faded where the PRD has "brilliant, warm, saturated color", the Super 8 muted with a glow where it has "strong, rich color", and the color Film Stocks of the 16mm and the 6×6 develop with the looks in his own files, which give the 6×6 a mild lens vignette the PRD does not list.
All four of the tracker's "PRD 2.0 implementation slices" are built, as the table shows, and none is validated on a physical iPhone; developed exposures are never reversed.
The Disposable's fixed exposure (EV 12), its low-light cue threshold and the fixed lens position are provisional pending DEC-04 and a physical-phone check ([`Evidence/NativeApp/capture-behavior-prd2-slice2.md`](Evidence/NativeApp/capture-behavior-prd2-slice2.md)).
Flash, manual focus and exposure appear only when the lens supports them, and the capture screen says when a lens cannot hold the Disposable's fixed exposure.
Movie capacity is counted in whole 30 fps frames, and Movie clips are always silent: the app never requests the microphone.
Movie capture uses a 4:3 native format that is provisional pending DEC-04.

### Film lifecycle

All screens live in [`App/Immerse/Sources`](App/Immerse/Sources).

- **Load.** Start a Film from the Journal, pick a Camera, name the Film, on the 6×6 and the 16mm choose Color or Black and white, and for Movie Cameras choose Portrait or Landscape.
  The Camera, Film Stock and Movie orientation cannot change after loading.
  The Camera permission is requested here and in Open Camera, not at launch.
- **Capture.** Open Camera shows a live viewfinder, remaining exposures or M:SS time, and a shutter that saves each capture privately inside the app.
  Saves that were interrupted are recovered at launch or resumed with Resume Save.
- **Early completion.** Disposable, 6×6 and Movie Films can be completed early ("Rewind & Develop Early" or "Stop & Develop Early") once they have at least one saved capture; unused capacity is permanently wasted.
  Instant Films have no early completion because each print develops on its own.
- **Development.** A full or early-completed Film is developed once.
  Before Development you choose whether original captures are saved to Photos after the reveal or removed after verified Development.
  Photo Films reveal every print; Movie Films assemble their clips, in order, into one silent Movie with a player in the Film screen.
- **Journal.** The Journal groups Films as On the roll, Ready to develop, Developing, Pack complete and Developed, with progress and up to three revealed thumbnails per photo Film.
  Films can be renamed and moved to and from the Archive.
- **Darkroom.** Revealed photos open in a Darkroom with exposure, contrast grades 0 to 5, color filtration, crop and point-based dodge and burn, saved as reversible edits with Reset to Original.
  Its limits are the captain's of 2026-10-13: print exposure and Dodge and Burn each run to 3 stops either way, and filtration to 30 ([`Evidence/NativeApp/darkroom-export-decisions-060.md`](Evidence/NativeApp/darkroom-export-decisions-060.md)).
  Every Photo Film gets the contrast grades, Instant prints included, but an Instant print has no crop, so its square picture and white card stay whole.
  Black-and-white 6×6 prints are silver gelatin: they take chemical toning (sepia or selenium) and no color filtration, which stays for color prints.
- **Discard.** A single photo or Movie clip can be discarded after reveal, with no refund of exposures or time.
  Discarding a clip rebuilds the Movie from the surviving clips without redevelopment (ADR 0007); a Movie whose clips are all discarded keeps numbered placeholders with no playback or export (DEC-09).
- **Photos export.** "Save Developed to Photos" and "Originals" use add-only Photos access, requested only when you export.
  Photos are saved as sRGB JPEG, the Disposable at no more than 12,000,000 pixels in 3:2, the 6×6 at 3072 × 3072 and an Instant print exactly as developed, 2282 × 2774; Movies as H.264 in a `.mov` at 1920 × 1440, or 1440 × 1920 for a portrait Movie, at 18 or 24 frames a second, silent (the captain, 2026-10-13).
  An Instant asks about the original of each print after it is revealed.
  Exports are flattened results, cannot be recalled by the app, and stay in Photos after a Film is deleted.
- **Delete.** Delete Film removes the Film, its captures and edits from app storage.
  The confirmation discloses that Photos exports remain and that restoring an older iOS backup can bring the Film back (DEC-17).

Films are stored on the iPhone under the app's `Application Support/FilmJournal` in SQLite plus media files, and are included in iOS device backups.
There is no sync or app-managed backup.

### Trial and subscription

- **Trial.** Each iPhone gets one Trial Film with any Camera ([ADR 0012](2026-09-29-film-camera-experience-v1/adr/0012-v1-trial-is-one-film-per-iphone-with-no-accounts.md)).
  The first successfully saved capture consumes it, and the Trial record is kept in the Keychain so deleting the Film or the app does not restore it.
  The single decision point is `TrialCoordinator.load` in [`Packages/FilmRuntime`](Packages/FilmRuntime).
- **Subscription.** The app has a StoreKit 2 monthly and yearly subscription flow with purchase, restore and verified updates in [`Packages/EntitlementCore`](Packages/EntitlementCore).
  Production product IDs are deliberately absent from the build, so the Subscription screen shows "Subscriptions are not available in this build."
  Only the test target's synthetic `.storekit` file exercises purchases.
- **Expiry.** Existing Films stay capturable, developable, editable, viewable and exportable after a subscription lapses (ADR 0006).

### What is provisional

These are reversible engineering defaults in the code, not approved decisions:

- **Render output.** Export sizes and formats and the Darkroom's ranges are no longer provisional: the captain approved them on 2026-10-13.
  Nor are the Instant's contrast and print-to-print variation or the toning range, which he decided the same day ([`Evidence/NativeApp/instant-study-and-toning-061.md`](Evidence/NativeApp/instant-study-and-toning-061.md)).
  The looks themselves are no longer provisional (see Cameras above); the earlier versions, `film-look-1-provisional` and `film-look-2-provisional`, stay renderable unchanged for Films that started with them.
- **Assets.** [`App/Immerse/Sources/Resources/MediaCatalog.json`](App/Immerse/Sources/Resources/MediaCatalog.json) is empty, so the build shows no Camera samples and no built-in soundtracks (the Soundtrack picker stays hidden).
  By the captain's decision of 2026-10-13 (DEC-05) it stays empty until he supplies his own sample shots, one for each Camera and Film Stock, and until a license allows a soundtrack inside exported Movies.
  Draft review material is in [`Evidence/AssetReview`](Evidence/AssetReview/README.md) and is not production clearance.
- **Pricing.** No prices or live product IDs exist pending DEC-02.
- **Lapsed subscribers.** A lapsed subscriber who never used the Trial is currently granted it, a provisional default for PRD open question 7.
- **Native stack.** SwiftUI, raw SQLite and the local package boundaries follow the architecture baseline defaults; DEC-03 sign-off is still open.

## Scope

- iPhone only, iOS 26.0 or later (`TARGETED_DEVICE_FAMILY: 1`, deployment target 26.0).
- Personal Films only.
- No server, Accounts, sign-in or analytics.
  Permissions are Camera and Photos add-only; the app never requests the microphone, location or photo-library reading.
- Groups and Accounts are deferred to v2 and kept in PRD sections 8 and 8.13 and the tracker's Deferred to v2 section.

## Getting started

### Requirements

- macOS with Xcode 26.5 (the version used locally, build 17F42, and in CI).
- An iOS 26 simulator runtime; CI uses an iPhone 17 Pro on iOS 26.5, plus iOS 26.2 for local StoreKit tests.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.43 or later, only if you change `project.yml`.

### Open and run in the simulator

The Xcode project [`App/Immerse/Immerse.xcodeproj`](App/Immerse/Immerse.xcodeproj) is committed, so you can open it directly.
It is generated from [`App/Immerse/project.yml`](App/Immerse/project.yml); after changing targets, packages or build settings there, regenerate it from the repository root and commit both:

```sh
xcodegen generate --spec App/Immerse/project.yml
```

In Xcode, choose the **Immerse** scheme and an iPhone simulator, then Run.
All dependencies are local Swift packages, so no package resolution against the network is needed.
To build from the command line:

```sh
xcodebuild -project App/Immerse/Immerse.xcodeproj -scheme Immerse \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/Simulator build
```

The simulator shows the real Camera permission request.
An unsigned simulator build may fail Keychain queries, so the Trial can report "Trial status unavailable"; leave the Debug testing unlock on to load Films there.

### Run on a physical iPhone

The app target's signing team (`QH9S83CX4Y`) is committed in `project.yml`, so a team picked in Xcode survives regeneration.
To install, sign in to that team in Xcode, turn on Developer Mode on the iPhone (Settings > Privacy & Security > Developer Mode), select the device and Run with the Debug configuration.
Product IDs and production assets are not configured, so plans and samples look the same as in the simulator, while capture and the Keychain Trial record are real.
[`Evidence/NativeApp/manual-validation.md`](Evidence/NativeApp/manual-validation.md) holds the step-by-step physical validation plan and names the commit to test.

### Debug testing unlock

Debug builds include a testing unlock ([`App/Immerse/Sources/TestingUnlock.swift`](App/Immerse/Sources/TestingUnlock.swift)) that is on by default.
While on, every Camera loads as a subscription Film without reading or writing the iPhone's Trial record or touching StoreKit, and the Load Film and Subscription screens show "Testing unlock - Debug build".
Turn it off in **Settings > Debug testing** to check the Trial and plan screens; the choice persists on the device, and UI tests pass `-ImmerseDebugTestingUnlock NO` to get the shipping gate.
The code is compiled only under `#if DEBUG`, and [`Scripts/verify-release-excludes-testing-unlock.sh`](Scripts/verify-release-excludes-testing-unlock.sh) fails if the Release binary contains it.

See [`App/Immerse/README.md`](App/Immerse/README.md) for product configuration, StoreKit fixtures, Keychain behavior and limits in detail.

## Testing

From the repository root:

```sh
sh Scripts/validate-local.sh
```

This runs the scripts' own tests, the requirement-map check, every package's `swift test`, the Trial commit and Development process-exit probes, the documents ZIP comparison, unsigned simulator and device builds, and the Release check for the testing unlock.

Set simulator IDs to add the UI and StoreKit suites:

```sh
IMMERSE_SIMULATOR_UDID=<ios26.5-sim-udid> \
IMMERSE_STOREKIT_SIMULATOR_UDID=<ios26.2-sim-udid> \
IMMERSE_WORKFLOW_SIMULATOR_UDID=<ios26.5-sim-udid> \
sh Scripts/validate-local.sh
```

- `IMMERSE_SIMULATOR_UDID` reruns the `RenderCore` tests inside the simulator (all but `LegacyLookTests`), since Core Image differs between a Mac and iOS, runs `ImmerseUITests` in light appearance and large text, then reruns the `JournalFlowTests` accessibility audits and `MovieCapacityUITests` in dark appearance.
- `IMMERSE_STOREKIT_SIMULATOR_UDID` runs the hosted `ImmerseTests`, including local StoreKit tests, on iOS 26.2, because the StoreKit fixture does not activate on iOS 26.5.
- `IMMERSE_WORKFLOW_SIMULATOR_UDID` runs the populated Journal harness in [`Probes/PopulatedJournalHarness`](Probes/PopulatedJournalHarness/README.md).

Use simulators you own for the run, never a physical-device ID.
For dark-mode coverage beyond the audits, and for small-screen checks on an iPhone SE (3rd generation) simulator, see the notes in [`AGENTS.md`](AGENTS.md) and [`Evidence/NativeApp/visual-sweep-048.md`](Evidence/NativeApp/visual-sweep-048.md).
A single package can be tested on its own, for example `swift test --package-path Packages/FilmRuntime`.

CI ([`.github/workflows/native.yml`](.github/workflows/native.yml)) runs the same script on `macos-26` with Xcode 26.5 for every pull request and push to `main`, creating its own iOS 26.5 and iOS 26.2 simulators and keeping the `.xcresult` bundles as artifacts.
It runs the script as four parts side by side, chosen with `IMMERSE_VALIDATE_PART` (`packages`, `harness`, `ui-text`, `ui-flows`), each with a 75-minute limit, and one summary check, `local-native`, is green only when every part is.
A pull request that changes only Markdown runs the `packages` part alone.
A failed screen test is run once more only when the simulator's own log shows it dropped that test's touch, and a run that passed that way says so ([`Evidence/NativeApp/dropped-touch-059.md`](Evidence/NativeApp/dropped-touch-059.md)).
The scripts have their own tests: `python3 -m unittest discover -s Scripts/Tests`.

## Repository layout

| Path | Contents |
| --- | --- |
| [`App/Immerse`](App/Immerse/README.md) | The iOS app: SwiftUI sources, unit and UI tests, `project.yml` and the generated Xcode project |
| [`Packages`](Packages) | Local Swift packages the app is built from (below) |
| [`Probes`](Probes) | Non-shipping probes and harnesses for Trial, receipt, export, accessibility and populated-Journal scenarios, the look review boards and the captain's look calibration files, each with its own README |
| [`Evidence`](Evidence) | Dated test results, diagnoses and validation handoffs that back each requirement |
| [`Scripts`](Scripts) | Local validation and document, requirement-map and Release checks |
| [`2026-09-29-film-camera-experience-v1`](2026-09-29-film-camera-experience-v1/README.md) | The v1 product package: PRD, ADRs, architecture, task tracker, evidence map and open-decision recommendations |
| `2026-09-29-film-camera-experience-v1-documents.zip` | A ZIP of that package, kept in step with the directory |
| [`2026-09-29-nostalgic-camera-app-market-research-hipstamatic.md`](2026-09-29-nostalgic-camera-app-market-research-hipstamatic.md) | Market research behind the product |
| [`AGENTS.md`](AGENTS.md) | Build, test and sharp-edge notes for contributors and coding agents |

Packages:

| Package | Role |
| --- | --- |
| [`FilmDomain`](Packages/FilmDomain) | Camera catalog, Film and capture model, capacity and state rules |
| [`FilmPersistence`](Packages/FilmPersistence) | SQLite repository, stored media, verification and file-presence helpers |
| [`FilmRuntime`](Packages/FilmRuntime/README.md) | `TrialCoordinator` and `FilmProcessor`: capture commits, Development, Darkroom, Photos export and removal |
| [`RenderCore`](Packages/RenderCore) | Native photo and Movie rendering, Darkroom recipes and Movie assembly |
| [`NativeAdapters`](Packages/NativeAdapters/README.md) | AVFoundation capture backend, permissions and PhotoKit export |
| [`EntitlementCore`](Packages/EntitlementCore) | Keychain device Trial record, StoreKit subscriptions and entitlement state |
| [`MediaCatalog`](Packages/MediaCatalog/README.md) | Reader for the bundled, rights-verified sample and soundtrack manifest |
| [`RenderFixtures`](Packages/RenderFixtures) | Synthetic DEC-04 discovery fixtures; not used by the app |

## Status and open decisions

**Done in software.** The full personal v1 flow above is implemented, with package, hosted and simulator UI tests passing in CI on `main`.
Implementation progress is traced in the [evidence map](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-evidence-map.md) and [acceptance companion](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-acceptance-evidence.md); the [task tracker](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-task-tracker.md) keeps its 135 v1 tasks unchecked until acceptance, so its checkboxes do not show code progress.

**Needs a physical iPhone.** Real capture, Keychain Trial behavior across reinstall, Photos writes, power loss, backup and restore, iPhone 11 performance and assistive-technology accessibility have not been validated on hardware.
The plan is in [`Evidence/NativeApp/manual-validation.md`](Evidence/NativeApp/manual-validation.md) and the release handoff in [`Evidence/NativeApp/launch-readiness.md`](Evidence/NativeApp/launch-readiness.md); the build is not release-ready.

**Open captain decisions.** Each of these has something still open; the [open-decision recommendations](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-open-decision-recommendations.md) propose options for several of them.

- DEC-01: final brand, product name and copy.
- DEC-02: monthly and yearly pricing and offers.
- DEC-03: sign-off of the native stack (minimum iOS 26, iPhone only and no backend are settled).
- DEC-04: the Movie capture's native 4:3 format size, still provisional (decided: each Camera's Format Reference, picture shape, look, imperfections and frame rates in PRD 2.0, each look's tone, contrast and grain on the review boards, and on 2026-10-13 the export sizes and formats, the Instant's contrast and print-to-print variation and the toning range).
- DEC-05: the captain's own sample shots, one for each Camera and Film Stock (the rule is decided: only material he owns or has written rights to, and no built-in soundtrack until a license allows it inside exported Movies).
- DEC-12: measuring the speed and storage targets approved on 2026-10-13 (iPhone 11 as the oldest phone), and the rows of the recommendation he was not asked about.
- DEC-13: the support and App Store wording (its approach is approved).
- DEC-14: the learning targets themselves (no analytics, and learning from TestFlight interviews, tester feedback and Apple's reports, is decided).

DEC-09, DEC-11 (since 2026-10-13) and DEC-15 to DEC-17 are decided and recorded in the tracker and PRD section 15.

## Further reading

- [PRD, version 2.1](2026-09-29-film-camera-experience-v1/2026-10-06-film-camera-experience-v1-prd-version-2.0.md) (version 1.5 is kept [beside it](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-prd.md))
- [Domain glossary](2026-09-29-film-camera-experience-v1/sources/CONTEXT.md)
- [Architecture baseline](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-architecture.md)
- [ADR collection](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-adrs.md) and [individual ADRs](2026-09-29-film-camera-experience-v1/adr)
- [Task tracker](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-task-tracker.md)
- [Native app candidate evidence](Evidence/NativeApp/2026-10-01-native-candidate.md)
- [App README](App/Immerse/README.md) and [AGENTS.md](AGENTS.md)
