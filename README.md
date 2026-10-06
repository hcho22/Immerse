# Immerse

Immerse is an iPhone camera app that brings back the patience of shooting film.
You load a Film into one of five period Cameras, capture without seeing results, and develop the whole Film to reveal it in a personal Film Journal.
"Immerse" is a working title: the final brand, product name and user-facing terminology are still open (DEC-01).

This README describes the app as it exists on `main` today.
Where the product documents and the code differ, it describes the code and notes the gap.

## What the current build does

### Cameras

The catalog is fixed in code in [`Packages/FilmDomain/Sources/FilmDomain/CameraPackage.swift`](Packages/FilmDomain/Sources/FilmDomain/CameraPackage.swift).

| Camera | Medium | Capacity | Reveal | Controls in the capture screen |
| --- | --- | --- | --- | --- |
| 1990s Disposable | Photo | 27 exposures | Sealed until the whole Film is developed | Fixed focus, optional flash |
| 1970s Instant | Photo | 10 exposures | One print revealed after each exposure | Square framing |
| 1960s 6x6 Medium Format | Photo | 12 exposures | Sealed until the whole Film is developed | Square framing, manual focus and exposure sliders |
| 1960s Super 8 Home Movie | Movie | 3:20 (200 seconds) | One silent Movie after Development | Handheld look, grain and flicker |
| 1960s 16mm Cinema | Movie | 2:45 (165 seconds) | One silent Movie after Development | Finer grain |

Flash, manual focus and exposure appear only when the lens supports them.
Movie capacity is counted in whole 30 fps frames, and Movie clips are always silent: the app never requests the microphone.
Movie capture uses a 4:3 native format that is provisional pending DEC-04.

### Film lifecycle

All screens live in [`App/Immerse/Sources`](App/Immerse/Sources).

- **Load.** Start a Film from the Journal, pick a Camera, name the Film, and for Movie Cameras choose Portrait or Landscape.
  The Camera and Movie orientation cannot change after loading.
  The Camera permission is requested here and in Open Camera, not at launch.
- **Capture.** Open Camera shows a live viewfinder, remaining exposures or M:SS time, and a shutter that saves each capture privately inside the app.
  Saves that were interrupted are recovered at launch or resumed with Resume Save.
- **Early completion.** Disposable, 6x6 and Movie Films can be completed early ("Rewind & Develop Early" or "Stop & Develop Early") once they have at least one saved capture; unused capacity is permanently wasted.
  Instant Films have no early completion because each print develops on its own.
- **Development.** A full or early-completed Film is developed once.
  Before Development you choose whether original captures are saved to Photos after the reveal or removed after verified Development.
  Photo Films reveal every print; Movie Films assemble their clips, in order, into one silent Movie with a player in the Film screen.
- **Journal.** The Journal groups Films as On the roll, Ready to develop, Developing, Pack complete and Developed, with progress and up to three revealed thumbnails per photo Film.
  Films can be renamed and moved to and from the Archive.
- **Darkroom.** Revealed photos open in a Darkroom with exposure, contrast, color filtration, crop and point-based dodge and burn, saved as reversible edits with Reset to Original.
  Chemical toning exists in code but only for a silver-gelatin print process; every current Camera uses the provisional color process, so toning is not offered today.
- **Discard.** A single photo or Movie clip can be discarded after reveal, with no refund of exposures or time.
  Discarding a clip rebuilds the Movie from the surviving clips without redevelopment (ADR 0007); a Movie whose clips are all discarded keeps numbered placeholders with no playback or export (DEC-09).
- **Photos export.** "Save Developed to Photos" and "Originals" use add-only Photos access, requested only when you export.
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

- **Render presets.** Development and Darkroom output use a versioned `film-look-1-provisional` treatment pending DEC-04 and DEC-11.
- **Assets.** [`App/Immerse/Sources/Resources/MediaCatalog.json`](App/Immerse/Sources/Resources/MediaCatalog.json) is empty pending DEC-05, so the build shows no Camera samples and no built-in soundtracks (the Soundtrack picker stays hidden).
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
[`Evidence/NativeApp/manual-validation.md`](Evidence/NativeApp/manual-validation.md) holds the step-by-step physical validation plan; its note that signing is not configured predates the committed team.

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

This runs the requirement-map check, every package's `swift test`, the Trial commit and Development process-exit probes, the documents ZIP comparison, unsigned simulator and device builds, and the Release check for the testing unlock.

