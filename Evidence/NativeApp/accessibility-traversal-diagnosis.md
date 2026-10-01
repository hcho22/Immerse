# Paired Real-App Traversal

Firstmate instruction 030 authorizes one comparison after its independent read-only
review. Base `241dafd6a4bc42b98078a19f83674358a4f67eed`; production Form source
unchanged (`CameraCatalogView.swift` SHA-256
`7287304aa8a76bc6c7bb78bec0883cb5f0f271de77e34cab02ecfe69d790d549`).
No padded app patch, draw-only probe, Trial substitution, audit category filter,
artificial settling delay or native app-window screenshot observer is added.

## Prediction and Method

A persistent user-visible clipping/masking/scaling defect should appear in ordinary
Arm A when the affected row is fully exposed. Clean A with failing B would
disconfirm that explanation for this bounded state, not establish a framework
false positive or accept QA-13. A failure visible in A would justify only a
demonstrated local correction followed by the affected original gates. Failure
not reproducing without earlier audits would be a history difference, not a new
pass for the sequential suite. Unmatched poses or missing arms are inconclusive.

Current Form app, actual empty Journal and unavailable Trial, pushed path Journal
> Start a Film > Choose a Camera > 16mm. Fresh launch per arm, A then B. System
accessibility XXXL/light; no launch arguments or earlier audit. First bring the
Film title to y=400 with ordinary bounded drags. Compare consecutive public
accessibility frames for settlement and both pre-invocation poses to one point,
including native collection viewport/navigation and exposed label/control frames.
This tolerance is a diagnostic matching condition, not a new product budget.
Frame containment is separate from hittability and from visual legibility.

Both arms retain a tree/screenshot before and after the invocation position.
A makes no audit call. B calls `performAccessibilityAudit(for: .all)` with an
issue handler returning false for every issue, then continues the same traversal.
No issue is waived. Each arm brings description, Silent capture, orientation
heading/picker, title heading/field, actual Trial label, disclosure, Subscription
and Load row into the reading area and retains identical tree/screenshot steps.
The reading area intersects the actual collection/window and leaves space below
native navigation and above the home region. It is not a changed app viewport
and says nothing about private analyzer transitions or unexposed rows.

The diagnostic is an additive test patch, retained in
`accessibility-traversal/paired/diagnostic.patch`, not an alteration to the
original sequential suite. The system-selected experiment is deliberately not
the original largest test's launch-override condition. Ordered arms, shared-host
load, framework screenshots and public AX queries remain possible observer/history
effects; no one-pair result establishes sole causality.

## Environment and Command

Xcode 26.5 (`17F42`), macOS 26.6.2, task-owned iOS 26.5 (`23F77`) x86_64
iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, portrait,
402x874 window. System `simctl ui` readback records XXXL and light in `paired/`.
The actual setup's menu picker and large text provide target-side size evidence;
there is no injected preferred-size launch argument. A separate attempted
`defaults read -g UIPreferredContentSizeCategoryName` returned no such key; that
is not used to infer an app preference or override the successful system readback.

```sh
xcrun simctl boot AA6AD12A-9D0E-4948-ABD2-760AA97B6A60
xcrun simctl bootstatus AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 -b
xcrun simctl ui AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 appearance light
xcrun simctl ui AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 content_size accessibility-extra-extra-extra-extra-large
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath DerivedData/Immerse-PairedTraversal -resultBundlePath DerivedData/Immerse-PairedTraversal-2.xcresult -only-testing:ImmerseUITests/SetupTraversalDiagnosisTests/testPairedSystemLargestTraversal -test-timeouts-enabled YES -maximum-test-execution-time-allowance 1200 CODE_SIGNING_ALLOWED=NO test
```

