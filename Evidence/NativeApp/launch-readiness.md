# v1 Launch Readiness and Validation Handoff

**Current receipt/read scope (039):** Firstmate explicitly corrected its
engineering assertion that every recovery must match the pending capture's
receipt identity. Direct publication from unused eligibility still requires the
exact post-write readback. Recovery may instead use a valid existing consumed
record from an authoritative correctly scoped same-item read plus the persisted
Film grant, without claiming acknowledgment of the pending write. Captain
saved-only debit, no second new Trial Film/no refund, restored-Film rights and
independent destination entitlement are unchanged. No marker/protocol/schema or
shipping source change was necessary.

`Evidence/ReceiptFaultMatrix/039/README.md` records the query/type/caller review,
source-bound current tests, 23 runtime and six adapter passes, seven hosted iOS
passes and one process-exit method covering nine histories. Receipts are injected;
native media and persistence are real. The four direct identity/date mismatches
reject, repaired exact data recovers once, and authoritative existing-grant
permutations preserve restored rights without receipt mutation. These are partial
TRI-03/04/09, ARC-03/05/11/12, CAP-08, QA-12/15 and FR-04/21 software evidence,
not physical Keychain, backup or atomic durability acceptance.

Historical `036/README.md` and `037/README.md` remain factual failed tests of the
stronger engineering assertion; their source and histories are retained, not
retroactively green or waived captain criteria. `038/README.md` retains the
disproved marker, five equal-input pairs and arbitrary fabricated-read
counterexamples. That expanded trust/fault model is unsupported under instruction
039, not a new passed guarantee. No captain requirement or original ADR changed.

Draft sample and soundtrack review material is available at
`../AssetReview/review.html`; provenance, decoded metadata, source hashes and
limits are in `../AssetReview/README.md`. It is not production asset clearance.

**Not release-ready. No publication is authorized.** This is QA-14 preparation,
not approval, a checked tracker task, or a substitute for native/hardware evidence.
The [physical validation handoff](manual-validation.md) pins candidate `241dafd`,
records the exact manual-test deferral and earlier probe-only authority, and gives
future HC_iPhone13 Xcode steps, per-case outcomes/evidence fields, full receipt
failpoints and iPhone 11/two-device prerequisites. All physical cases remain
untested. It is preparation for eventual manual testing, not a request to start it.
The candidate is the branch commit containing this file; exact execution outcomes
are in `2026-10-01-native-candidate.md`, `2026-10-01-media-workflows.md` and the
superseding `../TrialKeychainProbe/2026-10-01-production-receipt-integration.md`.
Draft asset preparation is separately recorded above. The
implementation worker owns the configured no-mistakes run; Firstmate supervises
ask-user findings, reviews this evidence linkage, and must coordinate a separate retained
ordinary release task before any future authorized exposure. Never merge here.

## Candidate Identity and Local Gates

