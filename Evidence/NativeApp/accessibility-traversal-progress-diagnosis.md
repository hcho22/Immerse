# Progress-Checked Real-App Traversal

Firstmate 032 authorizes one mechanics-only continuation of the [incomplete
paired traversal](accessibility-traversal-diagnosis.md). Base
`1a69b3d997ce200f856b3bd0e25c25da45a81ed4`; production app and original sequential
UI suite remain unchanged. The initial failures, 600-second timeout and missing
recording remain historical evidence, not replaced results. No phone/signing work.

## Hypotheses and Change

The retained stdout shows a 14-point title correction followed by a remaining
10-point correction, then repeated ineffective 10-point gestures. Other rows
similarly stop just outside the diagnostic inset. Ranked predictions:

1. Lost initial gesture travel: compensating those ten points should move the
   remaining distance and reach the original y=400/inset targets.
2. Wrong gesture target: compensation still produces no measured content motion;
   stop immediately with the observed before/after frames.
3. Moving layout: motion occurs but consecutive settlement or matched A/B frames
   fail. Do not interpret an unsettled pair.

Only the additive diagnostic's drag helper changes: add ten signed points before
the existing 220-point clamp, keep the same ordinary gesture origin, velocity,
press/hold parameters, then compare the first visible cell's label and frame.
If the label is unchanged and vertical movement is at most one point, retain a
failure snapshot and throw `ScrollFailure.noProgress`. This is an empirical test
mechanic, not a claim about a documented UIKit threshold. Every existing target,
settlement, matching, full-visibility assertion, row, capture/query sequence and
unfiltered `.all` handler is retained. No app-window drawing, delay or layout edit.

## Execution Identity

Xcode 26.5 (`17F42`), iOS 26.5 (`23F77`), task-owned x86_64 iPhone 17 Pro
`AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, portrait, 402x874. System readbacks already
showed accessibility XXXL/light; no settings write was needed. Empty Journal,
actual unavailable Trial and native Form, fresh launch A then B, no launch override
or earlier audit. Source hashes and additive patch are in
`accessibility-traversal/progress-correction/`; UI test SHA-256
`1269c601f3d9a9f7b3085ee84b2fa56452d978311b9bbe32bd731b61981a9478`.
The production setup hash remains `7287304aa8a76bc6c7bb78bec0883cb5f0f271de77e34cab02ecfe69d790d549`.

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath DerivedData/Immerse-PairedTraversal -resultBundlePath DerivedData/Immerse-PairedTraversal-Progress.xcresult -only-testing:ImmerseUITests/SetupTraversalDiagnosisTests/testPairedSystemLargestTraversal -test-timeouts-enabled YES -maximum-test-execution-time-allowance 1200 CODE_SIGNING_ALLOWED=NO test
```

Same timeout configuration as the preceding run: the maximum flag is **not** a
default allowance increase; the previously observed effective 600-second case
bound is not enlarged. Only one invocation is authorized. Shared-host load and
fixed order remain limitations. Original sequential audits are not replaced by
this diagnostic; QA-13 requires more than this screen and no waiver is implied.

## Observed Result

**Incomplete pair; no production correction or acceptance.** One selected test,
one run, zero passes, one failure, zero skips; xcodebuild exit 65. The sole test
failure is the unchanged **600-second execution allowance**, not a visibility,
pose, no-progress or audit assertion. UIKitToolbar warnings remain retained.

| Condition | Observed result |
| --- | --- |
| Target and settlement | Both title origins reach y=400; consecutive settlement and A/B comparison assertions pass. Maximum pre-pose component delta is floating-point roundoff, `1.42e-14` points. |
| Ordinary A traversal | All ten required rows pass existence, hittability and full containment; ten snapshots and the A-complete record exist. |
| B audit | `.all` returns normally in 5.963 seconds, with zero issue callbacks and no caught error. This one invocation does not reproduce the earlier contrast finding. |
| B traversal | Seven rows through actual unavailable Trial pass and have completed snapshots. Disclosure, Subscription and Load have no completed row records; no B-complete event. |
| Gesture progress | 24 completed drags have measured cell movement or a changed first-cell label. No no-progress guard fires. One later drag is interrupted during timeout handling and has no after-frame record. |
| Pair acceptance | Fails the required two ten-row completion condition. Neither the historical failed gates nor QA-13/H-UX is cleared. |

The shared reading bounds are `[0,156,402,668]`, native viewport
`[0,62,402,812]`, navigation `[0,78,402,54]`, title
`[32,400,199.667,63.333]`, field `[32,471.333,338,126]`, and Trial
`[16,647.333,370,155.333]`. The source-bound `.all` success at y400 is a
different observation from the preceding y410 failure, not proof that ten points
caused the audit difference. Gesture history, fixed arm order, AX/screenshot
observation and shared-host load remain confounds.

