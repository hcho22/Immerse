# Darkroom and Movie Player Observation Checkpoint 044

Continuation from checkpoint `8317e77fb8a99d455a42e67e471a31cc61c9749b`.
This checkpoint covers two bounded Populated Journal harness continuations:
Darkroom non-gesture control reachability and Movie player/item retirement
through public UIKit/AVKit relationships. It is not physical-device acceptance,
VoiceOver/Switch Control acceptance, production render-quality approval,
PhotoKit execution, background interruption evidence or hardware playback-cache
fidelity.

## Scope

The `PopulatedJournalHarness` target compiles the actual app views, model,
repository and native render/runtime modules with private synthetic media in a
separate nonshipping app. This checkpoint adds no production `App/Immerse`
source change and no shipping diagnostic flag.

For Darkroom, the retained workflow UI test now opens a real developed photo,
enters the actual `DarkroomView`, and reaches:

- the Contrast menu control as exposed by iOS accessibility (`Contrast grade,
  Original`);
- CMY Filtration sliders;
- Crop enablement, size and horizontal/vertical position sliders;
- non-gesture Dodge/Burn horizontal/vertical positioning, point insertion and
  undo; and
- Save plus the existing harness state inspection.

For Movie playback, Firstmate approved the nonshipping follow-up proposed in
`movie-player-cache-042.md`. The harness-only `--movie-player-observer` overlay
uses only public `UIApplication`/`UIViewController` traversal to find the
existing `AVPlayerViewController`, then weakly records the initial
`AVPlayer`/`AVPlayerItem` identities. The UI test triggers Discard #1 through the
actual Film detail confirmation path, waits for the discard control to disappear
and the retained clip to be visible, then asserts that the old player path is
`released`, `detached` or `replaced` while a successor player/item is visible.
Before/after observer snapshots are retained in the final result bundle.

## Observed Behavior

| Case | Expected and observed result | Evidence |
| --- | --- | --- |
| Darkroom assistive/non-gesture paths | The actual Darkroom sheet exposed all configured tool controls under XCTest accessibility queries. CMY, crop size/position and local exposure position controls accepted UI adjustments; Dodge point insertion enabled Undo; Undo cleared the stroke; Save returned to the photo/Film flow and inspection completed. | `RetainedWorkflowTests.testDarkroomAccessibleControlsReachNonGestureEditingPaths` in `DerivedData/Populated-darkroom-controls-044.xcresult` |
| Movie initial player observation | With the actual developed Movie visible, the observer found a public `AVPlayerViewController` and recorded an attached initial player/current item. | `PopulatedWorkflowTests.testMovieDiscardRetiresObservedPlayerItemBeforeSuccessorPlayback` in `DerivedData/Populated-movie-player-observer-044-2.xcresult` |
| Movie first-clip discard boundary | After the real Discard #1 confirmation completed and `discard-clip-2` remained available, the old player/item reference was no longer the still-attached visible playback path and a successor player/item identity was visible. | Same `044-2` UI run; successor content remains bounded by the runtime stale-Movie test recorded in `movie-player-cache-042.md` |

## Executed Gates

Environment: macOS 26.6.2, Xcode 26.5, Swift 6.3.2. Hosted iOS execution used
the owned iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, iOS
26.5 / build 23F77.

```sh
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj \
  -scheme PopulatedJournalHarness \
  -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' \
  -derivedDataPath DerivedData/PopulatedJournalHarness \
  -resultBundlePath DerivedData/Populated-darkroom-controls-044.xcresult \
  -only-testing:PopulatedJournalHarnessTests/RetainedWorkflowTests/testDarkroomAccessibleControlsReachNonGestureEditingPaths \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 180 \
  CODE_SIGNING_ALLOWED=NO test
```

Result: one UI test passed, zero failures/skips. `xcresulttool` summary reported
`passedTests: 1`, `failedTests: 0`; the xcodebuild observer reported 96.790
seconds elapsed.