Record `git rev-parse HEAD`, `git status --short`, `xcodebuild -version`, simulator
OS/build, test result bundles and device model/OS for every execution. A dirty-tree
result must name its source changes, not claim the base commit alone was tested.
Run `sh Scripts/validate-local.sh` for packages, document ZIP and unsigned builds;
the app README names separate optional navigation and StoreKit simulator gates.
The `.storekit` fixture is test-target-only, with a strict product preflight and
verified event barriers. No credentials or real purchases are required by CI.
CI configuration is prepared; only an actual green run can establish that gate.
The current checkpoint retains the repeated scrolled-setup accessibility
failure detailed in `accessibility-diagnosis.md`; unaffected software continues. Default audit success does not
waive the fresh-build largest-type failure or the UIKitToolbar runtime warning.
The controlled follow-up in `accessibility-container-diagnosis.md` reproduced
the actual app's default failure and isolated a default-only stack success, but
largest-text contrast survives the container and hard-edge counterfactuals.
No production accessibility correction or green CI claim is established by it.
`accessibility-viewport-diagnosis.md` subsequently rejects documented edge
suppression and a GeometryReader viewport wrapper (0/2 and 0/1 tests). Timestamped
geometry/video shows the audit size sweep moves the viewport before callbacks;
the wrapper still underlaps navigation chrome. It does not establish a framework
false positive. Actual-app default/largest light/dark gates remain failed or unproved.
`accessibility-physical-frame-diagnosis.md` proves genuine frame separation in a
padded minimal probe (all-category pass and twelve fully reachable rows), but its
actual-app countercheck fails: light 0/2, dark 1/2. The attempted production patch
is retained only as evidence, not an accepted correction. Capture instrumentation
adds latency, and the probe's navigation/entitlement state differs from production.
QA-13 remains failed; these results do not authorize a required-check exception.
The next `accessibility-observer-diagnosis.md` comparison fails at its first
prerequisite: capture-enabled padded probe passes, capture-disabled fails two
contrast findings while all twelve rows remain reachable and the viewport stays
separate. Navigation/Trial-label comparisons were not advanced. The instrumented
green result cannot establish an uninstrumented remedy; audit pose/timing and
shared-host load remain limitations. No new production change or acceptance.
The subsequent [real-app traversal](accessibility-traversal-diagnosis.md) matches
A/B settled title frames and reproduces Silent capture contrast in the first
scrolled `.all` without earlier audits. A records ten rows but five inset checks
fail; B times out before its row traversal at the effective 600-second bound.
This is incomplete diagnostic evidence, not a startup failure, native correction
or QA-13 pass. The original UI suite remains byte-identical; the additive test
patch and every failure are retained outside normal CI sources.
The [mechanics-only continuation](accessibility-traversal-progress-diagnosis.md)
reaches matching y400 poses and passes all ten A row checks. B's unfiltered audit
returns without issues, then seven rows pass before the unchanged 600-second
timeout. Its final three rows and completion record are absent. The pair remains
incomplete; no original failed gate is cleared and no production edit follows.
Repeated bounded condition queries remain in the diagnostic trace; additional
variants stopped under instruction 032. Physical scenarios remain deferred.
Instruction 033's [early-exit continuation](accessibility-traversal-early-exit-diagnosis.md)
then completes in 426.038 seconds: both ten-row traversals pass at exactly matching
y400 poses; B's unfiltered audit returns no findings. Only diagnostic loop exit
timing changed. This establishes that bounded readability/reachability path, not
the cause of prior failures or clearance of original sequential/assistive gates.
Production/original suites remain unchanged; QA-13 and physical gates stay open.
Instruction 034's [unchanged original matrix](accessibility-original-matrix-diagnosis.md)
then executes all four default/largest light/dark cases once: four failures,
seven findings, no skips/timeouts. Default names Movie Orientation sizing;
largest names scrolled description/Silent capture contrast and elementless command
contrast. All later navigation steps execute. Retained source, native videos,
trees and timings distinguish the earlier passing pair's configuration/history
and pose without establishing a user defect or analyzer cause. No original-test
or production correction, exception or acceptance follows. The report also names
remaining native fault-controller, race-instrumentation and coverage code work;
hardware deferral does not waive those preparable deliverables.

Instruction 035 delivers the first [receipt-harness checkpoint](../ReceiptScenarioHarness/035/README.md):
an isolated iOS target using production receipt coordination, media journal and
SQLite, explicit phase/re-entry controls and retained state/namespace inventories.
Native Security capability skipped on actual -34018 in the unsigned simulator;
the injected-store cases are labeled as such, never native Keychain acceptance.
The [remaining engineering inventory](../ReceiptScenarioHarness/035/remaining-engineering.md)
names missing exact Development/FIFO boundaries, export/privacy race tests and
broader native workflow coverage, with production interface impacts to review
before dependent edits. No production change, original-audit fix/waiver, physical
acceptance or implementation-ready claim follows. This report is repository-owned
no-mistakes handoff material, not a structured scenario import or a pipeline run.

