# Movie Player Cache Checkpoint 042

Continuation from checkpoint `96a284f273aacc68d6452b88232fa5af09512180`.
This checkpoint covers bounded software evidence for developed Movie playback
state around clip discard in the populated Journal harness. It is not native
hardware playback fidelity, PhotoKit export, device interruption, backup/restore
or accessibility acceptance.

## Diagnosis

The first draft of the populated Movie UI test required the generic
`developed-movie-player` accessibility query to disappear after every clip
discard. That was too strong for the first discard: when one clip remains, the
product requirement is stale-clip retirement plus a rebuilt playable Movie for
the surviving clip, not a human-visible transient absence between those states.

The `041-9` activity log separates the cases:

- `Discard #1` was confirmed, `discard-clip-1` disappeared and
  `discard-clip-2` remained available.
- The generic player query never stopped existing during the first-discard wait,
  so that query could not distinguish an old player instance from its legitimate
  successor.
- The test continued, confirmed `Discard #2`, observed `discard-clip-2`
  disappear and proceeded through the final no-player/no-export/placeholder
  assertions.

Earlier failures are preserved as separate causes: `041` and `041-2` were
premature confirmation lookups; `041-3` hit SwiftUI type-checking after an
abandoned item-based dialog experiment; `041-4` and `041-5` exposed the
nonshipping inspection bar overlapping the Movie discard control; `041-6`,
`041-7` and `041-9` exposed the over-specific transient-player assertion;
`041-8` failed before test execution because XCTest could not instantiate the
runner bundle from simulator cache.

The speculative `Task.yield()` and `hiddenFilms` Set-reassignment production
experiments were removed. The remaining production change is only a
non-visible accessibility identifier on the actual `VideoPlayer`, allowing the
harness to assert stable player presence/absence. The harness-only
`--hide-inspection-bar` launch argument removes its synthetic inspection controls
from this Movie workflow; retained inspection scenarios still launch without it.

## Observed Behavior

| Case | Expected and observed result | Evidence |
| --- | --- | --- |
| Runtime stale assembled Movie retirement | Discarding the first clip removes the old assembled Movie file, preserves the retained second clip bytes and deterministic Development assignments, writes a newly verified Movie containing only the surviving clip, and after the final discard leaves numbered placeholders with no assembled Movie asset. | `swift test --package-path Packages/FilmRuntime --filter FilmProcessorTests/testRealMovieDiscardReassemblesOnlyRetainedDevelopedClipThenKeepsEmptyPlaceholders` |
| Populated Journal initial Movie state | The actual Film detail view exposes a developed Movie player, no Darkroom entry, export affordance present and waste copy present before discard. | `PopulatedWorkflowTests.testMovieDiscardKeepsNumberedEmptyFilmWithoutPlaybackExportOrDarkroom` in `DerivedData/Populated-movie-cache-042.xcresult` |
| First clip discard with surviving playback | Confirming discard of clip 1 removes that clip control, keeps clip 2 available, and retains/rebuilds a playable Movie surface for the surviving clip. The UI evidence does not prove an old player instance disappeared between those states. | Same `042` UI run plus runtime stale-file retirement test above |
| Final clip discard / DEC-09 empty Movie behavior | Confirming discard of clip 2 leaves no Movie player and no "Save Developed to Photos" affordance, keeps two numbered discarded placeholders and keeps the exact wasted-seconds copy. | Same `042` UI run |

## Executed Gates

Environment: macOS 26.6.2, Xcode 26.5, Swift 6.3.2. Hosted iOS execution used
the owned iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, iOS
26.5 / build 23F77. The simulator was observed Shutdown after the passing UI
run.

```sh
swift test --package-path Packages/FilmRuntime \
  --filter FilmProcessorTests/testRealMovieDiscardReassemblesOnlyRetainedDevelopedClipThenKeepsEmptyPlaceholders
```

Result: one selected runtime test passed, zero failures.

```sh
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj \
  -scheme PopulatedJournalHarness \
  -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' \
  -derivedDataPath DerivedData/PopulatedJournalHarness \
  -resultBundlePath DerivedData/Populated-movie-cache-042.xcresult \
  -only-testing:PopulatedJournalHarnessTests/PopulatedWorkflowTests/testMovieDiscardKeepsNumberedEmptyFilmWithoutPlaybackExportOrDarkroom \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 180 \
  CODE_SIGNING_ALLOWED=NO test
```

Result: one UI test passed, zero failures/skips. `xcresulttool` summary reported
`passedTests: 1`, `failedTests: 0`, device iPhone 17 Pro simulator iOS 26.5 /
build 23F77.

