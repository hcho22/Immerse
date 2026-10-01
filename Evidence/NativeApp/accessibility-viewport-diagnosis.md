# Audit Viewport and Capture Timing

Status: bounded follow-up concluded without a production remedy, not acceptance. Baseline `08d4591` and its
complete container report remain retained. Firstmate instruction 025 authorizes
at most two independent smallest counterfactuals, preserving the original Form,
visible labels, semantic fonts/colors, controls, sheet navigation and every audit
category. No physical action or product decision is involved.

## Primary API Boundaries

Apple documents [audit execution](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/performaccessibilityaudit(for:_:))
with all categories as the default. Its [audit guidance](https://developer.apple.com/documentation/accessibility/performing-accessibility-audits-for-your-app)
describes current-screen checks and warns that passing audits is not complete
assistive-technology verification. The [issue object](https://developer.apple.com/documentation/xcuiautomation/xcuiaccessibilityauditissue)
exposes an optional element, not a documented analyzer-capture timestamp. Thus a
later callback frame or screenshot cannot be treated as the analyzer's own capture.

[Edge suppression](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffecthidden(_:for:))
hides the effect; it is distinct from the previously failed nearly opaque hard
style. [Scroll geometry](https://developer.apple.com/documentation/swiftui/scrollgeometry)
provides offsets, insets, content/container bounds and visible rect.
[GeometryReader](https://developer.apple.com/documentation/swiftui/geometryreader)
provides a container's coordinate space/size, with
[safe-area insets](https://developer.apple.com/documentation/swiftui/geometryproxy/safeareainsets).
Apple's [scroll-view guidance](https://developer.apple.com/design/human-interface-guidelines/scroll-views)
ties edge effects to scrolling content behind floating controls. These APIs enable
the experiments below; none establishes that an existing audit is a false positive.

## Timing Instrumentation

The existing minimal probe now records wall-clock and monotonic times for scroll
geometry, label geometry/categories and root/window safe areas. Test activity
records audit entry/return, handler entry, a screenshot before element queries,
current tree, issue query and a later screenshot. Every handler still returns
false. The API does not supply the internal analyzer capture time, so these only
bound observable events. Retain complete activity/video with the resulting
screenshots and issue nodes. The instrumented unchanged stack is a control, not
a third layout counterfactual.

## Falsifiable Counterfactuals

1. **Suppress edge effects only:** the same stack uses the documented
   `scrollEdgeEffectHidden(true)` with automatic style otherwise unchanged. If
   edge-effect masking is sufficient to explain the contrast failures, those
   findings should disappear. A remaining issue disproves sufficiency; visible
   overlap with chrome would still disqualify the result as a production remedy.
2. **Change viewport ownership only, if needed:** keep automatic edge effects and
   place the same stack's ScrollView inside GeometryReader, with its frame equal
   to the parent's available size. Prediction: measured physical viewport ends
   below navigation chrome and no label is painted through that chrome. Reject
   the condition if bounds do not actually change as predicted, if required
   content becomes unreachable, or if the same findings survive. No clipping
   modifier, fixed content height, hidden element or font cap is introduced.

All rows remain scroll-reachable and tests keep title and Load Film reachability
assertions. Each change is compared independently with the original stack; the
two conditions are not combined to manufacture acceptance. Only a demonstrated
cause may justify a minimal app correction followed by all-category actual-app
default/largest light/dark gates.

## Executed Candidate and Results

October 1, 2026, Xcode 26.5 (`17F42`), macOS 26.6.2, iOS 26.5 (`23F77`),
x86_64 iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`.
System size was `accessibility-extra-extra-extra-large`, appearance light.
Source was `08d4591` plus the probe instrumentation/two switches in
`accessibility-viewport/source.sha256`. Both new methods actually executed.
The Form control and prior default stack success are retained unchanged in the
previous report; this follow-up did not rerun or supersede their default results.

| Condition | Result | Findings / interpretation |
| --- | --- | --- |
| Instrumented automatic-edge stack control | Failed, 40.700 s test body | Top clean; title: Silent capture contrast; command: Trial label contrast. |
| Same stack, documented edge suppression | Failed, 39.352 s test body | Top/title clean; command: description, Movie Orientation, Silent capture contrast. Suppression is insufficient. |
| Same stack, GeometryReader-sized viewport, automatic edges | Failed, 40.065 s test body | Top clean; title: Silent capture contrast; command: description and Silent capture contrast. Viewport isolation prediction itself was not achieved. |

No skipped/expected failures, filters, category exclusions or callback exceptions.
Title and Load Film reachability assertions passed. The first result bundle is
0 passed / 2 failed; the second is 0 passed / 1 failed. Both commands exited 65.
Test bodies are not end-to-end build timings or iPhone performance evidence.
The bundles finalized at 16:37:01.658Z and 16:38:36.161Z respectively. A host
snapshot at 16:38:19Z showed load averages 23.28/22.51/23.76, not a controlled
low-contention condition. No contention-cause conclusion is supported.

## Earliest Observed Divergence

The later issue screenshot is demonstrably not the pre-audit viewport. Example:
the suppressed-edge **command** audit has these Unix wall-clock times; monotonic
values are retained beside them in the raw logs and `audit-timeline.json`.

| Time | Observation |
| --- | --- |
| 1790872583.553345 | Audit call. Largest type, content height 2089.333, offset 1294.667. Trial label global y=3, partly underneath the navigation title. |
| 1790872583.997029 | First recorded content shrink to height 833; label events report xSmall / preferred body 14 pt. Offset is initially still 1294.667. |
| 1790872584.004158 | Offset changes to 55, before any issue callback. |
| 1790872584.062587 | Further content shrink to 726 and offset changes to -52. |
| 1790872585.588598 | Content returns to height 2089.333 / accessibility5; offset stays -52. Trial label is now y=1349.667, outside the window. |
| 1790872586.490519 | First issue callback enters, after the size/offset changes. |
| 1790872586.700435 | Callback screenshot has returned, before app-tree and issue-element queries. It already shows the top of the content. |
| 1790872587.828155 | Issue-element query completes, reporting description y=501.667. It did not cause the preceding offset jump. |

Thus the callback's own element query is ruled out as the cause of this **earlier**
jump. Size sweeping/content shrink during the all-category audit precedes it;
offset clamping is a supported inference from the sequence, not a claim about
XCTest's internal implementation. The analyzer's exact contrast-image capture
time is still unavailable. These observations neither prove the contrast report
wrong nor establish a passing production fix.

The independent bounded condition reproduces that order: title audit call at
1790872664.007922, shrink at .444584, offset 538 -> 55 at .448422, then -52 at
.508494; first callback at 1790872666.724061. Root/window observations expose why
its proposed isolation is invalid: root layout frame is `[0,132,402,708]` after
navigation-title collapse, but the accessibility ScrollView frame is still
`[0,62,402,812]`, overlapping the navigation bar `[0,78,402,54]`. ScrollGeometry
retains 70-point top / 34-point bottom insets. The same values occur in the control.
An available-size frame alone did not create a distinct physical viewport.

Apple's [scroll-view presentation](https://developer.apple.com/videos/play/wwdc2023/10159/)
distinguishes changing the scroll view's frame from resolving safe areas into
content margins. This supports measuring the real boundary instead of assuming
GeometryReader or safe-area padding removes underlap; it is not an audit waiver.

## Inspectable Evidence

`accessibility-viewport/{suppression,bounded}/` retains all exported attachments,
including full Xcode-exported screen recordings, before/after/callback screenshots,
trees, issue nodes, complete test activity, filtered app geometry stdout, result
summaries and build logs. `manifest.json` maps each attachment to its test and
timestamp. Text exports have trailing horizontal whitespace normalized for Git;
no events, times or findings were removed. Original xcresult bundles/exports remain
in `DerivedData/`. `audit-timeline.json` is a derived convenience join: latest
observed geometry at each test event, reset per app launch. Event logs remain
authoritative; PNG/MP4 attachments are unchanged exports.

- Suppression command pre-audit: `FAE8B3B7-2CA8-40C2-8514-05A534723501.png`
  visibly draws Trial text through the `16mm` navigation title. This is not an
  acceptable remedy even where its title audit passed.
- Its first callback, before element query:
  `1803860B-EAFF-4597-A16C-52CD63F77B8A.png`, already at content top.
- Bounded title: `1029EE2B-303E-4455-AB6C-BDD62AC4ADB4.png`; command:
  `5BBEB323-C473-4A06-BCBA-B1112B03A7B0.png`. Blurred text remains underneath chrome.
- Complete exported videos: control `3E3AFB21-6A3B-4988-A668-D49368D187CD.mp4`
  (36.982 s), suppression `DC73FD7D-D00A-4CEF-860D-3A8348490FF1.mp4` (32.085 s),
  bounded `773B794B-87D2-494D-AEBD-9A683600A6D3.mp4` (34.515 s). These are untrimmed
  Xcode exports, shorter than test-body wall time; neither video attachment time
  nor presentation timestamp is asserted to be the internal analyzer capture time.
  Sampled suppression-video frames corroborate the size sweep and return toward content top.

## Next Decisive Check and Acceptance Boundary

Both authorized counterfactuals are exhausted. No production code changed and no
actual-app rerun can be called a corrected-candidate gate. QA-13 remains failed;
default/largest light/dark, VoiceOver and Switch Control acceptance remain required.
The prior actual-app default failure remains valid. Media, Trial, billing and asset
evidence are unaffected; physical work remains deferred.

Smallest next check: in the **same** probe, observe the actual underlying
UIScrollView window frame/adjusted inset, then compare a normal outer vertical
padding boundary (not safe-area/content padding) against the intact stack.
Require runtime geometry and screenshots to show that its physical scroll viewport
really ends below navigation chrome before interpreting audits. This directly tests
the failed GeometryReader assumption with a frame-changing operation documented
by Apple, rather than another edge style. Keep every row reachable, the same sheet
and controls, all categories, and no explicit clipping/hidden-content modifier.
If real viewport separation is not demonstrated, reject that condition too.
This is a proposed engineering experiment, not a product choice or executed result;
it cannot establish acceptance merely by removing content from the audited screen.

## Exact Commands

Both used the same fresh derived-data root, preventing the prior stale discovery
case. `$SIM` below is the exact UUID above; system size/appearance were set before
execution. Result paths were unused.

```sh
xcodebuild -quiet -project Probes/SetupAccessibilityProbe/SetupAccessibilityProbe.xcodeproj -scheme SetupAccessibilityProbe -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/SetupProbe-ViewportFresh -resultBundlePath DerivedData/SetupProbe-Viewport-Suppression.xcresult -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackContainer -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackSuppressedEdges -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
xcodebuild -quiet -project Probes/SetupAccessibilityProbe/SetupAccessibilityProbe.xcodeproj -scheme SetupAccessibilityProbe -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath DerivedData/SetupProbe-ViewportFresh -resultBundlePath DerivedData/SetupProbe-Viewport-Bounded.xcresult -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackBoundedViewport -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

For each bundle, `xcrun xcresulttool export diagnostics --path <bundle>
--output-path <diagnostics>`, `export attachments --path <bundle> --output-path
<attachments>` and `get test-results summary --path <bundle>` retained the evidence.
After finalization/export, the owned simulator's text size was restored to `large`
and it was shut down. Read-only discovery found no booted simulators. No other
process, daemon or device was stopped. No no-mistakes run, push or publication
was started, and no required failed check was reclassified as passed.

The unaffected regression gate `sh Scripts/validate-local.sh` subsequently exited
0 at approximately 16:43Z: 115 module tests plus 17 receipt-study/process tests, asset-generator
build, requirement traceability (122 intake IDs / 72 clauses / nine invariants),
25-entry ZIP content comparison and unsigned simulator/device app builds.
`accessibility-viewport/local-validation.log` retains its output. Optional app UI
and StoreKit simulator variables were unset: this result does not rerun or waive
the failed accessibility gates. `App/`, `Packages/` and CI had no changes from
`08d4591`. Source/evidence SHA-256 checks and `git diff --check` also pass.