The initial fresh build used result `Immerse-PairedTraversal.xcresult`. It compiled
but failed before the title pose: Form virtualized offscreen rows, so the initial
test's Trial-existence check failed and querying the absent title's frame stopped
execution. No arm comparison or audit ran. Raw summary/activity/attachments and
source hashes remain at `accessibility-traversal/`. The corrected diagnostic
scrolls absent rows into the native accessibility tree before querying frames
and records only currently exposed pose nodes. This changes test mechanics, not
production layout/content or any required assertion/audit category.

## Results and Execution Progress

**Incomplete comparison, no accepted correction.** Final bundle: exit 65,
one selected/executed test, zero passed, one failed, zero skipped. The original
suite was not rerun or modified. `paired/test-details.json` reports one test run,
600 seconds and **Test exceeded execution time allowance of 10 minutes**.
The command's `-maximum-test-execution-time-allowance 1200` did not set the default
allowance to 1200. Neither 180 nor 1200 seconds describes the observed case bound.
The worker did not extend a timeout or start a duplicate run after instruction 031.

| UTC, October 1 | Observed event |
| --- | --- |
| 17:39:48.557 | Selected test case started, per result details and activities. |
| 17:39:55.098 | A launched, no arguments. |
| 17:41:03.076 | A pre-invocation pose snapshot. |
| 17:41:04.772...774 | A invocation position, no audit. |
| 17:42:10.110...17:48:25.874 | A records all ten traversal rows, but five fail the containment condition below. |
| 17:48:29.153 | A completes ten recorded rows, then terminates its app. |
| 17:48:34.033 | B fresh app launch, no arguments. |
| 17:49:31.551 | B pre-invocation pose snapshot. |
| 17:49:32.908...40.572 | B executes `.all`; one contrast issue is retained. |
| 17:49:45.099 | B post-audit snapshot ends. |
| 17:49:48.419 | While locating description for B traversal, the activity carrying the timeout begins. B records zero completed rows; no B-complete event. |
| 17:50:20.270 | Timeout diagnostics/spindump attachment finalized. |
| 17:50:24.507...510 | XCTest automatically restarts its runner and executes **zero tests**. This is neither an agent-started duplicate nor a passing paired run. |
| 17:51:11.271 | xcodebuild finalizes; test operation elapsed 689.204 seconds, exit 65. |

Instruction 031's bounded inspection retained the exact process/command and owned
runtime queries in `paired/process-progress.txt` and `runtime-*-progress.log`.
The selected case was actually executing, not stuck before test launch. The
quiet execution log hid live events; those are now in `test-stdout.txt.gz`, full
activity JSON and timestamped attachments. A separate console-log extraction
reported no available console log; diagnostics export supplied the raw stdout.
No debugger-version cause is established. UIKitToolbar warnings remain retained.
No shared daemon, unrelated process, global setting or physical phone was changed.

## Pose and Traversal Observations

Both first-scrolled title poses settled at **y=410**, not the helper's requested
y=400; both target assertions fail and remain failed. However, the A/B pose
comparison and consecutive settlement assertions pass: maximum recorded component
difference is floating-point roundoff (`1.42e-14` points), not a measurable mismatch.
Shared viewport `[0,62,402,812]`, navigation `[0,78,402,54]`, reading bounds
`[0,156,402,668]`, title `[32,410,199.667,63.333]`, field
`[32,481.333,338,126]`, and unavailable Trial `[16,657.333,370,155.333]` match.
`paired/observations.json` is reproducible with `node
Evidence/NativeApp/accessibility-traversal/summarize.mjs`; it derives counts,
timestamps and pose deltas from exported attachments, not assumptions about tests.

A's recorded rows show five successful containment assertions: Silent capture,
orientation heading/picker, title heading and actual Trial label. Five fail:
description starts at 154 rather than inside the inset reading area's 156;
title field, disclosure, Subscription and Load end at 826 rather than at/before
824. These two-point inset violations are retained as diagnostic failures, not
converted to passed assertions after looking at screenshots. They are also not
evidence that the native window clips those glyphs: the window ends at 874 and
native navigation ends at 132. The conservative inset was a test condition.

