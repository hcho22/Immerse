# Configurable Media and Native Workflow Candidate

This is an unaccepted continuation of `67bf395` on `fm/immerse-v1-implementation`,
not completion of full v1. The commit containing this report identifies the source;
execution below used that dirty candidate on Xcode 26.5/macOS 26.6.2. Production
rights, render decisions, prices, hardware and the Trial cross-store conflict remain
open. No phone, Apple account, production purchase, publication or server is used.
`media-workflows-source.sha256` identifies source/config/test files, including the
unchanged bounded accessibility probe. The source hash inventory is not a test.

## Implementation and Requirements

| Requirement | Implementation and meaningful verification | Outcome / limit |
| --- | --- | --- |
| CAM-10 / DEC-05 / FR-01 browsing without Trial use | `MediaCatalog` verifies local manifest schema, Camera compatibility, media/license SHA-256, retained rights metadata and paths; `CameraSamplesView` decodes real photo or silent Movie before display. Browsing invokes no Film/Trial/capture/export method. | Four package tests pass. Production rejects test-only assets; malformed paths, changed bytes and missing export rights fail. Native sample browsing with approved media remains untested because no media is cleared. |
| MOV-09 / MOV-11 / DEC-11 / FR-05 | `FilmProcessor.selectSoundtrack`, `FilmRepository.selectMovieSoundtrack`, `SoundtrackView` select only verified built-in instrumentals or silence. Nil policy exposes no choice. Audio and license bytes plus metadata are retained with the Film; old assembled Movies retire in the same selection transaction. | Three native-media runtime tests pass, including real PCM and Movie decoding, export orchestration, locked/unresolved policy and corrupt audio rejection. Actual PhotoKit and licensed content are not proved. |
| PRV-08 / FR-16 A03,A04,A08 / invariant: no reroll or resurrection | Audio revision participates in assembly commit validation. Reopen and Discard use retained audio and Developed Clips, not a bundle dependency or new treatment. | Tests remove the fixture bundle, Discard, decode the shorter audio Movie, compare survivor clip bytes and assignments, reject old-revision write, then retain two empty numbered placeholders and delete all Film media. Source capture audio remains forbidden. |
| DRK-01...06,08 / FR-07 / DEC-04,11 | `DarkroomRecipe.chemicalToning`, frozen `DevelopmentRun.printProcess`, native sepia/selenium response, applicability checks and conditional controls. Preview, save and export consult the saved process; old runs/recipes decode as unchanged color originals. | Two decoded-pixel tests pass: only explicit silver-gelatin process admits toning; color filtration is rejected there; invalid/nonfinite ranges fail; Reset is byte-exact. No current Camera is assigned silver gelatin. Stock applicability/quality/ranges are still decisions, not approved by these tests. |
| FR-03,04,06,07,16,17,18 / QA-03,04,11,13 | Separate `Probes/PopulatedJournalHarness` compiles production views/model/modules and seeds private synthetic existing Films. UI paths cover early waste, Development, photo Darkroom/Reset/Discard, rename/archive/delete, Instant and last-Movie-clip placeholders. | Build-for-testing passed. Runtime outcomes below retain failed selectors and the actual source-choice bug. This harness is not capture, Trial, backup or accessibility acceptance. Production app has no fixture switch. |
| STO-05,07,08 / FR-06,08 | Completed roll records original disposition before beginning Development, while open rolls still reject the choice; source access and cleanup require reveal and independently verified masters/receipts. Early-completed Film UI reports wasted capacity and full progress, without changing actual saved debits. | Focused SourceCleanup regression failed before correction with `mediaNotRevealed`, then all five cleanup tests passed. Native app-model scenario now chooses before Development and verifies source removal only after real successful render. |
| TRI-04 / ARC-11 / QA-12 / FR-21 | Actual coordinator/repository counterexamples, restored-pending cases and isolated `Probes/TrialCommitStudy`; see `../TrialKeychainProbe/2026-10-01-receipt-study.md`. | Seven production-path Trial tests include the **known failing D3 invariant**. Eleven separate study tests exercise real SQLite/native media, 30 abrupt exits and injected receipt stores. Production correction/native adapter conditions and physical guarantees remain unaccepted. |
| QA-13 native accessibility | `Probes/SetupAccessibilityProbe`, retained `setup-probe/` metrics/trees/PNGs and `accessibility-diagnosis.md` follow-up. | Default, launch-forced largest and system-selected largest all fail. No filters, caps or exceptions. The failure does not stop independent software work. |

