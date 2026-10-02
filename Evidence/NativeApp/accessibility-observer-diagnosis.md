# Window Capture Timing Countercheck

Status: authorized bounded follow-up (Firstmate 027) concluded at the first
countercheck: capture enabled passes, capture disabled fails. Base `1951294`.
No production change, accepted correction, hardware action or waiver is implied.
The previous physical-frame report and all contradictory results remain intact.

## Predictions Before Execution

Ranked hypotheses and sequential tests:

1. Synchronous app-window PNG capture materially alters audit timing. Keep the
   same padded probe, public geometry callbacks, labels/fonts/colors, sheet root
   and all top/title/command audit categories. Compare capture enabled against
   disabled in one build, at system largest Dynamic Type and light appearance,
   matching the previous passing condition. Prediction: the disabled condition
   remains clean if that result is independent of this observer. A failure stops
   the later navigation/Trial comparisons in this follow-up.
2. Only if disabled stays clean, a pushed setup and Back navigation changes the
   observed viewport/audit outcome. Match the real catalog-to-setup path while
   keeping the unused Trial presentation, content and capture-disabled state.
   Prediction: it stays clean if navigation is not the missing difference.
3. Only if that stays clean, replace only the constant unused-Trial presentation
   with the actual app's existing unavailable status text. Prediction: it stays
   clean if this content/geometry difference is not the missing cause. This
   presentation-only probe has no entitlement authority or loading/capture path.

Default/largest and light/dark comparisons will be added only where they resolve
the current causal distinction. No audit category/issue filter, label removal,
font/content-height cap, clipping modifier or weakened assertion is permitted.
No production correction is inferred from a probe pass.

## Stage 1 Source

One `-disableWindowCaptures` branch returns before window drawing/PNG encoding or
file writes. It keeps the already queued main-thread callback, read-only native
geometry observation and a timestamped `size-screen-disabled` category record.
Enabled behavior is unchanged. Normal XCTest pre/callback/after screenshots,
trees, audit-call timestamps and any exported recordings remain enabled in both
conditions. The row-reachability helper is shared without changing its assertions;
the new disabled variant must still fit each of twelve rows fully in the viewport.

This is probe-only code. Production app/packages/harness and all rights, Trial,
privacy, capacity, persistence and disclosure rules are unchanged.

## Stage 1 Execution

Xcode 26.5 (17F42), iOS 26.5 (23F77), x86_64 iPhone 17 Pro, task-owned simulator
`AA6AD12A-9D0E-4948-ABD2-760AA97B6A60`; light appearance and system accessibility
XXXL. Source identity is `accessibility-observer/stage-1/source.sha256` on base
`1951294`. A fresh derived-data directory avoids the previously documented
new-test-discovery problem; actual nonzero test execution remains required.

```sh
xcrun simctl boot AA6AD12A-9D0E-4948-ABD2-760AA97B6A60
xcrun simctl bootstatus AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 -b
xcrun simctl ui AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 appearance light
xcrun simctl ui AA6AD12A-9D0E-4948-ABD2-760AA97B6A60 content_size accessibility-extra-extra-extra-large
xcodebuild -quiet -project Probes/SetupAccessibilityProbe/SetupAccessibilityProbe.xcodeproj -scheme SetupAccessibilityProbe -destination 'platform=iOS Simulator,id=AA6AD12A-9D0E-4948-ABD2-760AA97B6A60' -derivedDataPath DerivedData/SetupProbe-ObserverFresh -resultBundlePath DerivedData/SetupProbe-Observer-Largest-Light.xcresult -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackOuterPadding -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testStackOuterPaddingWithoutWindowCaptures -only-testing:SetupAccessibilityProbeTests/SetupAuditTests/testPaddedRowsRemainFullyReachableWithoutWindowCaptures -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 CODE_SIGNING_ALLOWED=NO test
```

No unrelated package/study tests or generic app builds are rerun for probe-only
changes. The affected native probe compilation/audits, row check, exact source
and artifact inventories, requirement map, ZIP content comparison and whitespace
checks are the scoped gates. These do not replace full-v1 or production UI gates.