| UTC, October 1 | Retained event |
| --- | --- |
| 18:01:10.888 | Selected case begins. |
| 18:02:07.023 | A matched-pose snapshot begins; no-audit invocation at 18:02:08.598. |
| 18:02:37.767...18:06:16.281 | A's ten passing row records. A-complete at 18:06:20.624. |
| 18:06:26.675 | B fresh launch, no arguments. |
| 18:07:15.865 | B pre-audit snapshot begins. |
| 18:07:17.443...23.406 | Unfiltered B audit runs and returns; no issues. |
| 18:11:01.741 | Seventh B row, Trial, passes. Its tree/screen snapshot ends 18:11:08.013. |
| 18:11:10.756 | Disclosure-existence activity carrying the ten-minute timeout begins. Diagnostic attachment finalizes at 18:11:15.981. |
| 18:11:21.634...636 | XCTest's automatic runner restart executes zero tests, not another pair. |
| 18:12:17.827 | xcodebuild finalizes; 688.441-second test-operation time, exit 65. |

The remaining limit is visible in both source and stdout: `for ... where`
continues evaluating its condition through every bounded iteration even after
the row is present/contained. For example, after the last completed drag at
18:10:46.926, the trace repeatedly queries the already-positioned Trial bounds
before its passing record at 18:11:01.741. After its snapshot, repeated disclosure
existence checks cross the timeout; the row is not demonstrated absent. This is
query overhead, not repeated ineffective gestures or a proven app hang. The
condition/capture sequence was deliberately retained under 032; no loop rewrite,
timeout extension, second run or new variant was performed. Optimizing those
loops would change diagnostic query timing and requires a separate steer.

Ten PNGs were inspected: both before poses; A description, title field, Trial,
disclosure, Subscription and Load; B Silent capture and Trial. Together they
show all ten A items legible at their reading positions and the sampled B items
legible, without establishing assistive interaction or all transient states.
Already-scrolled labels blur beneath native navigation at other poses; that is
not evidence of persistent clipping of a fully exposed row. No reproducible
ordinary-traversal production defect or smallest production correction is
established. The incomplete B traversal prevents the requested pair conclusion.

## Evidence and Containment

All new exports are scoped to `accessibility-traversal/progress-correction/`:
summary, test details, full activities, manifest-indexed attachments, lossless
compressed test/app stdout, source hashes, patch and mechanical source-equivalence
check. Reproduce derived rows/poses/events with `node
Evidence/NativeApp/accessibility-traversal/progress-correction/summarize.mjs`.
`observations.json` contains the exact per-row frames and gesture records.
`artifacts.sha256` covers only this continuation; historical inventories remain
unchanged. Exported text trailing whitespace may be normalized for Git; compressed
raw stdout, images and binary snapshots remain unmodified.

Recording `BF2FF7B5-696E-4F40-8DE2-D74613F45FE6` is a 60-byte error payload,
**not video**: `Unexpected Error: Finished test run with pending attachment.`
The missing recording is retained, not replaced by a claimed complete video.

The temporary additive class was removed after retaining its patch. Production
sources, packages, project and original UI suites remain byte-identical to
`1a69b3d`. The task-owned simulator is shut down; no global settings, phone,
signing, purchase, media deletion or release operations occurred. No new feature
flag or production rollback is needed for this evidence-only change. Previous
media/backup recovery limitations and physical-test deferral remain unchanged.
No further diagnostic variants are authorized by 032. Firstmate must determine
the next bounded scope; this report neither requests a product exception nor
claims full-v1 readiness.

## Scoped Verification

- `git diff --exit-code 1a69b3d -- App Packages .github Probes Scripts adr`:
  pass after removing the additive test; no production/original-suite change.
- `git apply --check Evidence/NativeApp/accessibility-traversal/progress-correction/diagnostic.patch`:
  pass. Reconstructing the test from base plus patch matches the executed SHA-256;
  `source-restoration-check.txt` retains that check.
- Derived observation regeneration/content comparison: pass; ten A and seven B
  contained rows, 24 completed drags, zero issue records, missing B completion.
- `sh Scripts/verify-document-package.sh`: pass after `zip -r -X -q`; archive
  listing and extracted-tree content diff retained in `document-package-check.txt`.
- `sh Scripts/verify-requirement-map.sh`: pass, 122 intake IDs, 72 clauses,
  nine invariants; coverage only. Local Markdown links also pass.
- Artifact SHA-256 verification and `git diff --cached --check`: pass before
  commit. No unrelated software suites, physical checks, no-mistakes or CI run.