Instruction 036's first [export/privacy checkpoint](../ExportPrivacyHarness/036/README.md)
adds source-bound native synthetic tests using existing public authorizer/writer
interfaces. It exercises failed/unknown/cancelled replies, verified-master cleanup,
acknowledgment-aware retries, paused export versus removal, stale private Movie
retirement and process re-entry. Completed external synthetic copies remain;
unknown replies do not establish exactly-once external writes. No PhotoKit or
Security request, production change, physical acceptance, audit waiver or release.
Exact Development observation and remaining fault/view coverage are subsequent work.

The independent populated-view continuation is recorded in
`Evidence/PopulatedJournal/037/README.md`: four retained UI scenarios and exact
state/print comparisons pass, plus three unchanged legacy workflow tests and an
unsigned device build. Actual views/renderer/repository use synthetic media,
injected read-only Trial and absent billing configuration. Empty Delete and early
cancel/separate Development, individual Instant reveal, original choice without
export, saved Darkroom edit/exact Reset/reopen and legacy Archive/Movie placeholders
have bounded evidence. Initial compile/selector failures and UIKitToolbar warnings
remain recorded. This is partial FR-06/07/08/16/18 evidence, not capture, Photos,
Keychain, physical backup, final rendering or accessibility acceptance.

The Development process-exit continuation is recorded in
`Evidence/DevelopmentProcessExit/036/README.md`: 33 actual macOS child exits across
all five Cameras and four representative iOS app exits, followed by explicit
production recovery/resume and exact native state/media comparisons. Existing
optional observers are used only in nonshipping targets; shipping code is unchanged.
Fixed treatment/retained masters/clips, individual Instant reveal, abandoned Work
cleanup and post-Discard Movie retirement/reassembly have bounded evidence. These
are ordinary observed process exits, not power loss, physical interruption,
backup/restore, full-capacity performance or final native-media fidelity acceptance.
Initial compile/fixture failures are retained; FR-06/16 and DEV/PRV/ARC-06/QA-03/11
remain partial. Exact commands and affected outcomes are in that source-bound report.

The capture-backend quiescence continuation is recorded in
`Evidence/NativeApp/capture-backend-quiescence-040.md`: `CapturedMediaFiles`
cleanup now treats a removed staging directory as empty and uses standardized path
comparison for same-directory committed-file cleanup. NativeAdapters package tests,
a targeted hosted iOS `AVFoundationCaptureBackend` unit class and the runtime
capture-recovery integration test pass. This is partial CAP-09/PRV/ARC-03/06
software evidence for synthetic staged media and an injected committer, not a real
camera callback, storage-pressure, physical interruption or hardware acceptance.

The Movie player/cache continuation is recorded in
`Evidence/NativeApp/movie-player-cache-042.md`: the populated Journal harness now
asserts initial Movie playback, surviving-clip playback after first discard and
no playback/export after the final discard, while the runtime test proves stale
assembled Movie retirement and reassembly from retained clips. This is bounded
synthetic software evidence, not player-instance lifetime, hardware codec
fidelity, PhotoKit/export race, background interruption or physical acceptance.

The full-capacity runtime continuation is recorded in
`Evidence/NativeApp/full-capacity-runtime-043.md`: FilmRuntime package tests now
cover full Disposable 27, 6x6 12, Instant 10 including the final print, Super 8
200 seconds and 16mm 165 seconds with sealed-before-development or individual
Instant reveal semantics and extra-capture rejection. This is synthetic
repository/processor evidence, not hardware capture timing, iPhone 11
performance, physical storage pressure or real-device full-capacity acceptance.

The Darkroom/player observation continuation is recorded in
`Evidence/NativeApp/darkroom-player-observation-044.md`: the populated harness
now reaches Contrast, CMY, Crop and non-gesture Dodge/Burn controls in the actual
Darkroom sheet, and a harness-only public UIKit/AVKit observer proves the initial
Movie player/item path is released, detached or replaced before successor
playback is accepted after Discard #1. This is simulator/synthetic software
evidence, not VoiceOver/Switch Control, all-category audit, approved render-range,
hardware playback-cache, PhotoKit, interruption or physical-device acceptance.