Note: a follow-up `xcrun xcresulttool get test-results tests --path
DerivedData/Populated-darkroom-controls-044.xcresult --format json` command
returned Apple's result-tool error about `database.sqlite3` already existing
inside the result bundle. It is not counted as a test failure; the retained pass
claim is bounded to the `xcodebuild` exit code and `test-results summary` above.

```sh
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj \
  -scheme PopulatedJournalHarness \
  -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' \
  -derivedDataPath DerivedData/PopulatedJournalHarness \
  -resultBundlePath DerivedData/Populated-movie-player-observer-044-2.xcresult \
  -only-testing:PopulatedJournalHarnessTests/PopulatedWorkflowTests/testMovieDiscardRetiresObservedPlayerItemBeforeSuccessorPlayback \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 180 \
  CODE_SIGNING_ALLOWED=NO test
```

Result: one UI test passed, zero failures/skips. `xcresulttool` reported
`passedTests: 1`, `failedTests: 0`; the test node duration was 33.521 seconds.

Local result bundle hashes, computed over sorted file hashes:

| Artifact | Outcome | Hash |
| --- | --- | --- |
| `DerivedData/Populated-darkroom-controls-043.xcresult` | failed: `Open photo 1` was below the current scroll pose | `3fc437afaa983abe5f5920e8406df091a30d4f5e4cd9389b24d0702ad5731684` |
| `DerivedData/Populated-darkroom-controls-043-2.xcresult` | failed: exact `Contrast grade` query did not match the exposed `Contrast grade, Original` button label | `3a0498c28cdb479f5c3a45b006144476bcb32e7aff54c47fb28f2856c7f37b58` |
| `DerivedData/Populated-darkroom-controls-043-3.xcresult` | earlier bounded Darkroom pass before the harness-only Movie observer source was added | `01009afe07d69a77fc9c0caa431fc814ddf28568010acfa9937680d810b7576f` |
| `DerivedData/Populated-darkroom-controls-044.xcresult` | final bounded Darkroom pass on the same source state as this checkpoint | `d8397ec49c154ea92e5c44041a772b273fe317c47e2cc41c51d7fb94328f96d8` |
| `DerivedData/Populated-movie-player-observer-044.xcresult` | initial observer pass before retained before/after snapshots were added | `ae70a14af676c7d5e2049ea542650102497201e0bffa5a5a040ea772551d1aff` |
| `DerivedData/Populated-movie-player-observer-044-2.xcresult` | final bounded observer pass with retained snapshots | `6ac5d10706e6beb1506153ad4c5fff39ac848319b0d7f9b41cd82bbea9cfa651` |

Relevant source hashes after this checkpoint:

| Source | SHA-256 |
| --- | --- |
| `Probes/PopulatedJournalHarness/Sources/WorkflowHarnessApp.swift` | `24f85693f606df4a32a5a194265a41aeda1f7ba1f68c87723fb14e6d9100d5e8` |
| `Probes/PopulatedJournalHarness/Tests/PopulatedWorkflowTests.swift` | `4155b63c01a6b43f5aa2d64e9858fef61602dd8903613daf0a5aec6a70fbfc2b` |
| `Probes/PopulatedJournalHarness/Tests/RetainedWorkflowTests.swift` | `92a2258ece9f4137f03944879df5795e10bd0da554e6be17e74ecd178f03d1b9` |

## Limits

The Darkroom check is still a simulator XCTest path with synthetic media. It does
not establish VoiceOver rotor/order, Switch Control operation, all-category
accessibility audits, physical Dynamic Type behavior, gesture drawing coverage,
approved DEC-04/DEC-11 control ranges or final visual quality.

The Movie observer proves that the app-owned AVKit reference reachable through
public hierarchy relationships is retired, detached or replaced before the
successor Movie surface is treated as visible after the first discard. It does
not inspect private AVFoundation caches, hardware decoder behavior, PhotoKit
export races, background/lock interruptions, licensed soundtrack behavior,
physical storage pressure, or real-device playback fidelity. The successor
Movie's retained-clip content is still established by the runtime stale-Movie
retirement test in `movie-player-cache-042.md`, not by the observer alone.
