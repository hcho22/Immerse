# Physical Scroll Viewport Comparison

Status: bounded comparison authorized by Firstmate 026 finds real probe separation,
but the production attempt fails required audits. No production remedy or v1
acceptance is established. Baseline is `ba83eb2`. Original Form, automatic
stack, failed hard-edge/suppression/GeometryReader cases and all earlier evidence
remain unchanged. No physical device or release action is authorized.

## Prediction Before Execution

Compare the intact automatic-edge stack with only ordinary outer vertical padding
of 16 points. Do not combine this with edge suppression or the GeometryReader
switch. Padding is outside ScrollView, not its content or safe area.

Ranked explanations: (1) physical viewport underlap contributes to scrolled contrast;
(2) the observed audit size sweep/clamped offset explains later capture mismatch;
(3) a remaining contrast/semantic issue is independent of those boundaries.
Only the first is changed here. If padding genuinely isolates the viewport, public
UIScrollView window bounds must begin below the setup navigation bar and remain
separate during the sweep, with every row still reachable. If those measurements
do not change, reject the condition before interpreting any green audit. If
separation occurs but contrast survives, isolation is not sufficient.

Apple documents [ordinary padding](https://developer.apple.com/documentation/swiftui/view/padding(_:_:))
and its [layout effect](https://developer.apple.com/documentation/swiftui/laying-out-a-simple-view)
separately from content/safe-area margins. The public
[adjustedContentInset](https://developer.apple.com/documentation/uikit/uiscrollview/adjustedcontentinset)
and UIView coordinate conversion APIs are used read-only. No private type matching,
delegates, method swizzling or changes to UIScrollView behavior are introduced.

## Shared Probe Instrumentation

Both conditions traverse the probe window's public subviews to observe UIScrollView
window frame, bounds, content/adjusted insets, content size, safe area and existing
clipping state; UINavigationBar frames/titles are recorded separately. Observation
runs from existing layout/scroll callbacks, not a polling loop. It never mutates
native scroll geometry. Records are deduplicated by observed geometry.

After each Dynamic Type change, one main-queue capture renders the app UIWindow
using `UIGraphicsImageRenderer` and `drawHierarchy(afterScreenUpdates: true)`.
`size-screen` records capture start/return times, then file persistence time and
the native trait category. The PNG filename includes a per-launch UUID; capture
failure is reported, not omitted. This captures app-window pixels, not the system
status bar or XCTest's private analyzer image. It may add latency; identical
instrumentation is present in the control. Native metrics and earlier XCTest
pre-audit/callback/after screenshots plus full exported recordings are retained.

No labels/controls/semantic colors/fonts/sheet navigation change. No clipping
modifier, content-height/font cap, issue filter or category exclusion is used.
The existing title and Load Film reachability assertions remain in force. This
probe has no media, permissions or billing and its Load Film command remains no-op.

## Initial Observations

Xcode 26.5, iOS 26.5 (23F77), x86_64 iPhone 17 Pro, task-owned simulator
`AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, system accessibility XXXL, light appearance.
The source in `accessibility-physical-frame/experiment-source.sha256` executed in
`DerivedData/SetupProbe-PhysicalFrame-Largest.xcresult` on October 1, 2026:

| Condition | Observed outcome |
| --- | --- |
| Intact stack, shared instrumentation | Failed (51.616 s): command audit reports description and Silent capture contrast. Top/title audits clear in this run. |
| Outer vertical padding only | Passed (42.809 s): all-category top/title/command audits; original title/command reachability checks pass. |

The bundle correctly reports **one pass / one failure**, exit 65. The failing
control was not excluded. Its native viewport is `[0,62,402,812]`, with adjusted
insets 143/34 at expanded title and 70/34 collapsed. The padded native viewport
is `[0,221,402,603]`, zero adjusted insets; its navigation bar is `[0,78,402,127]`.
During the size sweep the viewport changes to `[0,200,402,624]` and back, remaining
below the navigation bar. `frame-summary.json` joins successive public observations:
502 padded scroll observations have a 12-to-16-point positive gap; settled states
have 16 points. Sequential observations are not claimed to be simultaneous samples.

Thirty-six timestamped app-window PNGs per condition are retained in `size-screens/`.
No window-capture failure was logged. Queued captures can observe the same native
category more than once; they do not guarantee an image for every intermediate
category. Capture start/return windows and later persistence timestamps are distinct.
Full XCTest attachments/trees are in `audit/`, along with the untrimmed exported
control recording. Xcode did not export a video for the passing condition; its
pre/after screenshots and timed app-window size-sweep captures are retained instead.

Padded title pre-audit `7F9732A1-AE78-4E5A-AD78-F66EA1EB548E.png` and command
`0B74527A-2D2C-4B58-ABD6-B6D8BACC4D64.png` confirm physical separation from chrome.
They also expose that `isHittable` alone accepts a partially visible Load Film
button. This is not sufficient row-accessibility evidence, so a separate check
requires every label/control frame to fit fully inside the scroll viewport after
ordinary user scrolling. It does not alter any audit or comparison position.

The first reachability attempt failed before the first row: LabeledContent exposes
`Capacity, 2:45 of film`, not `Capacity`. The raw failure is retained under
`reachability-initial/`, with its source in `reachability-initial-source.sha256`.
Only the query was corrected; the new check also includes the picker/title field.
The corrected check passed all twelve rows (74.788 s) in
`DerivedData/SetupProbe-PhysicalFrame-Reachability-2.xcresult`, one pass / zero
failures, exit 0. Its current source is `source.sha256`; `reachability/` retains
complete activity, bounds and each fully visible row's screenshot. For example,
Load Film is `[32,745.667,338,63.333]` inside `[0,221,402,603]`, and the 364.667-point
disclosure fits fully after scrolling. The initial wrong-query failure is not
relabeled as a product defect or silently removed.

## Actual-App Countercheck

The localized production attempt replaced only LoadFilmView's Form with the same
padded ScrollView/VStack arrangement. All labels, controls, semantic fonts/colors,
loading/error actions, sample sheet and catalog navigation remained. No audit
code changed. `production-attempt.patch` reconstructs this attempted source on
`ba83eb2`; `production-source.sha256` identifies it. No probe observer was added
to production. The attempted layout is removed from the final candidate because
the required actual-app countercheck failed, not retained as an accepted fix.

Same iOS 26.5 simulator, system default large size; the largest test uses its
existing accessibility XXXL launch argument. Each test retains every audit finding.

| Appearance / test | Actual outcome |
| --- | --- |
| Light / default | Failed, 34.063 s: Subscription contrast, callback frame `[32,816,96,20.3]`. |
| Light / largest | Failed, 72.190 s: title audit Movie Orientation; command audit description, Movie Orientation and Silent capture contrast. |
| Dark / default | Passed, 30.427 s, including catalog/setup/back/cancel/Settings/Archive assertions. |
| Dark / largest | Failed, 62.852 s: command audit Trial status unavailable contrast. |

Light is **0/2**, dark **1/2**, both exit 65, zero skips. Full activity, all exported
attachments/recordings, summaries and command logs are in `app-light/` and
`app-dark/`. A passed audit elsewhere in these tests does not cancel a failure.
The actual unsigned app correctly reports unavailable Trial status; the probe's
constant unused-Trial label is not production authority or a permitted bypass.

Largest light Movie Orientation callback frame is `[32,793.3,249.7,125.3]`,
description `[32,482.7,302.7,187.3]`, Silent capture `[60,700,308,63.3]`. Largest dark
Trial callback frame is `[38.7,1330.7,329.3,187.3]`. These are later issue-query
frames, not the analyzer's internal capture. The app's pre-audit AX trees show a
setup scroll frame `[0,148,402,676]` below collapsed navigation `[0,78,402,54]`;
default expanded frames are `[0,200,402,624]` and `[0,78,402,106]`. No native
production observer measured the intervening sweep, so continuous separation is
not asserted for the actual app.

Inspected light command-after `B2251824-5346-4059-B4AA-D321970A7299.png` and dark
`38ED8E7A-0F88-4786-9EDA-1AB8A0E45210.png` show the viewport returned near the top
after the audit, with Capacity and Movie Orientation partly beyond its edges.
They do not show the earlier command position or justify a false-positive claim.
The actual app has a pushed setup with a Back button, unlike the probe's sheet
root. This and real entitlement text remain material differences.

The affected populated-flow regression run passed **3/3**, zero skips, exit 0:
photo early Development/Darkroom/Reset/Discard/rename/Archive/restore/Delete Film
(91.099 s), Instant open-pack reveal (16.655 s), and Movie discard to numbered
empty placeholders without playback/export/Darkroom (30.741 s). `populated/`
retains the result summary, full activity and exported screenshots/trees;
`populated-source.sha256` binds the unchanged harness, which compiled the attempted
production source. These private fixture paths do not load/capture a real Trial,
write Photos, or establish populated-screen accessibility acceptance.

The first export command ran before xcodebuild finalized the populated bundle and
failed with missing Info.plist/root ID. No artifact or result was accepted from
that incomplete bundle. Exports succeeded after xcodebuild returned exit 0. The
task-owned simulator was restored to light/default size and shut down afterward.

## Impact and Recovery

Final production app/packages/harness source is byte-for-byte unchanged from
`ba83eb2`; `final-production-source.sha256` records the restored setup/test files.
Only probe instrumentation/tests and evidence/documentation remain as changes.
The attempted patch was reapplied to an isolated temporary Git index and its setup
source SHA-256 exactly matches `production-source.sha256`; this does not change
the worktree or production database. Probe PNGs are synthetic UI in its own
simulator container, with no permissions, personal media or service side effects.
Existing production accessibility failures remain unresolved after removal of
the attempt. Hardware/media recovery and product judgments remain with their
existing owners; this checkpoint neither changes those risks nor accepts them.

## Conclusion and One Next Check

The geometry prediction succeeds in the instrumented minimal probe: ordinary
outer padding creates a physically separate scroll frame, unlike the earlier
GeometryReader wrapper. All-row reachability and its all-category audit pass.
The stronger prediction, that this is sufficient for production acceptance, fails.
No category exception, hidden label, fixed font/content height, clipping modifier,
global style patch or product-contract change is warranted by this evidence.

One smallest next decisive check, **not executed or authorized by this report**:
repeat the padded minimal condition with only synchronous app-window PNG capture
disabled, retaining read-only geometry, the same content/navigation and all
top/title/command audits. Keep XCTest pre/callback/after screenshots and exported
video where available. Prediction: it remains clean without the added capture
latency. Failure would disprove independence from observer timing; success would
leave the documented navigation/entitlement differences for later isolation.
Current `size-screen` capture/persistence work runs on the main queue and adds
0.243 to 0.412 seconds per capture (median 0.293 across 72 captures, using
`time - captureStart` in `geometry.log`). Equal instrumentation in both conditions
does not establish equivalence to the uninstrumented production app.

## Exact Execution

All commands ran from the repository root with Xcode 26.5 (17F42), macOS 26.6.2,
Swift 6.3.2. No phone, credentials, Keychain mutation, Photos write or publication
was requested. Set `SIM=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60` in the commands below.
Result bundles are local under ignored DerivedData; portable exports and hashes
are retained beside this report. Original bundles retain raw stdout; trailing
horizontal whitespace in exported text logs may be normalized for Git only.

```sh
xcrun simctl ui "$SIM" appearance light
xcrun simctl ui "$SIM" content_size accessibility-extra-extra-extra-large
xcodebuild -quiet -project Probes/SetupAccessibilityProbe/SetupAccessibilityProbe.xcodeproj -scheme SetupAccessibilityProbe -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/SetupProbe-PhysicalFrameFresh -resultBundlePath DerivedData/SetupProbe-PhysicalFrame-Largest.xcresult -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackContainer -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackOuterPadding -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
xcodebuild -quiet -project Probes/SetupAccessibilityProbe/SetupAccessibilityProbe.xcodeproj -scheme SetupAccessibilityProbe -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/SetupProbe-PhysicalReachabilityFresh -resultBundlePath DerivedData/SetupProbe-PhysicalFrame-Reachability-2.xcresult -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testPaddedRowsRemainFullyReachable -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
xcrun simctl ui "$SIM" content_size large
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/ValidationSimulator -resultBundlePath DerivedData/Immerse-PhysicalFrame-Light.xcresult -only-testing:ImmerseUITests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
xcrun simctl ui "$SIM" appearance dark
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/ValidationSimulator -resultBundlePath DerivedData/Immerse-PhysicalFrame-Dark.xcresult -only-testing:ImmerseUITests -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
xcrun simctl ui "$SIM" appearance light
xcodebuild -quiet -project Probes/PopulatedJournalHarness/PopulatedJournalHarness.xcodeproj -scheme PopulatedJournalHarness -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/PopulatedJournalHarness -resultBundlePath DerivedData/Populated-PhysicalFrame.xcresult -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

The first reachability run used the same command with result path
`SetupProbe-PhysicalFrame-Reachability.xcresult` and the initial query source hash.
Test selections and effective environments are explicit; no zero-test run counts
as evidence. QA-13 / H-UX remains open, as do the separately recorded full-v1
hardware, asset, product and launch requirements. This report is a no-mistakes
handoff artifact, not authority to waive a gate or launch the pipeline as green.

## Final Local Gate

After removing the production attempt, `sh Scripts/validate-local.sh` returned
exit 0 on October 1, 2026, approximately 17:06-17:09 UTC. It passed 115 package
tests plus 17 Trial study/process tests, built the asset generator, verified all
122 intake IDs / 72 clauses / nine invariants, compared the regenerated documents
ZIP by listing/content, and built the app unsigned for simulator and generic iOS
device. `local-validation.log` retains the complete output. Optional native UI
and StoreKit simulator environment variables were not set in this final command;
the explicit UI failures above remain failures, not part of that green gate.

Source inventories, reconstructed attempted-source hash and evidence SHA-256
inventory were checked separately. Production source equality against `ba83eb2`
and `git diff --check` pass. This checkpoint has no no-mistakes run, push, public
exposure, CI-ready claim or completed-v1 assertion. Firstmate owns the next bounded
diagnostic direction and existing unresolved product/manual-validation decisions.