The permission and storage failure continuation is recorded in `Evidence/NativeApp/permission-storage-failures-045.md`.
Staging recovery, privacy tombstones and pending Trial saves no longer treat an existing but uninspectable path as absent, so they fail and retry instead of reporting empty or removed.
A denied add-only Photos status in the actual populated views now shows Photos guidance instead of storage advice and raw error text, and Settings shows readable permission states.
This is partial CAP-09/STO/PRV/QA-09 software evidence on macOS temporary directories and a simulator privacy revoke, not PhotoKit, device storage-pressure, Camera prompt or physical acceptance.

The `CaptureController` continuation is recorded in `Evidence/NativeApp/capture-controller-quiescence-046.md`.
Hosted tests drive the actual controller, backend, Trial owner and repository on a camera-less simulator, with Camera authorization injected through the existing protocol and the shipping default unchanged.
Four reproduced defects are fixed: Discard deleted another capture's unfinished save, an `open` still finishing a save started the session after Done, and late save events showed storage failure alerts during Delete Film and Resume Save.
The actual app now declines the real simulator Camera request at Load Film, loads nothing and shows Camera Off in Settings; a Keychain Trial failure no longer gives storage advice.
The iOS 26.2 hosted stage, which CI runs, exposed an abort in `SubscriptionController`'s `isolated deinit`; a plain deinit replaces it and all 16 hosted tests pass on 26.2.
This is partial CAP-08/09, PRV, DEV-05 and QA-09/13 software evidence, not a running camera, AVFoundation callback, physical interruption or device acceptance.

## Required Native Manual Matrix

Use only captain-authorized devices and synthetic/private test media. The captain
deferred physical-phone work to manual v1 testing; this document does not authorize
installation, signing, purchases, device deletion, backup restoration or erasure.

| Gate | Required scenario and retained evidence | Current gap |
| --- | --- | --- |
| CAP-01...10 / QA-01,02 | Each Camera rear/front; asymmetric target proves mirrored preview and unmirrored saved output; all supported controls; deny Camera; interrupt call/lock/background; retry low-space and process kill. Record source/media hashes, saved capacity and Trial state. | No physical capture run. |
| DEV / QA-03 | Fill each exact capacity, prove no roll/Movie auto-reveal; confirm/cancel exact early waste; empty Delete Film; Instant final print; terminate and resume the same treatment/master. | Full-capacity repository/processor tests pass synthetically; app-model/native renderer tests are not device rituals, physical timing or termination proof. |
| DRK / QA-04,13 | Every applicable control, accessible point and gesture Dodge/Burn, exact Reset/export equality, independent photos, no Movie entry. Largest Dynamic Type, VoiceOver and Switch Control across populated screens. | Populated simulator now covers actual Darkroom controls and non-gesture Dodge/Burn; exact Reset/reopen was already bounded. At the default text size the last Dodge/Burn row rests in the bottom bar's edge band until scrolled (045 observation). Gesture drawing, assistive technologies, all-category audits, physical Dynamic Type and approved ranges remain open; medium applicability/ranges remain DEC-04/11. |
| STO / QA-09 | Independent developed/original exports; denied/restricted add-only permission, failed Photos write/retry; decode/hash masters before cleanup; inspect real Photos output; no sealed or automatic exports. | Simulator denied add-only status reaches Photos guidance without a write; PhotoKit execution, restricted/limited states and actual device low-storage paths untested. |
| MOV / PRV / QA-11 / ARC-10 | Both final orientations, opposite-orientation borders, chronological cuts, native cadence/color/HDR/codec fidelity, optional cleared music; Discard during playback/export and reopen; no stale asset or deleted clip returns. | Runtime stale-Movie retirement, populated final empty-Movie UI and public AVKit player/item retirement after first Discard pass synthetically; hardware fidelity/music/export/background/cache-internals acceptance absent. |
| BIL / ARC-09 | Approved monthly/yearly products, cancellation/pending/renewal/expiry/restore; offline after one online sync; finish/develop/edit/export existing Films after expiry. | Local fixtures pass separately from any authorized StoreKit sandbox/device execution. Live setup and DEC-02 are absent. |
| TRI / ARC-11 | Pinned Keychain procedure, offline activation/first save failure windows, zero-save delete/replacement, used delete/reinstall, two-device restored Trial coexistence. | Hardware untested. `../TrialKeychainProbe/2026-10-01-production-receipt-integration.md` records the production correction to historical D3, raw-status/read tests, native Journal integration and production-owner process exits. Complete pending media precedes one receipt/consumption item, then once-only projection. Injected survival and process-exit checks do not prove physical retention, power-loss ordering or restore. A marker-only probe cannot accept this protocol. |
| ARC-08 / QA-13 | iPhone 11 iOS 26 capture-to-save and full-roll/Movie Development timings, interrupted resume, peak memory, thermal/storage-pressure behavior. | No measurements; DEC-12 budgets are proposals only. |
| ARC-12 / QA-15 | Authorized two-device large-Film backup/restore, sealed/revealed state, edit recipes, Movie assets and independent Trial; older backup after deletion. Record backup size and reappearing objects. | No authorized restore performed. |

