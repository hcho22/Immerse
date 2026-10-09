# Private Populated Journal Harness

This separate, non-shipping target compiles the actual app views/model/modules
and seeds only its own temporary sandbox with generated native media. It does not
add fixture loading, Trial bypasses or imported media to the production app. It
does not prove native capture, entitlement, Photos writes or real-device behavior.
There is no Photos usage key; a Camera usage key exists only for the declined-request test below.

The initial Film uses synthetic preexisting subscription rights so edit/removal
workflows can run without configuring purchases. Tests exercise the real native
UI, Development, Darkroom, repository and Movie reassembly. No mocked successful
render path is installed. The separate package tests verify byte-exact Reset and
decoded output; screenshots alone cannot establish those properties.

The retained-scenario preparation additionally injects a read-only in-memory
`DeviceTrialStoring` instance into the existing JournalModel initializer. Any
unexpected ensure/consume call throws; no native Security dispatch occurs. It
requires absent StoreKit configuration, whose existing adapter returns without
calling transaction APIs. No shipping source, receipt namespace, signing setting,
permission usage key or fault flag is changed.

```sh
xcodegen generate --spec Probes/PopulatedJournalHarness/project.yml
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/PopulatedJournalHarness -resultBundlePath "DerivedData/Populated-$(date -u +%Y%m%dT%H%M%SZ).xcresult" -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

Use only a task-owned simulator. Ordinary legacy tests still create a new UUID
history each launch. Retained tests explicitly launch with `--workflow-run UUID`
and reopen that same history using `--reopen`; missing/reused seed histories fail
instead of reseeding. Histories remain under this harness's
`Documents/WorkflowHistories/UUID`, separate from the shipping app. `App/` is the
real private repository, `Fixtures/` holds native synthetic input and `Evidence/`
holds inspected state. Reopening is ordinary app process termination/relaunch,
not iOS backup, power loss or physical recovery.

An explicitly nonshipping inspection bar takes actual repository/development/
recipe snapshots, decodes and verifies retained asset hashes, and renders current
photo print bytes through the production processor. It adds an inset and explicit
rendering work, so its screenshots are contextual native workflow evidence, not
unmodified-app layout, accessibility, timing or render-quality acceptance. It does
not synthesize successful state or call exports. All inspection failures surface
as fixture failures; source/master/print and seed comparisons are separate from
UI assertions.

```sh
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/PopulatedJournalHarness/run-retained.sh UNIQUE-LABEL
ruby Probes/PopulatedJournalHarness/inspect-retained.rb Evidence/PopulatedJournal/037/UNIQUE-LABEL
SIMULATOR_ID=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 sh Probes/PopulatedJournalHarness/run-retained.sh UNIQUE-LEGACY-LABEL legacy
```

The runner requires the explicitly selected owned simulator to be Shutdown,
preserves appearance/content size, records source/artifact/runtime and xcresult
attachments, copies only newly created histories and shuts down after execution.
The six retained tests cover empty-Film Delete confirmation, early cancellation
and separate Development/original choice, one Instant revealed while the next is
sealed, saved per-photo edit/exact Reset across relaunch, Darkroom control
reachability (044) and a drawn dodge stroke saved across relaunch (047). They never
tap Open Camera, execute Photos export or purchase. Runs before 044 produced four
histories; the inspector now requires all six and tells the three developed-photo
histories apart by their inspection reasons. The offline Ruby inspector compares
UInt64 seeds exactly and normalizes only the order of Swift's completed-sequence
Set. It is an additional required check, not inferred from a screenshot/test exit.

These are functional navigation tests, not replacements for all-category
accessibility audits or the hardware/manual matrix in
`Evidence/NativeApp/launch-readiness.md`. Production export/privacy races have
their separate injected writer harness. Read `Evidence/PopulatedJournal/037/`
for actual outcomes; prepared commands alone are not acceptance.

The optional `legacy` selection reruns the three original functional tests and
the 044 player-observation test against the new harness. Its initial snapshots alone do not establish the
retained tests' before/after comparisons; do not use the six-history inspector
on that legacy output.

The optional `--movie-player-observer` argument installs a nonshipping, nearly
invisible observer that traverses the harness app's public UIKit/AVKit hierarchy,
records weak `AVPlayer`/`AVPlayerItem` identities for the actual developed Movie
surface and exposes state labels for UI tests. Use it only for the bounded
player-retirement check; it is not a production diagnostic, private API probe or
hardware playback-cache test.

```sh
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/PopulatedJournalHarness -resultBundlePath DerivedData/Populated-darkroom-controls-044.xcresult -only-testing:PopulatedJournalHarnessTests/RetainedWorkflowTests/testDarkroomAccessibleControlsReachNonGestureEditingPaths -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/PopulatedJournalHarness -resultBundlePath DerivedData/Populated-movie-player-observer-044-2.xcresult -only-testing:PopulatedJournalHarnessTests/PopulatedWorkflowTests/testMovieDiscardRetiresObservedPlayerItemBeforeSuccessorPlayback -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

Read `Evidence/NativeApp/darkroom-player-observation-044.md` for the retained
outcomes, failed setup assumptions, hashes and limits.

`PhotosPermissionWorkflowTests` needs a denied add-only Photos status set from the host before launch.
The harness has no Photos usage key.
The test reads the status in the actual Settings view and stops before any export control unless it shows Off, so it never reaches a system prompt and never writes to Photos.
`Scripts/validate-local.sh` applies the same revoke before the full harness suite.

```sh
xcrun simctl bootstatus "$SIM" -b
xcrun simctl privacy "$SIM" revoke photos-add com.immerse.PopulatedJournalHarness
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/PopulatedJournalHarness -resultBundlePath DerivedData/Populated-photos-denied.xcresult -only-testing:PopulatedJournalHarnessTests/PhotosPermissionWorkflowTests -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

Read `Evidence/NativeApp/permission-storage-failures-045.md` for the reproduced defects, outcomes and limits.
A simulator privacy revoke is not a device PhotoKit write, restricted-status or prompt-timing result.

`CameraPermissionWorkflowTests` resets the harness's Camera authorization, opens an existing Film's camera and declines the actual system request through an interruption monitor; without the monitor XCTest allows it.
The harness declares a Camera usage key only for this test; other tests never open the camera, and the simulator has no camera to capture with.
The test also checks that the guidance and the shutter are on screen without scrolling; run it on small screens such as an iPhone SE (3rd generation) as well.
Read `Evidence/NativeApp/visual-sweep-048.md` for the outcomes and limits.

`--black-and-white` loads the seeded 6×6 (`--medium-format`) or 16mm (`--movie`) Film on the black-and-white Film
Stock; without it a Camera with a Film Stock gets Load Film's default, color. `--photo-source PATH` and
`--movie-source PATH` capture an existing still or silent movie instead of the generated fixtures, so screenshots can
show a natural scene; the UI tests pass them on when the run sets `TEST_RUNNER_PHOTO_SOURCE` and
`TEST_RUNNER_MOVIE_SOURCE` (for example `Evidence/AssetReview/sources/window-still-life-generated.png` and
`Evidence/AssetReview/draft-01/source-landscape.mov`). They are evidence aids only; nothing in the shipping app reads them.