## Execution

```sh
swift test --package-path Packages/MediaCatalog
swift test --package-path Packages/FilmPersistence
swift test --package-path Packages/FilmRuntime --filter SoundtrackTests
swift test --package-path Packages/RenderCore --filter ChemicalToningTests
xcodegen generate --spec App/Immerse/project.yml
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/Immerse CODE_SIGNING_ALLOWED=NO build
xcodegen generate --spec Probes/PopulatedJournalHarness/project.yml
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/PopulatedJournalHarness CODE_SIGNING_ALLOWED=NO build-for-testing
```

Observed October 1, 2026 PDT: MediaCatalog 4/4, FilmPersistence 23/23 (05:56),
SoundtrackTests 3/3 (06:00), ChemicalToningTests 2/2 (06:06), unsigned app simulator
build before toning changes and harness build after toning changes passed. Initial
test compilation errors (incorrect XCUI query/type references and an over-complex
Swift type-check expression) were corrected; they are not runtime passes. A full
post-change package/device build remains required. No hardware timing inference
comes from these native host tests or simulator runs.

Subsequent execution: `sh Scripts/validate-local.sh` passed all **100** package
tests and both unsigned app builds at 06:18-06:22 PDT. Earlier attempts failed from
local stale SPM dependency/build products: CapturePipeline lacked a resolved
MediaCatalog module, then FilmRuntime tests linked the old DarkroomRecipe initializer.
`swift package --package-path Packages/CapturePipeline clean` and the equivalent
FilmRuntime command rebuilt those package-local products; no manifest workaround
or global cache deletion was used. Retained successful gate log:
`media-workflows/Validation-media-workflows-3.log`. The final ID-only confirmation
changes postdate that build and require the final build gate below.

`SoundtrackTests` was repeated at 06:23 PDT, **3/3 passed**, with exact synthetic
source/audio/license SHA-256, generator metadata, Film IDs and treatment assignments
in `media-workflows/Soundtrack-identified.log`. The three fixture records correspond
to the tests in logged execution order. Their 160x96 silent source clips decode to
0.168333 seconds at 17.821783 nominal fps; the generated 440 Hz PCM test tone is
not a licensed production asset. These deliberately small fixtures prove native
behavior and recovery, not production fidelity or performance.

Native app model/local StoreKit: `DerivedData/StoreKit-MediaWorkflows.xcresult`,
**6 passed / 0 failed / 0 skipped**, iPhone 17 Pro simulator iOS 26.2 (23C54),
finished 06:24 PDT. Exact command:

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=A5825795-2E74-49C8-BC64-A5CDCB27AF8B' -derivedDataPath DerivedData/ValidationSimulator -resultBundlePath DerivedData/StoreKit-MediaWorkflows.xcresult -only-testing:ImmerseTests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 CODE_SIGNING_ALLOWED=NO test
```

Populated UI histories on iOS 26.5 (23F77), same owned simulator named in the
harness README: first full run 2/3 passed (Movie/Instant); photo selector was
ambiguous. The second photo run reached the actual original-choice repository
error. `SourceCleanupTests` reproduces that error before the correction and rejects
sealed access/cleanup after it; red and green logs are retained. The third full run
again had 2/3 pass but a collection query still matched both Develop Film buttons.
A stable confirmation identifier resolved the ambiguity: photo run 4 reached
Development, exposure adjustment, Reset and Save, then tapped the covered Discard
toolbar instead of its confirmation. Its tree confirms the Film still had both
photos. Destructive confirmation identifiers now make that distinction explicit.
No result from those incomplete photo runs is a full workflow pass. Final populated
and accessibility outcomes are recorded separately below when execution finishes.

### Later Workflow Results

The next full local gate passed **101 package tests and both unsigned builds** at
06:31-06:34 PDT (`media-workflows/Validation-media-workflows-final.log`): Domain 13,
MediaCatalog 4, RenderFixtures 2, RenderCore 11, Persistence 24, NativeAdapters 18,
CapturePipeline 6, EntitlementCore 6, Runtime 17. The subsequent Journal route/row
changes still require their final unsigned build below; this older gate is retained.

Populated run 5 failed because SwiftUI exposed the same confirmation identifier on
parent and child. The test now scopes the first match to the presented sheet. Photo
run 6's activities unexpectedly contained an older removed selector; its result is
retained without claiming a proved cache cause. A fresh build directory ran current
selectors: run 7 passed Movie/Instant and reached a real Archive navigation failure.
Archive used a view-based destination while Films used a value-based path, leaving
Archive above the selected Film. A common typed route fixed opening archived Films.
The extended run 8 then caught a stale Journal row after restoring from Archive:
the heading reflected Development but the row showed the original title/capacity.
Rows now observe current Film state by ID, like the detail view.

Run 9 passed **3/3, zero skipped**, 06:45 PDT, iPhone 17 Pro iOS 26.5 (23F77):
photo early waste/Development/Darkroom exposure/Reset/Save/Discard/rename/Archive/
restore/reopen/rearchive/Delete Film; Instant reveal without roll Development;
Movie Discard to two numbered empty placeholders without playback/export/Darkroom.
`media-workflows/populated-7`, `populated-8` and `populated-9` retain failure/pass
summaries, relevant trees and screenshots. The Movie screenshot contains decoded
synthetic imagery with opposite-orientation borders; after final Discard, the
player/export disappears while capacity remains spent. This is native simulator
view behavior, not camera capture, final render quality or physical performance.

```sh
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath DerivedData/PopulatedJournalFresh -resultBundlePath DerivedData/PopulatedJournal-CurrentRows-9.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