## Assets and Apple Configuration

Subsequent 036 Development preparation is linked in
[Development observer evidence](../DevelopmentObserver/036/README.md). The shared
runtime gains a default-absent observer at five existing phases; no shipping
configuration installs it. The report binds actual tests/builds and initial
fixture failures to source, and distinguishes recovery after joined cancellation
from untested process death, restore and physical media fidelity. No acceptance
checkbox, QA-13 exception or release authority follows from this preparation.
The separate [receipt FIFO follow-up](../ReceiptFIFO/036/README.md) records one
package and one hosted pass using the existing internal count, single possible
new queue entrant at each step, real deletion and injected-memory receipts only.
It leaves the original 035 request-before-release limitation and hardware gates
intact; no new public queue-observation API or production source change.

- DEC-01: final app name/copy, app icon, screenshots and metadata are not approved.
- DEC-04/11: provisional render presets and controls require actual Camera-quality
  review. Do not label them authenticated simulations or silently approve ranges.
- DEC-05: no production sample photos/movies or instrumental audio is cleared.
  Before bundling each asset retain source, author, license text/hash, acquisition
  date, redistribution/export rights, attribution requirements and approval. Music
  must permit inclusion inside a user's exported Movie, not just in-app playback.
  Synthetic test fixtures must not be shown as production Camera samples.
- DEC-02: production product IDs, prices, offers and refund/revocation product
  policy remain absent. Test fixture prices are not recommendations. No Apple
  account, App Store Connect or billing configuration change is authorized.
- DEC-13: support/privacy URLs, approved policy copy, App Review contact/material,
  privacy declarations, age rating and signing/provisioning need their real owners.
  App requests only Camera and Photos add-only. Audit the final binary and Apple
  disclosures; do not infer store-review approval from source strings.
- DEC-14: approve TestFlight/interview learning targets without adding analytics
  or autonomous telemetry. No automatic upload of media or diagnostics.

## Support and Recovery Draft

Saved Films stay in this app's local storage and may be included in iOS device
backups. Immerse has no media server or app-managed recovery service. A Photos
export is a flattened copy, not a restorable Film or edit history. Exports cannot
be recalled by Discard/Delete Film; restoring an older iOS backup may bring back
removed captures or an entire deleted Film. The device-only Trial record does not
migrate with restored Films. Do not promise recovery without an available backup.

For save/development/export failure, preserve the Film and private staging, record
the visible error, check storage and retry through the app's recovery path. Do not
advise deleting/reinstalling as a first-line recovery step: it destroys local media.
Do not ask a user to provide personal media, Keychain data or Apple credentials.
Any optional support diagnostics require explicit consent and redaction.

Recovery containment for this candidate is the isolated branch and no exposure.
Privacy tombstones retire app-controlled files and stale Movie versions; earlier
device backups and Photos copies remain outside that current-store removal. A
code rollback is not proof of a reversible media migration. Preserve master/source
files and validate any future migration before distributing it.