## Observed Results

The bundle finalized with exit 65, **two passed / one failed / zero skipped**.
The failed test contains two contrast findings; this is not two failed test cases.
Execution on October 1, 2026, 17:13:50-17:17:22 UTC:

| Selected case | Outcome |
| --- | --- |
| Capture-disabled full-row reachability | Pass, 104.272 s; each of twelve labels/controls fits fully in the scroll viewport after ordinary user scrolling. |
| Padded, window capture enabled | Pass, 62.107 s; all-category top/title/command audits. This independently repeats the prior instrumented pass. |
| Identical padded layout, window capture disabled | Fail, 45.530 s; top clean, title description contrast, command unused-Trial label contrast. |

The conditional prerequisite for navigation/Trial comparisons was not met, so
neither was implemented or executed. No default-size/dark repeat is needed to
demonstrate this specific divergence from the former largest/light pass. This is
not default/dark coverage or a waiver of those eventual actual-app gates.

`stage-1/audit/93C7EF09-57F3-47A6-BB3C-E2F54CAB0F97.txt` identifies the title
finding: `Deliberate framing, finer grain`, later queried frame
`[32,506.7,302.7,187.3]`. `269CEEAF-FAFB-4B9D-A5FB-190F2CD1F934.txt` identifies
the command finding: `One Trial Film on this iPhone`, later queried frame
`[38.7,1354.7,326.7,187.3]`. Both are contrast (`auditType=1`). The callback/query
frames are not the analyzer's unobserved internal capture time or viewport.

## Geometry and Timing

Both conditions retain actual padded scroll frames `[0,221,402,603]` and
`[0,200,402,624]` through the size sweep, with zero adjusted insets. There are
499 capture-enabled and 502 disabled main-scroll observations. Joining each with
the latest preceding 16mm native navigation frame yields a positive 12-to-16-point
gap, 16 points when settled. These are sequential public observations, not
simultaneous samples or proof of every intermediate frame.

Enabled records contain 36 window PNGs. Disabled records contain zero window
captures and 36 `size-screen-disabled` callbacks, establishing the intended
execution difference. Enabled main-queue capture/draw/encode/persistence duration
is 0.363-0.757 s, median 0.446 s (`time - captureStart`). The prior run's lower
duration remains separately recorded. `host-load.txt` records load averages
101.97 / 54.08 / 39.42 during this run; shared-host load is a confound, not a
reason to discard failures or an iPhone performance measurement.

| Observation | Enabled | Disabled |
| --- | --- | --- |
| Top audit call scroll offset y | 0 | 0 |
| Title audit call offset y | 671.333 | 681 |
| Title audit call Film title frame y | 523.667 | 514 |
| Command audit call offset y | 1449 | 1452 |
| After title/command size sweep offset y | 102 | 102, already before the first failure callback |

Both use ordinary XCTest swipes; their pre-audit scroll poses are close but not
identical. The enabled title audit takes 9.629 s call-to-return; the disabled first
title callback arrives after 3.190 s. Disabled title callback enters at epoch
1790875022.452441; its screenshot returns 0.298 s later, its tree 1.056 s later,
and its issue query 1.969 s later. The native logs already place the viewport near
the top at callback entry. Timing/position differences remain material; do not
attribute the failure solely to capture latency from this single ordered pair.

Visually inspected enabled title-pre `1CAE3B08-DF38-44AD-8246-ED9B8B3CCE14.png`,
disabled title-pre `A805FEE8-6C82-47CC-9638-44DAB0F794F8.png` and disabled callback
`6A9D2765-91DB-41C7-86C0-231EFF5A670E.png` confirm this pose change without showing
text through the 16mm header. They do not establish the analyzer's pixel sampling.

Reproduce the chronological join, counts and timings with:

```sh
ruby Evidence/NativeApp/accessibility-observer/summarize.rb > DerivedData/observer-summary.json
diff -u Evidence/NativeApp/accessibility-observer/stage-1/observation-summary.json DerivedData/observer-summary.json
```

The script uses the fixed 402-point main viewport width for this pinned simulator;
it is a bounded evidence calculation, not an app abstraction or cross-device test.

## Earliest Divergence and Next Check

The first audit-result divergence is the capture-disabled **title** audit, before
changing navigation or Trial text. Thus the prior passing probe does not establish
that outer padding fixes the uninstrumented app. Physical separation and row
reachability are observed, but they are insufficient accessibility acceptance.
No production patch is made; reintroducing diagnostic captures or artificial
delays into production to obtain a green audit would not be a valid correction.

One smallest next decisive check, proposed but **not executed**: in the same
padded probe compare capture-disabled against a draw-only condition that retains
`drawHierarchy(afterScreenUpdates: true)` but removes PNG encoding and file writes.
Keep geometry, normal XCTest evidence and all categories unchanged. Prediction:
if drawing/render synchronization (or its own cost) is sufficient for the prior
pass, draw-only remains clean; failure would show that drawing alone is not
sufficient. This distinguishes the capture stages without adding arbitrary
blocking delays or claiming to know the analyzer's internals. Preserve exact
pre-audit offsets/order/load and all contradictory outcomes in that comparison.

## Retention and Limits

`stage-1/` retains exact source hashes, completed summary, full app/test stdout,
geometry, the reproducible joined observations and every exported attachment.
Full verbose app stdout is losslessly compressed as `app-stdout.txt.gz` (263,400
lines when decompressed); `gzip -t` passes and extracting its geometry reproduces
`geometry.log` exactly. It retains the earlier UIKitToolbar hierarchy warning,
which is not dismissed or established as the cause here.
`enabled-size-screens/` contains the 36 generated window images for launch UUID
`24911B50-4710-4723-9C13-F1F9A7F82CBE`. Xcode exports the failed disabled recording
`28B7AF4A-E3FE-4CD7-86DA-A7A464056513.mp4`; it did not export video for either
passing test. Their normal pre/after or per-row screenshots remain retained.
Raw xcresult is local at the exact path above; trailing horizontal whitespace in
portable text exports is normalized for Git, without modifying PNG/MP4 content.

The owned simulator was restored to light/default size and shut down after the
completed run. Production app/packages/harness are unchanged from `1951294`.
Only the probe callback switch/tests and evidence/docs change; no permissions,
personal media, Keychain, Photos, billing, account, hardware or service operations
occurred. Existing full-v1 and production accessibility gaps remain unaccepted.
No no-mistakes run, PR, push, CI-ready or release action occurred.

## Scoped Verification

| Gate | Observed outcome |
| --- | --- |
| Native probe compilation and selected tests | Compiled; all three selected cases executed. Two pass, one fails as recorded above. No zero-test success or skipped category is accepted. |
| `ruby -c Evidence/NativeApp/accessibility-observer/summarize.rb` and reproduction/diff above | Pass; regenerated structured observations exactly match the retained summary. |
| `shasum -a 256 -c Evidence/NativeApp/accessibility-observer/stage-1/source.sha256` | Pass; current probe source/configuration matches the executed build input. |
| `sh Scripts/verify-requirement-map.sh` | Pass; all 122 intake IDs, 72 clauses and nine invariants remain covered. No task or clause is newly accepted. |
| Regenerated `zip -r -X` package and `sh Scripts/verify-document-package.sh` | Pass; listing and content comparison retained in `document-package.log`. |
| Production equality, evidence hash inventory and `git diff --check` | Pass; no production source modification or extra acceptance claim. |

The 132 unaffected package/study tests and unsigned generic app builds were not
rerun, as instructed for this probe/evidence-only checkpoint. Their previous
results remain bound to their original candidate and do not erase the current
required accessibility failures. Default/largest light/dark actual-app acceptance,
hardware, assets, product choices and manual v1 validation remain outstanding.