Actual-app dark-mode all-category accessibility run finished 06:37 PDT: **0 passed,
2 failed**, Dynamic Type on the default flow and contrast on largest-type flow.
Summary: `media-workflows/accessibility-dark/summary.json`. The audit handler still
returns false for every finding. No rule filter, font cap, expected failure or
exception was added. Light-mode repetition finished 06:49 PDT with the same
**0 passed / 2 failed / 0 skipped** result and issue categories. Both directories
retain screenshots, pre-audit trees, issue nodes and summaries. The current
candidate's default flow is therefore failed too; earlier default passes do not
generalize. Exact app command (use each unique result path and the corresponding
`xcrun simctl ui <UDID> appearance dark|light` before launch):

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath DerivedData/ValidationSimulator -resultBundlePath DerivedData/Accessibility-MediaWorkflows-Light.xcresult -only-testing:ImmerseUITests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

## Configuration, Recovery and Judgment

Final combined gate: `sh Scripts/validate-local.sh` finished successfully at
06:51 PDT with **101 module tests plus 11 isolated receipt-study tests**, complete
122-ID/72-clause/nine-invariant map coverage, matching 25-entry document ZIP, and
both unsigned simulator/device builds. Log:
`media-workflows/Validation-media-receipt-final.log`. No simulator environment
variables were supplied to that invocation; its exit zero does not include or
override the separately failed accessibility runs. Populated UI and local StoreKit
outcomes above remain separate behavioral evidence. Source inventory verification
(`shasum -a 256 -c Evidence/NativeApp/media-workflows-source.sha256`) passed before
commit. No live CI, no-mistakes run, PR or publication has occurred.

`App/Immerse/Sources/Resources/MediaCatalog.json` is deliberately empty with an
unresolved soundtrack policy. Before production bundling, its owner must approve
each source, author, license text/hash, acquisition date, attribution, redistribution
and exported-Movie rights. JSON clearance is a recorded declaration, not legal
validation. Test-only rights cannot enter the public loader. Catalog failure leaves
existing Films usable and reports unavailability in Settings. It never falls back
to remote media, an import picker, a fixture or an automatic export.

Selected soundtrack media/license remain local and backup-included, independent
of future bundled catalog changes. A failed assembly leaves the new choice durable
and old Movie retired; retry uses retained inputs. Changing to silence deletes the
retained audio through the deletion journal. Discard never refunds capacity or
rerolls survivors. Whole-Film deletion includes soundtrack/license assets; Photos
copies and older device backups cannot be recalled. Code rollback is containment,
not a way to recover deleted private media.

Toning is prepared behind actual print-process applicability, not a user stock
replacement or a universal filter. Recommend reviewing silver-gelatin sample prints
only if a Camera's approved stock calls for that process; otherwise preserve the
color presets and no toning control. Provisional response and amount range need
DEC-04/11 review. No production stock was silently changed to make this test pass.

Full v1 remains unaccepted: pending required DECs/assets, scrolled accessibility,
all real Camera/Photos/device interruption and performance checks, backup/restore,
device Trial and first-save atomicity, and actual launch readiness. The configured
no-mistakes pipeline owns review/fixes/tests/docs/push/PR/CI at candidate handoff;
Firstmate supervises its ask-user findings. Evidence linkage is report-based and
owner-reviewed, not machine-enforced by the installed pipeline.