Local result bundle hashes, computed over sorted file hashes:

| Artifact | Outcome | Hash |
| --- | --- | --- |
| `DerivedData/Populated-movie-cache-041.xcresult` | failed: premature confirmation lookup | `50f352c31ad914c27c5846e5d1c8d44c8b8a9debd9f0857cbc56c1bdf0b88485` |
| `DerivedData/Populated-movie-cache-041-2.xcresult` | failed: premature confirmation lookup retained | `308bd05b797bcef4e3a77a11ac889f522a47cd74b7dda2924de5de575d672d9a` |
| `DerivedData/Populated-movie-cache-041-3.xcresult` | failed: SwiftUI type-checking after abandoned item-dialog experiment | `200d9571fc801ffb1506452f0fc3489573d0ea271c656d420778ec18e61188c5` |
| `DerivedData/Populated-movie-cache-041-4.xcresult` | failed: inspection bar overlapped discard control | `e9de5ea1776d5f1406712cff257d8f96a080bf5051571528401b4e46d15dc07b` |
| `DerivedData/Populated-movie-cache-041-5.xcresult` | failed: inspection bar still overlapped final discard control | `029b096a66e1242b9a94dbae0fd7ce4d72722bef7069bcc2d7e531e5bba2795c` |
| `DerivedData/Populated-movie-cache-041-6.xcresult` | failed: generic player query never disappeared after first discard | `8bba791977ec4846db13910576e77c35076e719ac1f96fd150707911b91c006c` |
| `DerivedData/Populated-movie-cache-041-7.xcresult` | failed: `Task.yield()` did not make transient absence observable | `359bc52422b3b14259fb2ced68bcb3c405fca8c569e9ebfaf3121f3768cbb0c1` |
| `DerivedData/Populated-movie-cache-041-8.xcresult` | failed before test execution: XCTest runner bundle cache error | `829291777721d9d0ef44c6db4c22d95ce0bc371ba764508e01250ba2cc84870a` |
| `DerivedData/Populated-movie-cache-041-9.xcresult` | failed: Set-reassignment experiment still did not make transient absence observable, but activity log proved first and second discards persisted | `7d7ea176c7e6e160d82f19759d799a008ebe6e7b5691aa85f26f8bd99788806e` |
| `DerivedData/Populated-movie-cache-042.xcresult` | final bounded pass, one UI test passed | `110a627c8bf37ba47188b8448883a705e8ac3fdbaa36918c03283b2d4d1b4908` |

Relevant source hashes after this checkpoint:

| Source | SHA-256 |
| --- | --- |
| `App/Immerse/Sources/FilmDetailView.swift` | `4a5086b909dc54ee310d2f50634dff404cfc71b623be007d81f6076af1958971` |
| `Probes/PopulatedJournalHarness/Sources/WorkflowHarnessApp.swift` | `74eb50fd309c211567fe9ac26ac45be5f4f731cac301572c44702f4f2053b1ee` |
| `Probes/PopulatedJournalHarness/Tests/PopulatedWorkflowTests.swift` | `9e99bf80438d77ab183c9e7b2e9a3451ee3977ac7cc54e93c1baa897ceec7315` |

## Limits

This checkpoint proves repository/runtime stale assembled-Movie retirement and
stable populated-Journal UI states with synthetic media. It does not prove the
identity or lifetime of a specific `AVPlayer` instance, a real device playback
cache, hardware codec fidelity, PhotoKit export race behavior, background
interruption, accessibility conformance, or any physical backup/restore result.
Those remain in the manual and hardware matrices.

## Proposed Follow-Up

The old app-owned player lifetime is still a software-observable boundary, not
automatically a hardware-only gap. Before adding production seams, use a
nonshipping hosted view test against the actual Film detail view with synthetic
Movie media:

1. Host the real view/model in a probe target that can traverse the SwiftUI /
   UIKit hierarchy after the developed Movie player appears.
2. Locate the existing `AVPlayerViewController`/player surface through public
   UIKit/AVKit relationships and retain a weak reference to the observed player
   or current item. Do not use private API.
3. Trigger Discard/Delete through the actual view action path and wait for the
   production completion acknowledgement.
4. Assert the observed old playback path cannot still present discarded content:
   either the old player/item is released, or the retained player has no current
   item / no readable discarded asset. Separately assert any successor Movie
   contains only retained clips, as the current runtime test already does.

If the public hierarchy cannot expose enough identity to distinguish old and
successor players, record that exact infeasibility and propose the narrowest
reviewable nonshipping seam. Do not add a shipping diagnostic flag, forced
visible delay, broad observer framework or persistent protocol for this.