Activity logs show repeated short residual drags without reaching the requested
target: the title remains ten points short, and inset correction loops similarly
repeat ten-point gestures. The helper exhausted its bounded iterations. This is
an observed positioning problem; touch-slop/non-effective small drags are a
hypothesis, not an identified UIKit mechanism. It also consumed substantial case
time before B began. The interim suggestion that full-tree/frame capture alone
explained the long runtime was incomplete; the final history shows these repeated
corrections and the effective 600-second case limit.

Ten retained PNGs were visually inspected: both pre-invocation screens, B after,
and A description, Silent capture, title field, Trial, disclosure, Subscription
and Load reading screens. They span all required text/controls. At its reading
pose, Silent capture is complete and legible; the other required text is readable
at the corresponding retained positions. At other poses, already-scrolled content
is blurred beneath native navigation. That does not show a persistent defect of
the fully exposed row. Screenshots do not replace the failed containment checks,
complete B traversal, assistive interaction or every transient state.

B's issue is `type=1`, **Contrast failed for SwiftUI.AccessibilityNode**,
`Silent capture`. Its later queried element frame is `[60,41,308,63.333]`, above
the reading pose/partly outside the collection's top. It is not a documented
analyzer capture-time frame. The issue, automatic screenshots and returned-false
handler are preserved. Before/after title poses match despite the intervening
issue; no claim about the auditor's internal bitmap or false positives follows.

Thus the no-earlier-audit B call **did reproduce a contrast finding**, although
on a different label from some historical sequential runs. We cannot report the
requested full paired traversal as completed: B's ten rows are absent, and A's
inset assertions did not all pass. No demonstrated production correction follows
from this partial comparison. All original failures and required matrix remain.

## Retained Evidence and Next Check

`paired/attachments/manifest.json` indexes every export. The screen-recording
attachment `51FEA07B-8A2D-42BE-B053-042F7B23FF22` is **not a video**: its bytes say
`Unexpected Error: Finished test run with pending attachment.` It is retained as
that missing-evidence error. No complete paired recording is claimed. The earlier
incomplete attempt's actual MP4 remains separately retained. Raw test/app stdout
is compressed losslessly; text export trailing whitespace may be normalized for
Git, without changing PNGs or binary snapshots. Result bundles remain local under
ignored DerivedData. Artifact inventory hashes bind the portable report.

The additive diagnostic patch is retained, then removed from the ordinary UI
test source so the manually configured XXXL experiment cannot accidentally become
a default-size CI case. The original `JournalFlowTests.swift`, production sources
and packages are byte-identical to `241dafd`; `git apply --check` verifies the
retained patch remains applicable. No original assertion or test category is
removed. No new native run follows this incomplete comparison.

Smallest proposed next check for Firstmate: correct **only diagnostic scrolling**
to make measurable progress into the same full-visibility bounds (account for the
observed ineffective residual gesture), retain original pose/containment assertions
and unchanged `.all`, and complete this same A/B traversal within its existing
effective bound. Fail promptly on no movement instead of spending twenty repeated
no-progress gestures per row. Do not raise timeouts, relax bounds to force a pass,
add captures/delays or modify production to accommodate this harness. Confirm both
ten-row completion records and matching settled pose before interpreting the pair.
This recommendation is not executed or accepted here; the repeated incomplete
diagnostic is returned to Firstmate for focused direction.

Scoped checks: native diagnostic compiled and executed (failed as recorded);
original-source comparison and patch applicability pass; derived observations,
artifact hashes, requirement-map coverage, ZIP listing/content comparison and
whitespace checks pass. Unrelated package/native app suites are not rerun for this
diagnostic-only checkpoint. Owned simulator shut down, invocation completed, no
physical operations. The [manual handoff](manual-validation.md), committed as
`d8a9eae`, separately records hardware/authority gaps. QA-13 and full-v1 readiness
remain unaccepted, with no CI, no-mistakes or release claim.
