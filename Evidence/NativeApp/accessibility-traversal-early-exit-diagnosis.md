# Early-Exit Real-App Traversal

Instruction 033 authorizes exactly one mechanics-only continuation of
[50c78df's incomplete pair](accessibility-traversal-progress-diagnosis.md).
Base `50c78dffbac5ef5bd64ddd6258e54332b5b2684f`; production and original sequential
UI suites are unchanged. Historical failures and physical deferral remain.

## Change and Predictions

The retained trace repeatedly queries already-contained Trial bounds, then
already-present disclosure existence across the 600-second limit. Five additive
diagnostic loops now exit on the first successful **fresh actual AX condition**:
camera hittability, title existence, title y400 within one point, row existence
and full reading-bounds containment. Limits remain 8/16/16/20/20; the existing
post-loop assertions/guards still reject failure to reach the target. Every drag
retains the measured no-progress snapshot/throw; no gesture failure is swallowed.

Ranked predictions: (1) eliminating redundant successful-condition queries allows
both arms to finish; (2) remaining AX/snapshot overhead still exhausts the bound;
(3) faster timing exposes unstable poses or stalled gestures, which existing
settlement/matching/no-progress assertions must reject. This deliberately changes
public query timing, so it is a harness efficiency correction, **not** a controlled
experiment identifying the accessibility audit's cause.

`early-exit/verify-source.mjs` mechanically compares the executed additive patch
with the preceding patch: only these five loop rewrites differ. Actual fresh
conditions are checked before each gesture; final guards/assertions remain after
bounded exhaustion. Original ten rows, completion events, consecutive settlement,
A/B match, every tree/screenshot, `.all` with every issue returned false and
no-progress throw are byte-identical. This source check is not an executed native
failure injection; any untriggered failure path remains unexercised in this run.

## Environment and Command

Owned iPhone 17 Pro simulator `AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`, x86_64,
iOS 26.5 (`23F77`), Xcode 26.5 (`17F42`), macOS 26.6.2. Portrait 402x874,
system XXXL/light readbacks; no global or simulator appearance/category writes.
Fresh actual native Form launch per arm, Journal > Start a Film > 16mm, no launch
arguments, actual unavailable Trial, A without audit then B unfiltered `.all`.
No artificial delay, production layout/content edit or app-window observer.

```sh
xcodebuild -quiet -project App/Immerse/Immerse.xcodeproj -scheme Immerse -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath DerivedData/Immerse-PairedTraversal -resultBundlePath DerivedData/Immerse-PairedTraversal-EarlyExit.xcresult -only-testing:ImmerseUITests/SetupTraversalDiagnosisTests/testPairedSystemLargestTraversal -test-timeouts-enabled YES -maximum-test-execution-time-allowance 1200 CODE_SIGNING_ALLOWED=NO test
```

Same timeout flags as both preceding runs: maximum 1200 does not override the
effective default 600-second case allowance. No second invocation is authorized.
Executed source hashes and full additive patch live in
`accessibility-traversal/early-exit/`. UI test SHA-256 is
`bd7dafa6756e3b544dc597a0db1b274ddaf8dfe58078c9c632573e0815deea18`;
production setup remains
`7287304aa8a76bc6c7bb78bec0883cb5f0f271de77e34cab02ecfe69d790d549`.
Shared-host load, fixed order and observer
timing limit interpretation; this bounded path cannot clear original failed
matrix/assistive checks or QA-13.

## Observed Result

**Completed bounded pair, one test passed in 426.038 seconds.** One selected run,
zero failures/skips/expected failures; xcodebuild exit 0. Test duration is below
the unchanged 600-second bound. Total test-operation time is 516.980 seconds,
including launch/finalization. UIKitToolbar runtime warnings remain retained.

| Required condition | Observation |
| --- | --- |
| Target, settlement, matching | Both y400 targets and consecutive settlement assertions pass. Every recorded pre-pose component has exactly zero A/B delta. |
| A ordinary traversal | All ten existence/hittability/full-containment assertions pass; all ten row snapshots and A-complete exist. |
| B all-category audit | Returns normally in 7.550 seconds, zero issue callbacks/caught errors. No category or issue filtered. |
| B traversal | All ten row assertions and snapshots pass, including disclosure, Subscription and Load; B-complete exists. |
| Progress | 27 completed drag records show movement or changed first-cell identity. No no-progress exception or bounded-exhaustion failure occurs; those native failure branches are not exercised by this successful run. |

Pre-invocation reading bounds `[0,156,402,668]`, viewport `[0,62,402,812]`,
navigation `[0,78,402,54]`, title `[32,400,199.667,63.333]`, field
`[32,471.333,338,126]`, Trial `[16,647.333,370,155.333]` match. Exact floats,
all twenty row rectangles, 27 gestures and timestamps are in `observations.json`.

| UTC, October 1 | Event |
| --- | --- |
| 18:20:13.959 | Selected case starts; A launch event 18:20:23.039. |
| 18:21:14.201 | A settled pre-invocation snapshot. No-audit invocation 18:21:16.193...195. |
| 18:21:34.616...18:23:46.953 | Ten A row records; A-complete 18:23:51.708. |
| 18:23:58.280 | Fresh B launch; pre-invocation snapshot 18:24:42.974. |
| 18:24:44.877...52.427 | B `.all` invocation, no findings. |
| 18:25:14.918...18:27:13.928 | Ten B row records; last snapshot ends 18:27:18.435, B-complete 18:27:18.437. |
| 18:27:19.998 | Case passes; no runner restart or duplicate test. |
| 18:28:19.052 | xcodebuild finalizes. |

The trace confirms early exit retains real queries. For B Trial, the final drag
record at t=374.25 is followed by the actual containment query, final
existence/hittability/containment assertion and event queries; the row record
arrives at t=376.93 instead of twenty repeated post-success condition checks.
This supports removal of the diagnosed harness overhead, not a controlled speed
benchmark: shared-host one-minute load changed from 75.27 before to 24.91 after,
and both public query timing and gesture history differ from earlier attempts.

Twelve PNGs were visually inspected: description, title field, Trial, disclosure,
Subscription and Load in **each arm**. Together they cover all ten required
items per arm, legible when brought into their reading positions. Previously
scrolled text still blurs beneath native navigation; no persistent clipping of
the fully exposed items is demonstrated. This supports ordinary readability and
reachability for this exact path only. No Load tap, capture, purchase, VoiceOver
or Switch Control interaction is proved by it.

The B audit did not reproduce a finding in this completed pair. This does not
explain historical failures or establish an Apple limitation/false positive.
No production correction is identified or applied. Original sequential
default/largest light/dark failures, assistive checks, populated screens and
QA-13 remain open for subsequent direction. No required gate is waived.

## Evidence and Recovery

`early-exit/` retains source/patch, equivalence check, complete activity JSON,
summary/details, timestamped row/pose events, 24 tree/screenshot pairs and
lossless compressed test/app stdout. Reproduce observations with `node
Evidence/NativeApp/accessibility-traversal/early-exit/summarize.mjs`.
No screen-recording attachment is present in this run's exported manifest or
activity list; **no video evidence is claimed**. All preceding failed/missing
recordings remain historical evidence. PNGs/binary snapshots/raw compressed
stdout remain unchanged; exported text trailing whitespace may be normalized.

The additive class is removed after retaining its exact patch; production,
packages, project and original suites remain byte-identical to `50c78df`.
The owned simulator is shut down. No device/signing/account, purchase, global
setting, media deletion or release action occurred. Evidence-only changes require
no production rollback; existing media/backup recovery limitations remain.
Full-v1 readiness is not established. Firstmate owns subsequent native-matrix
direction and eventual no-mistakes validation; this run is not CI or that pipeline.

## Scoped Verification

- `node Evidence/NativeApp/accessibility-traversal/early-exit/verify-source.mjs`:
  pass, only five loops differ from the preceding patch; all safeguards retained.
- `git diff --exit-code 50c78df -- App Packages .github Probes Scripts adr` and
  `git apply --check Evidence/NativeApp/accessibility-traversal/early-exit/diagnostic.patch`:
  pass. Base plus patch reconstructs the executed test SHA-256. Original source
  equality and twenty distinct contained/completed row records are checked in
  `source-restoration-check.txt`.
- Observation regeneration/content comparison and local Markdown links: pass.
- `sh Scripts/verify-document-package.sh`: pass after `zip -r -X -q`, with archive
  listing and extracted-tree content diff. `sh Scripts/verify-requirement-map.sh`:
  pass, 122 intake IDs, 72 clauses, nine invariants; traceability, not acceptance.
- Scoped `artifacts.sha256` verification and `git diff --cached --check`: pass.
  No unrelated software suite, device action, no-mistakes, push or CI run.