Set simulator IDs to add the UI and StoreKit suites:

```sh
IMMERSE_SIMULATOR_UDID=<ios26.5-sim-udid> \
IMMERSE_STOREKIT_SIMULATOR_UDID=<ios26.2-sim-udid> \
IMMERSE_WORKFLOW_SIMULATOR_UDID=<ios26.5-sim-udid> \
sh Scripts/validate-local.sh
```

- `IMMERSE_SIMULATOR_UDID` runs `ImmerseUITests` in light appearance and large text, then reruns the `JournalFlowTests` accessibility audits and `MovieCapacityUITests` in dark appearance.
- `IMMERSE_STOREKIT_SIMULATOR_UDID` runs the hosted `ImmerseTests`, including local StoreKit tests, on iOS 26.2, because the StoreKit fixture does not activate on iOS 26.5.
- `IMMERSE_WORKFLOW_SIMULATOR_UDID` runs the populated Journal harness in [`Probes/PopulatedJournalHarness`](Probes/PopulatedJournalHarness/README.md).

Use simulators you own for the run, never a physical-device ID.
For dark-mode coverage beyond the audits, and for small-screen checks on an iPhone SE (3rd generation) simulator, see the notes in [`AGENTS.md`](AGENTS.md) and [`Evidence/NativeApp/visual-sweep-048.md`](Evidence/NativeApp/visual-sweep-048.md).
A single package can be tested on its own, for example `swift test --package-path Packages/FilmRuntime`.

CI ([`.github/workflows/native.yml`](.github/workflows/native.yml)) runs the same script on `macos-26` with Xcode 26.5 for every pull request and push to `main`, creating its own iOS 26.5 and iOS 26.2 simulators and keeping the `.xcresult` bundles as artifacts.

## Repository layout

| Path | Contents |
| --- | --- |
| [`App/Immerse`](App/Immerse/README.md) | The iOS app: SwiftUI sources, unit and UI tests, `project.yml` and the generated Xcode project |
| [`Packages`](Packages) | Local Swift packages the app is built from (below) |
| [`Probes`](Probes) | Non-shipping probes and harnesses for Trial, receipt, export, accessibility and populated-Journal scenarios, each with its own README |
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
Implementation progress is traced in the [evidence map](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-evidence-map.md) and [acceptance companion](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-acceptance-evidence.md); the [task tracker](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-task-tracker.md) keeps its 121 v1 tasks unchecked until acceptance, so its checkboxes do not show code progress.

**Needs a physical iPhone.** Real capture, Keychain Trial behavior across reinstall, Photos writes, power loss, backup and restore, iPhone 11 performance and assistive-technology accessibility have not been validated on hardware.
The plan is in [`Evidence/NativeApp/manual-validation.md`](Evidence/NativeApp/manual-validation.md) and the release handoff in [`Evidence/NativeApp/launch-readiness.md`](Evidence/NativeApp/launch-readiness.md); the build is not release-ready.

**Open captain decisions.** None of these is decided; the [open-decision recommendations](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-open-decision-recommendations.md) propose options for several of them.

- DEC-01: final brand, product name and copy.
- DEC-02: monthly and yearly pricing and offers.
- DEC-03: sign-off of the native stack (minimum iOS 26, iPhone only and no backend are settled).
- DEC-04: each Camera's rendering, output specs and controls.
- DEC-05: production sample media and licensed soundtracks.
- DEC-11: Darkroom ranges, Instant original-export timing and soundtrack reselection.
- DEC-12: storage, device, accessibility and reliability budgets.
- DEC-13: support, privacy disclosures and launch review.
- DEC-14: numeric learning targets (no analytics is settled).

DEC-09 and DEC-15 to DEC-17 are decided and recorded in the tracker and PRD section 15.

## Further reading

- [PRD](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-prd.md)
- [Architecture baseline](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-architecture.md)
- [ADR collection](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-adrs.md) and [individual ADRs](2026-09-29-film-camera-experience-v1/adr)
- [Task tracker](2026-09-29-film-camera-experience-v1/2026-09-29-film-camera-experience-v1-task-tracker.md)
- [Native app candidate evidence](Evidence/NativeApp/2026-10-01-native-candidate.md)
- [App README](App/Immerse/README.md) and [AGENTS.md](AGENTS.md)
