# Film Camera Experience v1 - Requirement and Evidence Map

**Created:** September 30, 2026
**Branch:** `fm/immerse-v1-implementation`
**Candidate:** the commit containing this file.
**Scope:** v1 personal iOS 26 iPhone app requirements only. Deferred Group and Account tasks remain out of v1.

This map is the repository-owned handoff for implementation evidence.
It covers every unchecked v1 tracker ID present at intake, each personal FR acceptance area, the implementation artifacts added so far, exact commands, observed outcomes, and the gaps that still require decisions, native app work, Apple configuration or hardware.

The [clause-level acceptance companion](2026-09-29-film-camera-experience-v1-acceptance-evidence.md) expands each personal FR acceptance paragraph and every section 11 invariant, binds the local checks to source `7bfc78c`, names the outstanding native/hardware gates, and records the precise first-save cross-store conflict without changing the Trial rule.

No simulator result below is treated as native hardware evidence.
No browser prototype result is treated as production behavior.
No StoreKit, actual Photos writes, AVFoundation hardware capture, backup or Keychain hardware behavior is accepted yet.

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

Physical execution preparation: [manual validation handoff](../Evidence/NativeApp/manual-validation.md)
binds candidate `241dafd` to future HC_iPhone13 (iPhone 13 Pro/iOS 26.6.2) Xcode
steps, all personal FR acceptance/invariants, full receipt fault cases and exact
evidence fields. It preserves the captain's manual-test deferral and earlier
probe-only scope; iPhone 11, second-phone restore, exact physical fault control, asset,
product and budget prerequisites remain unmet. No physical action or acceptance
is implied, and current accessibility failures still block readiness.

Receipt preparation checkpoint 035:
`Probes/ReceiptScenarioHarness/README.md` now owns executable unsigned build and
isolated simulator commands for T02...T09. Its source-bound observed results are
in `Evidence/ReceiptScenarioHarness/035/README.md`, including the actual native
Security `-34018` capability skip (no native receipt created), injected-store
recovery, media/SQL inventories and phase controls. Production source and the
original failed accessibility matrix are unchanged. This adds bounded software
evidence for TRI-01/03/04/09, ARC-03/05/11, CAP-08, DEL-04, QA-12 and
FR-04/05/18/21; it does not accept physical scenarios or settle atomic durability.
`remaining-engineering.md` beside that report identifies concrete missing
Development/export/privacy/native-coverage code and production boundary impacts.

Export/privacy preparation checkpoint 036:
`Probes/ExportPrivacyHarness/README.md` supplies executable native hosted and
process-exit tests through existing public writer/authorizer protocols. Results
and source/artifact binding are in `Evidence/ExportPrivacyHarness/036/README.md`.
Real production rendering, storage and removal operate on synthetic media; all
writer permissions, receipts and errors are explicitly injected, with completed
external synthetic copies retained outside the private repository. This advances
FR-08/16/18, STO-05...09, PRV-05...08, DEL-02, ARC-06 and QA-09/11 software evidence,
not physical PhotoKit or full privacy acceptance. Production and original failed
accessibility suites remain unchanged. Exact Development observers are authorized
for a subsequent checkpoint, not delivered or validated by that first export target.

The subsequent 036 Development boundary candidate is recorded in
`Evidence/DevelopmentObserver/036/README.md`, with exact commands in
`Packages/FilmRuntime/README.md`. Its optional default-absent observer exposes the
five approved existing phases, without a shipping fault setting or observer work
when absent. Actual native synthetic rendering/repository tests exercise
pause/release, exact thrown error, cancellation before the next side effect,
same-owner retry, observer-absent re-entry, Delete and Instant/Movie Discard.
Consult that source-bound report for executed package/hosted outcomes; ordinary
process-exit, physical restore/power-loss, active player/cache and capture races
remain distinct missing evidence. This adds partial FR-06/16/18, DEV-04/06/07/08,
ARC-06 and QA-03/11 evidence, not acceptance or a change to the receipt protocol.

Receipt FIFO follow-up 036 (`Evidence/ReceiptFIFO/036/README.md`) separately proves
one controlled 16mm save/Delete/stale-callback order in package and iOS-hosted
tests. The save owns its lease while counts 0/1/2 are observed, with only Delete
and then only the stale callback newly launched. Final count 0, exact late error,
private removal and unchanged injected consumption are recorded. No production
queue API or native Security call was added. This does not retroactively prove
the old 035 public-controller request timestamp or physical capture races.

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

Current QA-13 accessibility diagnosis:
`Evidence/NativeApp/accessibility-original-matrix-diagnosis.md` rechecks the
unchanged original default/largest cases once in light and dark on `a79d481`:
four executed failures, seven findings, no skips/timeouts. Source-bound native
videos/trees preserve all failures and completed downstream steps. Configuration,
audit history and pose differ from the passing bounded pair; neither a user
defect nor analyzer cause is isolated. No original-test/production correction or
exception. Remaining native fault/race harness and coverage code work is named
separately from deferred physical/product acceptance. QA-13 stays failed.
`Evidence/NativeApp/accessibility-traversal-early-exit-diagnosis.md` records a
completed bounded pair after correcting redundant diagnostic condition queries:
both ten-row traversals pass, y400 poses match exactly, B unfiltered audit has
zero findings, 426.038 seconds. This is readability/reachability evidence for that
path only, not production remediation or clearance of original matrix/assistive
failures. QA-13 remains open; original suites and prior evidence are unchanged.
`Evidence/NativeApp/accessibility-traversal-progress-diagnosis.md` records the
mechanics-only continuation on base `1a69b3d`: matching settled y400 poses, all ten
A rows passing, no-issue unfiltered B audit, seven B rows passing before the same
600-second limit. Missing B disclosure/Subscription/Load and completion keep the
pair incomplete. No production edit, required-check waiver or acceptance; further
variants stopped. Original suites, historical failures and physical deferral remain.
`Evidence/NativeApp/accessibility-traversal-diagnosis.md` records the subsequent
current-Form A/B attempt: matched title poses, first scrolled all-category contrast
on Silent capture, A ten rows with five inset failures, B no completed rows before
the effective 600-second timeout. The native case actually ran; comparison remains
incomplete. No production change, altered original suite, waiver or acceptance.
`Evidence/NativeApp/accessibility-observer-diagnosis.md` is the latest bounded
probe follow-up: capture-enabled padded control passes but capture-disabled fails title
and command contrast (same build, largest/light); twelve-row reachability passes.
Physical separation survives both. Pre-audit offsets and shared-host load prevent
claiming sole causality; no later navigation/Trial counterfactual or production
change is made. The instrumented pass is not an uninstrumented correction.
`Evidence/NativeApp/accessibility-physical-frame-diagnosis.md` retains the prior
follow-up: public native frames confirm outer-padding separation and its instrumented
probe passes all-category audits plus twelve fully reachable rows. The actual-app
attempt still fails light 0/2 and dark 1/2, and is retained only as an evidence patch.
Synchronous screenshot timing and navigation/entitlement differences remain explicit
limits; no production remedy, waiver or acceptance is claimed.
`Evidence/NativeApp/accessibility-viewport-diagnosis.md` retains the earlier
all-category largest-text control/suppression failures (0/2) and the independent
viewport-wrapper failure (0/1). Complete exported video/activity and timed
geometry establish a size-sweep/scroll-offset change before callbacks, not the
analyzer's internal capture time. The wrapper did not isolate the physical viewport;
suppression permits visible chrome overlap. No production fix or waiver is claimed.
`Evidence/NativeApp/accessibility-container-diagnosis.md` records source-bound
unchanged default/system-largest probe repeats, actual-app default failure and
container/scroll-edge counterfactuals after the coordinated quiet interval.
At default, the explicit stack passes all audits while the intact same-build Form
fails Movie Orientation sizing. Both hard-edge largest-text conditions still fail
contrast, with exact node/frame/category/timestamp and screenshot evidence retained.
The old default app pass lacked the subsequently added visible orientation heading;
it is not current same-label acceptance. No production patch, test exception,
hardware acceptance or no-mistakes/CI result is claimed. The repeated contrast
boundary remains open with Firstmate; all other software/asset evidence below is
unchanged.

Current asset-review preparation: `Evidence/AssetReview/README.md` and `review.html`
cover DEC-04/05/11, CAM-10/12, MOV-03/05/09/10/11, DEV-04/06 and QA-03/11/14.
Fourteen generated/derived native assets decode, with source/output hashes and
provenance; browser photo/Movie/audio inspection passes at desktop and a measured
390-pixel mobile viewport. These are actual provisional renderer outputs and a
draft original instrumental, not cleared production media, camera footage or
hardware proof. Source terms, final curation, quality and export rights remain
with the existing asset review; no task acceptance or product decision is changed.

Current Trial software addendum:
`Evidence/TrialKeychainProbe/2026-10-01-production-receipt-integration.md` binds
TRI-01/03/04/09, ARC-03/05/11, CAP-08, DEL-04, UX-03, QA-12 and FR-04/05/08/18/21
to production receipt/readback integration, complete pending media, serialized
privacy deletion, legacy outbox migration and restored-Film rights. Focused gates
pass 25 runtime tests, 12 entitlement tests, nine production-owner child-process
exits and eight native Journal/local StoreKit scenarios. Its own source inventory
and final combined gate are separate from the historical checkpoint below. No
real Keychain mutation or phone action was performed; no hardware gate is accepted.

Historical `d233bb7` execution (October 1, 2026, 06:18-06:47 PDT): 101 package tests
and unsigned simulator/device app builds passed, followed by all six native local
StoreKit/app-model scenarios on iOS 26.2. This includes two diagnostic Trial tests:
one **confirms a required invariant violation**, not an acceptance pass. The exact
source inventory, identified soundtrack fixtures, source-choice red/green regression,
native result summaries and limits are in `Evidence/NativeApp/2026-10-01-media-workflows.md`.
Rows explicitly described as historical below do not supersede these current reports.

TRI-04 / ARC-11 / QA-12 current boundary:
`Evidence/TrialKeychainProbe/2026-10-01-protocol-review.md` records the actual
SQLite/capture-commit followed by lost-outbox counterexample, compares four native
protocol orderings and retains 17 modeled prefixes. Prepared-media/Keychain receipt
authority fixes the idealized local reinstall window but leaves a new-device
backup distinction initially unproved. The focused follow-up in
`Evidence/TrialKeychainProbe/2026-10-01-pending-replay-review.md` closes that
particular modeled distinction with pending replay under restored rights: 35
prefixes and four native file-copy photo/Movie cases preserve once-only capacity,
chronology and destination entitlement. The authorized isolated implementation study
is now in `Evidence/TrialKeychainProbe/2026-10-01-receipt-study.md`: eleven tests
include 30 save-prefix histories, 60 restore copies and 30 abrupt child-process exits
against actual SQLite/native media with injected receipt stores. The subsequent
production report above corrects the D3 software ordering and maps native
status/read outcomes conservatively: unknown is pending, never refundable. Native
controller callbacks, launch, Trial start and whole-Film deletion share one owner.
The D3 failure and original source identity remain historical evidence, not hidden
as a hardware gap. Native retention, two-device restore, daemon interruption and
power-loss boundaries remain unaccepted. No first-save rule or privacy/storage
exception is changed; independent implementation continues.

Populated native workflows now pass 3/3 on iOS 26.5 after fixing Archive path mixing
and stale Journal rows. The photo flow includes early Development, Darkroom/Reset,
Discard, rename, Archive/restore/reopen and Delete Film. The other paths preserve
Instant open-pack reveal and an empty Movie's numbered placeholders without export.
The separate dark-mode all-category accessibility run still fails both tests
(Dynamic Type and contrast); it is not waived by functional workflow success.

Latest media/workflow addendum: `Evidence/NativeApp/2026-10-01-media-workflows.md`
maps CAM-10, MOV-09/11, PRV-08, DRK and their FR clauses to the rights-verified
bundle catalog, retained soundtrack/license/revision recovery, medium-gated chemical
toning and separate populated native UI harness. Native decoded-media tests pass
for soundtrack changes, stale Movie rejection, bundle-independent Discard and
byte-exact toned-print Reset. No production asset is approved or bundled, no
Camera stock is changed to black-and-white, and no test proves physical capture.
The bounded minimal accessibility probe reproduces failures with both forced and
system-selected largest text; unchanged picker style also fails. Host sleep accounts
for substantial earlier elapsed-time gaps, not device performance. Evidence and
exact commands are retained; no audit waiver or full-v1 acceptance follows.
Firstmate authorized continuing unaffected software and worker-owned no-mistakes
handoff with supervisor-owned ask-user findings. Historical rows below remain
historical snapshots; use these addenda for current implementation status.

Latest native app addendum: `Evidence/NativeApp/2026-10-01-native-candidate.md`
maps the actual SwiftUI Journal, setup, capture, reveal, Darkroom, export, privacy,
Settings and configurable StoreKit code to affected task IDs and FRs. It records
13 domain and 23 persistence passes, the initial native navigation execution,
unsigned builds and retained failed StoreKit runs. The UI is now integrated,
superseding historical "not started" UI entries below, but no such entry becomes
accepted from compilation. Four local StoreKit scenarios and two app-model native
integration tests subsequently passed on iOS 26.2 after proving asynchronous
fixture delivery (diagnosis and unchanged assertions retained). Accessibility
audits exposed real contrast/layout issues. Default setup now passes after bounded
diagnosis; expanded scrolled largest-type coverage still has navigation-edge
contrast and Movie Orientation/Silent capture Dynamic Type failures, including a
contradictory fresh-build result. Every finding is retained without exception. The current
checkpoint combined run passed 88 package tests plus both unsigned builds, and all six
StoreKit/app-model scenarios were repeated successfully. Later setup-only changes
still need their affected UI/build checks. `Scripts/verify-requirement-map.sh`
checks the 122 intake IDs, 72 clause records and nine invariants without treating
coverage as acceptance. FR-05
inspection also corrected a mistaken 16:9 renderer target to required 4:3/3:4.
The candidate report records exact commands, earlier failures and current outcomes;
`Evidence/NativeApp/launch-readiness.md` prepares QA-14 without release authority. Live prices,
sample/music rights, remaining UI/accessibility work, all hardware gates and the
Trial cross-store conflict remain open. `App/Immerse/README.md` and
`Scripts/validate-local.sh` are the current build/test entry points. The captain's
implementation-first amendment supersedes the old before-code TRI-11 order and
the historical reconnect instruction below; do not perform physical-phone actions.

Latest capture recovery addendum: `Evidence/NativeCapture/2026-10-01-staging-recovery.md`
records per-operation journals, preserved capture dates, decoder-gated relaunch
replay through persistent receipts, staging privacy deletion and native cancellation
boundaries. NativeAdapters 18, CapturePipeline 6 and FilmRuntime 11 tests pass;
iOS simulator compile passes. Staging is included in Film backups; excluded
temporary render work remains separate. Actual process termination and hardware
callback cancellation remain untested, and the app UI still needs integration.

Latest Trial addendum: `Evidence/TrialKeychainProbe/2026-10-01-software-integration.md`
records native Keychain code, offline activation, capture-transaction outbox and
reconciliation, four injected-store integration tests and both iOS compile gates.
It supersedes the historical pure-policy-only implementation status below, but
does not close hardware checks or the D3 first-save/uninstall atomicity conflict.

Latest Development/render/export addendum: `Evidence/NativeRendering/2026-10-01-workflows.md`
records real native pixel/Movie processing, persisted one-time assignments, verified
reveal (including individually sealed-to-revealed Instant prints), exact byte Reset,
retained-clip Movie reassembly and explicit Photos export orchestration. It records
69 passing tests across six affected packages and both signing-disabled iOS builds.
Actual PhotoKit writes and required hardware/visual/rights acceptance are still absent.
It supersedes earlier planning-only renderer and immediate-Instant-reveal descriptions.

Latest storage addendum: `Evidence/PrivacyRecovery/2026-10-01-save-cleanup.md`
records persistent native save receipts (including post-commit lost acknowledgement),
decoder/hash/choice/export gates for source deletion, 21 passing persistence tests,
6 passing capture pipeline tests and the signing-disabled iOS simulator compile.
This supersedes hash-only cleanup and lifetime-only duplicate-delivery descriptions
in historical rows below; process-kill staging recovery and actual Photos writes
remain unaccepted.

The native capture slice is recorded in `Evidence/NativeCapture/2026-10-01-backend.md`. The subsequent repository privacy slice, including four new failure/concurrency scenarios and 14 passing persistence tests, is recorded in `Evidence/PrivacyRecovery/2026-10-01-repository.md`. Durable deletion jobs and stale-writer suppression now exist in the repository; native staging/cache/export integration, capture receipts across process death and decoded developed-master verification remain incomplete. Earlier package checks below do not prove those missing behaviors.

The captain's later work order, "implement prd first. i'll test is manually when v1 is ready", supersedes the before-code hardware and foundation-only ordering restrictions. Implement the full reversible native app and Trial integration now; defer physical-phone operations and retain all required hardware checks as unaccepted. This does not approve unanswered product decisions. Historical gate records below retain their original outcomes, not a current instruction to reconnect a phone or wait before implementing software.

## Candidate Artifacts and Gates

| Artifact or gate | Location or command | Observed outcome | Evidence limits |
| --- | --- | --- | --- |
| FilmDomain Swift package | `Packages/FilmDomain` | Added a standalone pure Swift package using the architecture baseline's reversible Swift package default. | This does not decide DEC-03 for the app stack. |
| FilmDomain behavior tests | `swift test --package-path Packages/FilmDomain` | Passed locally on Xcode 26.5 / Swift 6.3.2; 12 tests, 0 failures, including fractional Movie duration persistence/budgets and independent clip/final orientation. | Tests cover domain behavior only, not native camera, renderer, storage files, Photos, StoreKit or hardware. |
| FilmPersistence Swift package | `Packages/FilmPersistence` | Added a standalone SQLite plus file-store package under the reversible local-store baseline. | Uses direct SQLite for deterministic contracts; it does not decide the final app persistence wrapper or GRDB choice under DEC-03/D4. |
| FilmPersistence behavior tests | `swift test --package-path Packages/FilmPersistence` | Passed locally on Xcode 26.5 / Swift 6.3.2; 10 tests, 0 failures. | Tests durable-save, relaunch-style reload, cleanup, whole-Film deletion and privacy-safe Movie assembly retirement contracts with synthetic data on macOS; not AVFoundation capture, PhotoKit, iOS backup or hardware. |
| RenderCore Swift package | `Packages/RenderCore` | Added a pure Swift package for stable treatment assignment, resumable Development bookkeeping, Movie assembly plans and exact Darkroom reset. | It deliberately does not choose render specs, treatment algorithms, control ranges, codecs or soundtrack rights. |
| RenderCore behavior tests | `swift test --package-path Packages/RenderCore` | Passed locally on Xcode 26.5 / Swift 6.3.2; 5 tests, 0 failures, including a pinned stable treatment seed value. | Tests planning/state contracts only, not actual pixels, video, audio or GPU performance. |
| RenderFixtures native media package | `Packages/RenderFixtures` | Added a bounded ImageIO/AVFoundation fixture generator and inspector for synthetic developed photo and Movie samples with configurable experimental settings. | Discovery-only. It does not decide DEC-04, implement production treatment quality, add user-facing toggles, use real capture media or prove hardware performance. |
| RenderFixtures behavior tests | `swift test --package-path Packages/RenderFixtures` | Passed locally on Xcode 26.5 / Swift 6.3.2; 2 tests, 0 failures. | Tests decoded real media fixture outputs on macOS through native APIs; not production rendering, device capture, Movie export fidelity on hardware or approved output specs. |
| RenderFixtures inspectable samples | `swift run --package-path Packages/RenderFixtures RenderFixtureTool Evidence/RenderFixtures` | Generated `synthetic-developed-photo.jpg`, `synthetic-developed-movie.mov` and `manifest.json`; decoded metadata: JPEG `public.jpeg` 640 x 480, H.264 `avc1` `.mov` 640 x 360, nominal 17.97005 fps, duration 1.0016666667 s, identity orientation transform. | Synthetic fixtures for comparison only; not production assets, visual treatment, licensed media or DEC-04 approval. |
| NativeAdapters Swift package | `Packages/NativeAdapters` | Added AVFoundation and PhotoKit boundary adapters plus protocol-backed coordinators for capture permission timing, rear/front capability discovery, front viewfinder mirroring with unmirrored output, lens-switch gating, silent Movie plans, interruption/save events and add-only Photos export outcomes. | Uses approved reversible Swift package default only; does not settle DEC-03 final app stack or product flow timing. |
| NativeAdapters behavior tests | `swift test --package-path Packages/NativeAdapters` | Passed locally on Xcode 26.5 / Swift 6.3.2; 16 tests, 0 failures. Coordinator tests cover retained-file retry, interruption and stale callbacks. Real synthetic JPEG and Movie files are decoded, preserved and rejected when invalid/over-budget. | Runs on macOS with synthetic media, not physical camera/microphone, production quality or device Photos writes. |
| Native capture backend | `Packages/NativeAdapters/Sources/NativeAdapters/AVFoundationCaptureBackend.swift`, `CapturedMediaFiles.swift`, `CaptureOperationCoordinator.swift` | Real AVCaptureSession lifecycle and photo/movie delegates, serial actor executor, rear/front switching, output unmirroring, preview helper, independent per-clip orientation, silent recording and interruption notifications compile for iOS 26.5 device/simulator. Evidence and exact commands: `Evidence/NativeCapture/2026-10-01-backend.md`. | UI and permission timing remain configurable/unwired. Native hardware capture, call/lock/background behavior, process-kill recovery and quality are untested. |
| CapturePipeline Swift package | `Packages/CapturePipeline` | Added capture-event-to-durable-save integration between `NativeAdapters` callbacks and `FilmPersistence`, including explicit failure/interruption outcomes and recovery-after-launch cleanup. | Uses synthetic files only; no real AVFoundation media operation, process-kill harness or device storage pressure was exercised. |
| CapturePipeline behavior tests | `swift test --package-path Packages/CapturePipeline` | Passed locally on Xcode 26.5 / Swift 6.3.2; 6 tests, 0 failures. Actor receiver acknowledges after persistence, rejects missing files without a debit and deduplicates repeated file delivery within its lifetime. | Tests synthetic storage payloads on macOS. Durable idempotency across process death, hardware capture and iOS interruption recovery remain unproved. |
| EntitlementCore Swift package | `Packages/EntitlementCore` | Added pure policy rules for subscription expiry preserving existing Films, one current-device Trial in progress, first-save Trial consumption, zero-save Trial deletion/replacement, used-Trial non-refund and restored Trial coexistence. | Policy only: no StoreKit, no Keychain, no product IDs/prices and no production Trial write path. TRI-11, ARC-09, ARC-11 and DEC-02 remain open. |
| EntitlementCore behavior tests | `swift test --package-path Packages/EntitlementCore` | Passed locally on Xcode 26.5 / Swift 6.3.2; 6 tests, 0 failures. | Tests settled entitlement policy in memory only; not StoreKit purchase/restore/expiry, Keychain persistence, delete/reinstall or backup/restore. |
| NativeAdapters iOS compile probe generation | `xcodegen generate --spec Probes/NativeAdaptersCompileProbe/project.yml` | Succeeded; generated `NativeAdaptersCompileProbe.xcodeproj`. | Requires XcodeGen on the machine. |
| NativeAdapters/CapturePipeline iOS simulator compile | `xcodebuild -project Probes/NativeAdaptersCompileProbe/NativeAdaptersCompileProbe.xcodeproj -scheme NativeAdaptersCompileProbe -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | Build succeeded against the iOS 26.5 simulator SDK with `NativeAdapters`, `CapturePipeline`, `FilmPersistence` and `FilmDomain` linked. | Compile-only; no simulator boot, camera session, microphone prompt, Photos write or device recovery was exercised. |
| Open-decision recommendations | `2026-09-29-film-camera-experience-v1-open-decision-recommendations.md` | Added concrete recommendations for DEC-04, DEC-05, DEC-11, DEC-12, DEC-13 and DEC-14 with affected tracker IDs and current supporting evidence; DEC-04 units and DEC-12 budgets are explicitly provisional and measurable. | Recommendations are not approved decisions and do not close any DEC item. |
| Trial Keychain probe source | `Probes/TrialKeychainProbe` | Small SwiftUI probe for a this-device-only, non-synchronizable marker. Captain approved the pinned single-phone procedure on 2026-10-01 and confirmed the paired iPhone 13 Pro/iOS 26.6.2 target. Source/project comparison against `6e5c1742d344e0505b74176f60ac11c19a83e686` passed with no differences. | Probe is not production Trial code. Exact approved scope and remaining authority boundaries are in `PERSONAL_DEVICE_TEST_PLAN.md`; no duplicate approval is needed for that scope. |
| Trial Keychain project generation | `xcodegen generate --spec Probes/TrialKeychainProbe/project.yml` | Succeeded; generated `TrialKeychainProbe.xcodeproj`. | Requires XcodeGen on the machine. |
| Trial Keychain simulator compile | `xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` | Build succeeded. | Compile-only. Simulator Keychain does not prove delete/reinstall, restore, OS update or erase behavior. |
| Trial Keychain physical-iOS compile | `xcodegen generate --spec Probes/TrialKeychainProbe/project.yml && xcodebuild -project Probes/TrialKeychainProbe/TrialKeychainProbe.xcodeproj -scheme TrialKeychainProbe -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` | Build succeeded against the iPhoneOS 26.5 SDK for arm64. Artifact path recorded in `PERSONAL_DEVICE_TEST_PLAN.md`: `/Users/hcho/Library/Developer/Xcode/DerivedData/TrialKeychainProbe-fbfzhiholludheevzyfcstyvxevx/Build/Products/Debug-iphoneos/TrialKeychainProbe.app`. | Compile-only; signing was disabled and no device install, launch, Keychain write, delete/reinstall, restore, OS update or erase was performed. |
| Trial Keychain signed physical-iOS build | `Evidence/TrialKeychainProbe/2026-10-01-device-attempt.md` contains the exact command template, local result bundle, signature verification and artifact hashes | On 2026-10-01 UTC, Xcode 26.5 built the unchanged pinned probe using the existing approved development team and provisioning. Build and local signature verification exited 0. | This is build evidence only. No install/launch/marker/write/delete/reinstall was performed because the approved phone was unreachable. |
| Xcode capability discovery | `xcodebuild -version`, `xcodebuild -showsdks`, `xcrun simctl list runtimes`, `xcrun devicectl list devices`; device details procedure in the probe evidence record | Xcode 26.5, iOS 26.5 SDK, iOS 26.0 through 26.5 simulators available. Latest read-only discovery on 2026-10-01 UTC reported the approved iPhone 13 Pro unavailable; cached details identify iOS 26.6.2 with pairing and Developer Mode enabled, but tunnel unavailable and DDI services false. | Reconnect the approved phone before the already-authorized probe sequence. Two-phone restore and iPhone 11 timing still lack their required devices/authority; native Movie hardware evidence is absent. |
| Document package ZIP gate | `zip -r -X 2026-09-29-film-camera-experience-v1-documents.zip 2026-09-29-film-camera-experience-v1`, then `unzip -l`, then extracted content diff | Passed locally; `unzip -l` listed 24 entries and byte comparison reported `ZIP_COMPARE_OK`. | Required because this file lives under the packaged requirements directory. |

## FR Acceptance Map

| FR / acceptance area | Current implementation evidence | Missing evidence or decision |
| --- | --- | --- |
| FR-01 Camera catalog | `CameraCatalog` models the five immutable packages; `CameraCatalogView` describes capacity, controls, reveal and audio; provisional per-Camera native photo and Movie treatments; lens-gated controls in `CaptureView`. Tests cover IDs, capacities, reveal rules, soundtrack eligibility, full-capacity runtime (`full-capacity-runtime-043.md`) and catalog browsing UI. | DEC-04 treatments, DEC-05 samples and soundtracks, Camera-quality review and real-device control differences (QA-01). |
| FR-02 Film Journal | Native `JournalView` and `FilmDetailView` group Films by state with revealed-only previews, suggested and custom titles, rename, Archive and restore, and capture date ranges. Hosted Journal tests and 037 populated UI cover them. | Device and assistive acceptance, the failed original QA-13 audits and DEC-01 copy. |
| FR-03 Setup and Load Film | `CameraCatalogView` starts with Camera selection and an explicit load screen; Camera permission is checked before any Film or Trial write; Movie Orientation locks at load; new Films need a subscription or the device Trial. UI tests show browsing and cancelling create nothing and declining the actual simulator Camera request loads nothing (046). | DEC-05 previews, the pending flow-bundle answers, Trial and StoreKit loading on hardware or sandbox, and device prompt timing. |
| FR-04 Capture | `CaptureController`, `CaptureView` and `AVFoundationCaptureBackend` provide rear and front capture with a mirrored front preview, unmirrored output, lens-gated controls, sealed staging and durable receipts. Hosted tests cover backend recovery (040), fail-closed uninspectable storage (045) and controller quiescence, including Discard keeping other unfinished saves (046). | Real capture, hardware mirroring and orientation, interruptions, low storage and process kill on a device (manual M04 to M08). |
| FR-05 Movie mechanics | Silent video-only recording with a maximum duration, per-clip orientation and fractional saved-duration debit; `NativeMovieRenderer` assembles chronologically and fits opposite clips with borders. Full 200 and 165-second runtime (043) and stale Movie retirement (042) are tested synthetically. | Hardware recording, interruption salvage, the microphone-denied check, playback and export fidelity, and DEC-04 codecs. |
| FR-06 Completion and Development | Explicit completion and exact early waste, DEC-09 empty-Film rules, resumable native Development with fixed treatment assignments and individual Instant reveal including the final print. Evidence: 036 observer and process exits, 037 UI, 043 runtime, and 046 Instant saves during other operations. | Native reveal ritual on a device, physical interruption and power loss, and DEC-11 Instant timing. |
| FR-07 Darkroom | `DarkroomView` offers exposure, contrast, CMY, crop and Dodge/Burn per photo with byte-exact Reset, and no Movie entry or saturation. Evidence: hosted Journal test, 037 exact Reset across relaunch and 044 control reachability. | DEC-11 ranges, crop and toning; gesture drawing and assistive technologies; device acceptance. |
| FR-08 Storage, Photos export and cleanup | Independent explicit developed and original exports, an irreversible originals choice, cleanup only after decodable and hash-verified masters, backup disclosure and add-only Photos guidance. Evidence: 036 injected-writer harness and 045 denied add-only Photos in the actual views. | Real PhotoKit prompt, write and fidelity, restricted and limited states, and hardware backup and restore. |
| FR-16 Discard and Movie reassembly | Discard tombstones with numbered placeholders and no refund, stale assembled Movie retirement and reassembly, and the DEC-09 empty Movie. Evidence: 036, 042, 044, 045 for uninspectable residual copies and 046 for other unfinished saves kept. | Hardware player and cache layers, device interruption races and older-backup restore. |
| FR-18 Delete Film | Delete Film confirmation discloses Photos copies and older-backup restoration; deletion privacy-cancels capture, tombstones media and never refunds a used Trial. Evidence: hosted Journal tests, 037 UI and 046 deletion during a held save. | Device acceptance, backup restore of deleted Films (QA-15) and DEC-13 copy. |
| FR-19 Account deletion | Correctly not implemented for v1; the app has no Account, sign-in or server flows. | Deferred to v2. |
| FR-20 Subscription | `StoreKitSubscriptions` and `SubscriptionView` support configurable monthly and yearly products, StoreKit prices, verified updates, restore and a management link; existing Films are never gated. Local StoreKit fixture tests pass on iOS 26.2. | DEC-02 products, prices and refund policy, App Store Connect configuration, sandbox or device purchase and the ARC-09 offline check. |
| FR-21 Trial | `TrialCoordinator` owns one per-iPhone Keychain Trial: the first saved capture consumes it through verified pending media, a single-item receipt with readback and once-only projection; Delete Film never refunds; restored Films keep capturing. Evidence: production receipt integration, 035 to 039 harnesses and 046 Done and Delete during a held save. | TRI-11 hardware marker, ARC-11 two-device and fault-window checks, physical Keychain retention, delete and reinstall, and restore. Cross-store atomicity remains unaccepted. |

## Invariant Map

| Invariant | Current evidence | Remaining gap |
| --- | --- | --- |
| Camera identity cannot change after loading; Movie presentation orientation is fixed before recording. | The load screen locks the Camera package and Movie Orientation; each clip's orientation locks at its recording start; the renderer fits opposite clips with borders. | Hardware recording and Movie fidelity. |
| Captures cannot exceed authorized capacity; retries do not consume twice. | Domain, persistence and pipeline failure tests show no debit for failed saves; runtime rejects captures past full capacity (043); the receipt journal projects each capture once across faults and process exits (035 to 039, 036). | Device crash, power loss and storage pressure. |
| Completion does not imply Development. | The native Development runner and Film detail keep completed Films sealed until explicit Development (037, 043). | Device reveal ritual acceptance. |
| Unrevealed content has no thumbnails, direct-export path, or Camera Preview path. | Views show lock placeholders for sealed captures, the processor rejects sealed photo reads, exports cover only revealed captures and Camera previews never use captures. | Device cache and snapshot review; DEC-05 previews. |
| Capacity is never refunded for deliberately spent, discarded or deleted saved capture. | Hosted photo Discard and Delete tests keep spent capacity, including Discard beside another unfinished save (046); Movie Discard keeps consumed seconds. | Device acceptance. |
| Treatment is assigned once, survives retries, and is unchanged by Movie reassembly. | Native Development keeps assignments across thrown, cancelled and exited boundaries (036) and through Movie reassembly (042). | Hardware render fidelity and DEC-04. |
| Privacy removals win over development retries, cached views, and old assembled versions. | 036 export and privacy races, 042 stale Movie retirement, 044 player retirement, 045 uninspectable paths keeping tombstones pending and 046 late save events unable to develop a deleted Film. | Hardware player and cache layers and device interruptions. |
| Archive, whole-Film deletion and subscription cancellation remain separate operations. | Native Archive, Delete Film and Manage Apple Subscriptions are separate, with copy that deleting Films or the app does not cancel a subscription. | Device and StoreKit sandbox acceptance. |
| Trial eligibility is consumed only by first successfully saved capture and is never restored. | Production `TrialCoordinator` consumes only on the first verified saved capture and never refunds on Discard or Delete Film (hosted Journal, receipt harnesses, 046). | TRI-11 and ARC-11 hardware; cross-store atomicity remains unaccepted. |

## Tracker ID Map

Status words in this table are intentionally conservative:

- **partial:** some behavior is implemented and tested in a package, the native app or a non-shipping harness, but acceptance evidence is still missing.
- **prepared:** code/procedure exists, but the required real environment evidence is absent.
- **blocked:** the implementation exists but cannot be exercised until the named decision or asset is supplied.
- **failed:** an executed required check fails and remains unwaived.
- **open decision:** the ID cannot be accepted until the named product decision is supplied.
- **not started:** no production implementation evidence yet.

Rows were reconciled with the native app and checkpoint reports through `Evidence/NativeApp/capture-controller-quiescence-046.md`.
No row is accepted: every v1 ID still needs the named decision, device or hardware evidence before its tracker box can be checked.

| ID | Dependency or blocker | Implementation location | Behavioral verification and observed outcome |
| --- | --- | --- | --- |
| DEC-01 | Open product decision. | None. | Not started; final brand/copy not selected. |
| DEC-02 | Deferred until before M2 billing. | None. | Not started; prices/refund/revocation handling still open. |
| DEC-03 | Native stack still open; Swift packages are baseline defaults only. | `Packages/FilmDomain`, `Packages/NativeAdapters`, `Packages/CapturePipeline`, `Packages/RenderFixtures`, `Packages/EntitlementCore`, `Probes/TrialKeychainProbe`. | Partial use of reversible Swift package default; does not close DEC-03. |
| DEC-04 | Open render/output decision. | Recommendations doc, `Packages/RenderFixtures`, `Evidence/RenderFixtures`. | Recommendation and native API fixture evidence prepared; Camera render specs remain unresolved until captain approval. |
| DEC-05 | Open asset/licensing decision. | Recommendations doc. | Recommendation prepared; samples and soundtrack rights remain unresolved until captain approval. |
| DEC-09 | Captain decision supplied 2026-09-30. | `Packages/FilmDomain/Sources/FilmDomain/Film.swift`. | Partial: tests verify empty early Development is blocked and all Movie clips discarded leaves placeholders with no playback/export. |
| DEC-11 | Open product decision. | Recommendations doc; `RenderCore` recipe model. | Recommendation prepared; Darkroom ranges, Instant source timing and soundtrack reselection unresolved until captain approval. |
| DEC-12 | Open product decision and hardware budgets. | Recommendations doc. | Recommendation prepared; low-storage/performance/accessibility matrix unresolved until captain approval and hardware evidence. |
| DEC-13 | Open product/launch decision. | Recommendations doc. | Recommendation prepared; support/privacy/review requirements unresolved until captain approval. |
| DEC-14 | Open numeric learning targets. | Recommendations doc. | Recommendation prepared; no analytics SDK remains preserved. |
| ARC-01 | DEC-03 open; reversible SwiftUI, raw SQLite and local Swift package baseline. | `App/Immerse` (XcodeGen `project.yml`), `Packages/`, `Scripts/validate-local.sh`, `.github/workflows/native.yml`. | Partial: unsigned iOS 26 simulator and generic-device app builds, package/probe tests and hosted, UI, populated-harness and local StoreKit simulator targets run locally; latest gate bound in `Evidence/NativeApp/capture-controller-quiescence-046.md`. CI is prepared, not observed green; no signed device run. |
| ARC-02 | Settled domain subset. | `Packages/FilmDomain/Sources/FilmDomain`. | Partial: state dimensions and invariants behavior-tested by `swift test`. |
| ARC-03 | Physical fault/recovery acceptance missing. | `FilmPersistence`, `FilmRuntime/TrialCoordinator`, `Probes/ReceiptScenarioHarness`. | Partial: production media journal/SQLite integration plus checkpoint 035 native-simulator synthetic phase/re-entry checks. Exact scenarios, source hashes and gaps in the 035 report; no hardware durability inference. |
| ARC-05 | Physical testing deferred by captain; hardware gate still required. | `EntitlementCore/DeviceTrialStore`, `FilmRuntime/TrialCoordinator`, both Trial probes. | Partial: production single-item consumption/receipt/readback and legacy reconciliation; 035 full-receipt harness compiles for iOS. Native Security capability skips with actual -34018 unsigned; physical retention/restore and cross-store durability unproved. No reconnect request authorized. |
| ARC-06 | Physical interruption, capture/removal-crash and full viewer/cache acceptance missing. | FilmProcessor/repository; ExportPrivacyHarness and DevelopmentProcessExit. | Partial: injected export/privacy races and exact observed Development exits recover retained native media and remove stale Movie assemblies without reroll/refund. External copies remain unrecalled; active camera/player and power-loss boundaries unproved. |
| ARC-07 | Needs ongoing documentation. | This evidence map. | Partial: records baseline/prototype boundaries and validation strategy. |
| ARC-08 | Requires iPhone 11/iOS 26. | None. | Untested; no usable physical device available. |
| ARC-09 | Early check S8 before offline entitlements are relied on; needs StoreKit sandbox or device and DEC-02 products. | `EntitlementCore/StoreKitSubscriptions`, `SubscriptionController`, test-only `LocalSubscriptions.storekit`. | Partial: local StoreKit fixture tests on iOS 26.2 cover purchase, reopen, restore, pending, expiry and revocation (`Evidence/NativeApp/2026-10-01-native-candidate.md`, `storekit-expiry-diagnosis.md`). Offline entitlement read after one online sync and Apple-ID-only restore are not executed. |
| ARC-10 | Requires native Movie media on hardware. | FilmDomain Movie domain; `Packages/RenderFixtures`; `Evidence/RenderFixtures/synthetic-developed-movie.mov`. | Partial: decoded synthetic H.264 `.mov` fixture proves native API write/read metadata path; capture/render/export fidelity on iPhone hardware remains untested. |
| ARC-11 | Requires Trial hardware tests. | Marker procedure; `Probes/ReceiptScenarioHarness`; manual T01...T12. | Partial software only, including 035 real media/SQLite with explicitly injected receipt errors/process exits. No delete/reinstall/restore, native receipt success or power-loss hardware evidence. |
| ARC-12 | Requires two-device backup/restore. | None. | Untested; no authorized hardware restore performed. |
| UX-01 | DEC-03 open; device and accessibility acceptance open. | `JournalView`, `FilmDetailView`, `JournalModel`. | Partial: native Film Journal groups Films by state with revealed-only previews and no B/C layouts or review controls. Empty-Journal UI tests and populated-harness navigation pass on the simulator; the original QA-13 audit findings remain failed. |
| UX-02 | Device acceptance. | `JournalView` Start a Film bottom-bar action; `PhotoView` Darkroom entry. | Partial: Start a Film is the prominent Journal action (UI tests); Darkroom opens only from a revealed photo and is absent for Movies (037 legacy UI, `darkroom-player-observation-044.md`). |
| UX-03 | Device and accessibility acceptance. | `JournalFilmRow`, `FilmDetailView` placeholders, FilmDomain reveal states. | Partial: Journal groups On the roll, Ready to develop, Developing, Pack complete and Developed; sealed captures show lock placeholders and only revealed photos produce thumbnails (037 populated UI, hosted Journal tests). |
| UX-04 | Device acceptance; several paid Films need an approved paid test entitlement. | `FilmRepository`, `JournalModel.films`, `CaptureController` Film switching. | Partial: multiple Films reload from SQLite; the 046 hosted test switches the attached camera between two Films, finishing the previous Film's save first, without revealing either. |
| UX-05 | DEC-01 final copy. | `CameraCatalogView` suggested title; `FilmDetailView` Rename. | Partial: suggested "Camera - Roll #NN" titles with optional custom names at load, and rename before and after Development (hosted Journal test, 037 legacy UI). |
| UX-07 | Device acceptance. | FilmDomain `captureDateRange`; `FilmDetailView` header. | Partial: the range derives from first and last capture timestamps, including a backward-clock regression, and is shown in Film detail. |
| UX-08 | Device acceptance. | `FilmRepository.setArchived`; Journal Archive list. | Partial: Archive and restore change no capture, reveal or capacity state (hosted Journal test, 037 legacy UI). |
| CAM-01 | DEC-04/05 for full package details. | `CameraCatalog`. | Partial: immutable package IDs/capacities/reveal rules tested. |
| CAM-02 | DEC-04/05 treatment and samples; hardware controls. | `CameraCatalog.disposable1990s`, provisional `NativePhotoRenderer` preset, `CaptureController` focus lock and supported flash. | Partial: 27-exposure full-roll runtime (`full-capacity-runtime-043.md`); focus locks and flash appears only when the lens supports it. The render preset is provisional, not an approved treatment. Hardware untested. |
| CAM-03 | DEC-04/05 and DEC-11 Instant source timing. | `CameraCatalog.instant1970s`, per-exposure Development, `CaptureView` print sheet. | Partial: ten individual reveals including the final print (043 runtime, 037 UI); a print saved while another operation owns the Film stays sealed for Resume Development (046). Hardware untested. |
| CAM-05 | DEC-04/05; hardware focus and exposure. | `CameraCatalog.mediumFormat6x6`, square viewfinder, lens-gated focus and exposure controls. | Partial: 12-exposure runtime (043); unsupported controls are hidden with an explanation. Hardware untested. |
| CAM-06 | DEC-04/05; hardware recording. | `CameraCatalog.super8HomeMovie`, provisional `NativeMovieRenderer` preset, video-only capture. | Partial: 200-second budget runtime (043), silent capture and synthetic native rendering. Hardware untested. |
| CAM-07 | DEC-04/05; hardware recording. | `CameraCatalog.cinema16mm`, provisional `NativeMovieRenderer` preset, video-only capture. | Partial: 165-second budget runtime (043), silent capture and synthetic native rendering. Hardware untested. |
| CAM-10 | DEC-05 sample rights. | `CameraCatalogView` descriptions, `CameraSamplesView`, empty `MediaCatalog.json`. | Partial: plain-language capacity, control, reveal and audio descriptions for every Camera. No sample media is shown until rights are cleared; drafts exist only for review in `Evidence/AssetReview`. |
| CAM-11 | DEC-01 final terminology. | `CameraCatalog.displayName`. | Partial descriptive names; final copy not approved. |
| CAM-12 | DEC-04/05 approval and Camera-quality review. | `NativePhotoRenderer`, `NativeMovieRenderer`, `Evidence/AssetReview`, `Packages/RenderFixtures`. | Partial: provisional per-Camera native treatments render decodable output and draft review samples exist; authenticity and bounded imperfections are not approved. |
| SET-01 | Device acceptance. | `CameraCatalogView`. | Partial: Start a Film opens Choose a Camera listing all five Cameras (UI test). |
| SET-03 | DEC-05 sample rights. | `CameraSamplesView`, `MediaCatalog`. | Blocked on DEC-05: the preview surface exists without a live feed or capture access, but shows no samples until cleared media is configured. |
| SET-04 | Device acceptance. | `CameraCatalogView`, `JournalModel.load`. | Partial: browsing and cancelling create no Film and no Trial write; declining the actual simulator Camera request at Load Film loads nothing and writes no Trial record (UI and hosted tests, 046). |
| SET-05 | DEC-01 copy; device acceptance. | `CameraCatalogView` load screen. | Partial: the load screen shows Camera, capacity, reveal rule and controls before an explicit Load Film action. |
| SET-06 | Settled domain. | Film immutable `camera`. | Partial: Camera immutability tested. |
| SET-08 | Device acceptance; original QA-13 finding names the Movie Orientation control. | `CameraCatalogView` Movie Orientation picker; Film `movieOrientation`; capture plan. | Partial: Movie Orientation is chosen at load, immutable afterwards and passed to the locked capture plan. |
| CAP-01 | Hardware capture evidence. | `AVFoundationCaptureBackend` photo delegate and decoded staging; `CaptureController`; `TrialCoordinator` receiver. | Partial: native capture path compiles and runs to recovery on a camera-less simulator; staged synthetic photos commit through the production receiver (040, 046). No real captured media. |
| CAP-02 | Device review. | No Photos picker, file importer or document picker in the app; capture only through `AVFoundationCaptureBackend`. | Partial: source review finds no import path; Photos access is add-only. |
| CAP-03 | DEC-04 cues; device acceptance. | `CaptureView` viewfinder and pinned shutter bar. | Partial: square framing for 6x6 and Instant, 3:4 otherwise, and a raw preview without developed effects; the shutter stays on screen and status sits above the viewfinder on iPhone SE, 13 Pro and 17 Pro simulators (`visual-sweep-048.md`). No device viewfinder observed. |
| CAP-04 | Needs AVFoundation hardware. | NativeAdapters backend camera discovery/input switching. | Partial: actual native code compiles for device/simulator; no hardware capture evidence. |
| CAP-05 | Needs front camera hardware/output tests. | NativeAdapters preview helper and output connections. | Partial: front preview mirror and output-unmirror paths compile; asymmetric-target hardware test remains untested. |
| CAP-06 | Hardware capture and recording. | `CaptureOperationCoordinator`, save delegates, `CaptureController`, `CaptureView`. | Partial: capture and lens switching are blocked until the save is acknowledged, with retained-file retry; the controller finishes or recovers a Film's save before switching Films (046). Hardware behavior untested. |
| CAP-07 | Needs hardware capability matrix. | NativeAdapters AVFoundation discoverer. | Prepared: adapter can report rear/front availability; no hardware matrix observed. |
| CAP-08 | Offline device run and Trial hardware tests. | `TrialCoordinator`, `JournalModel.load`, `CaptureController`; no network code. | Partial: capture and Trial start use only local storage and Keychain; there is no Immerse server or network API. No offline device run. |
| CAP-09 | Physical prompt timing, restricted Camera, storage pressure, actual AVFoundation save failure and device relaunch. | FilmDomain failed-save no debit; `FilePresence`; `CapturedMediaFiles`; `TrialCoordinator`; `CaptureController`; hosted and UI tests. | Partial: backend cancel and recovery (040); uninspectable staging, tombstone and pending-save paths fail closed (045); controller quiescence, Discard keeping other unfinished saves and no late-event failure alerts (046); the actual app declines the real simulator Camera request without loading a Film (046), and reopening an existing Film's camera with the request declined shows guidance with Open iPhone Settings and leaves the Film unchanged (048). The simulator has no camera. |
| CAP-10 | Device acceptance. | FilmDomain sealed state; `FilmDetailView` lock placeholders; exports only for revealed captures. | Partial: no sealed review, thumbnail, individual delete or export path in the views or processor; reading a sealed photo is rejected (hosted Journal test). |
| MOV-01 | Needs hardware recording. | Native Movie delegate, decoded file duration, fractional FilmDomain debit. | Partial: real synthetic file duration retained without whole-second rounding and persisted; actual camera recording untested. |
| MOV-02 | Needs hardware budget boundary. | FilmDomain fractional budget; native maxRecordedDuration and file validation. | Partial: over-budget files rejected and domain remaining duration tested; last-frame/stop timing untested on hardware. |
| MOV-03 | Hardware fidelity. | `NativeMovieRenderer.assemble`, `DevelopmentWorker`. | Partial: one chronological assembled Movie from developed clips with no timeline controls, rebuilt after Discard (`movie-player-cache-042.md`). Hardware untested. |
| MOV-04 | Needs native recording. | FilmDomain `ClipOrientation`; NativeAdapters per-recording orientation; CapturePipeline movie commit. | Partial: clip orientation is independent of locked final presentation, persisted and tested; actual recording untested. |
| MOV-05 | DEC-04 specs; hardware. | `NativeMovieRenderer`, FilmDomain `MovieOrientation`. | Partial: final orientation locks at load and opposite clips fit with borders in synthetic native rendering (`Evidence/NativeRendering/2026-10-01-workflows.md`). Hardware untested. |
| MOV-06 | Needs hardware interruption evidence. | Native session/runtime/background observers and saved-file salvage validation; operation coordinator. | Partial: coordinator proves no automatic recording restart; native paths compile. Call/lock/background/process-kill salvage untested. |
| MOV-07 | Needs AVFoundation permission proof. | Native backend video-only input, no microphone request, audio-session auto-configuration disabled; file validator rejects audio. | Partial: native code compiles and synthetic silent-file checks pass; microphone-denied/no-prompt hardware test remains untested. |
| MOV-09 | DEC-05 rights and DEC-11 reselection policy. | `SoundtrackView`, `MediaCatalog`, `FilmProcessor.selectSoundtrack`. | Partial: silence or one catalog instrumental, retained audio and reassembly are tested with fixtures (`2026-10-01-media-workflows.md`). The production catalog is empty, so the control stays hidden. No import or voice-over path. |
| MOV-10 | Needs native clip files. | FilmDomain clip records; FilmPersistence assets; CapturePipeline synthetic clip save; RenderCore assembly plan; RenderFixtures sample media. | Partial metadata/storage plan plus decoded synthetic native media fixture; no captured clip files. |
| MOV-11 | DEC-04/native media tests. | `Packages/RenderFixtures`, `Evidence/RenderFixtures`. | Prepared/partial: synthetic H.264 `.mov` fixture metadata recorded; approved codec/resolution/cadence and hardware export fidelity remain open. |
| DEV-01 | Settled domain subset. | FilmDomain completion/development split. | Partial: capacity completion does not auto-develop. |
| DEV-02 | Physical/full-capacity acceptance remains open. | FilmDomain completeEarly; FilmDetailView/DevelopmentView; PopulatedJournalHarness. | Partial: 037 UI/state checks verify cancel keeps open/sealed, confirmation spends exactly 25 remaining exposures and separate Development cancellation keeps completed/not developed. |
| DEV-03 | Settled domain subset plus DEC-09. | FilmDomain `completeEarly`. | Partial: exact time waste tested. |
| DEV-04 | Native reveal UI/physical acceptance remains open. | `FilmRuntime/FilmProcessor`, `DevelopmentStage`, 036 observer tests. | Partial: real native Development pauses/throws/cancels at approved existing phases; no reveal before verified persisted media. See source-bound DevelopmentObserver report. |
| DEV-05 | Native ritual and device acceptance. | FilmDomain Instant reveal; `DevelopmentWorker` per-exposure reveal; `CaptureView` print sheet. | Partial: all ten prints including the final one reveal individually without resealing earlier prints (043 runtime, 037 UI); a print saved while another operation owns the Film waits for Resume Development (046). |
| DEV-06 | Approved output/quality and physical evidence remain open. | Native renderer, repository and FilmProcessor; 036 DevelopmentObserver tests. | Partial: exact treatment assignments and native decoded/hash-verified persisted masters/clips survive thrown/cancelled observed boundaries, without rerendering retained captures. |
| DEV-07 | Full-capacity/physical interruption and restore acceptance remains open. | FilmProcessor/repository recovery; DevelopmentProcessExit probe. | Partial: 33 exact-boundary native macOS child exits and four representative iOS app exits recover fixed assignments/retained media through explicit new-owner resume; abandoned Work cleaned. Not power loss or hardware restore. |
| DEV-08 | Physical storage/render interruption and full UI recovery missing. | FilmProcessor/FilmPersistence plus 036 boundary scenarios. | Partial: boundary throw/cancel preserves sources and durable state; verified cleanup follows explicit choice; removal cannot acknowledge while the tested Development job remains held. |
| DEV-10 | DEC-09 supplied; physical/accessibility acceptance remains open. | FilmDetailView and production repository; PopulatedJournalHarness. | Partial 037 native UI: empty early disabled, Delete cancel/confirm; last Movie removal preserves numbered empty placeholders without export. |
| DRK-01 | DEC-11/final-quality and full-control acceptance open. | DarkroomView, FilmProcessor, RenderCore and FilmPersistence. | Partial 037 UI/state comparison: saved exposure edit changes photo 1 print bytes, preserves photo 2 and treatment assignments, and survives relaunch. |
| DRK-02 | DEC-11 final ranges and all-control acceptance open. | `DarkroomView` and native print renderer. | Partial: saved exposure edit and reopen verified in 037; the Contrast grade control is reachable in the actual views (`darkroom-player-observation-044.md`). Ranges are provisional. |
| DRK-03 | DEC-11 ranges and toning applicability. | `DarkroomView` CMY controls; `NativePhotoRenderer`. | Partial: CMY filtration is reachable in the actual views (044); toning applies only to an explicit silver-gelatin process; no saturation control. |
| DRK-04 | DEC-11 crop behavior. | `DarkroomView` Crop; RenderCore `Crop`. | Partial: crop controls are reachable in the actual views (044); final crop behavior is not approved. |
| DRK-05 | DEC-11 ranges; gesture and assistive acceptance. | `DarkroomView` Dodge/Burn; RenderCore `LocalMask`. | Partial: non-gesture Dodge/Burn and Undo are reachable in the actual views (044, 045), and a drawn dodge stroke paints without scrolling the Darkroom, renders and persists across relaunch (`darkroom-gesture-tint-047.md`). Device touch, Pencil and assistive technologies are untested. |
| DRK-06 | Full control/physical acceptance open. | DarkroomView, native print renderer and recipe persistence. | Partial 037: Reset/save/reopen restores original recipe and byte-identical print/source/master after saved exposure edit, without changing photo 2 or treatments. |
| DRK-08 | Physical/full navigation acceptance open. | FilmDetailView/PhotoDetailView; PopulatedJournalHarness. | Partial 037 legacy UI regression: developed/empty Movie has no Darkroom; real photo path reaches it. |
| STO-01 | Device storage and backup acceptance. | `Packages/FilmPersistence` under the app's private root; `JournalModel`. | Partial: Film metadata and source/master assets reload from SQLite and files in new repository instances and after app relaunch (hosted Journal, 037 retained relaunch). |
| STO-02 | DEC-13 final copy. | `SettingsView` Storage and backup (`PrivacyCopy.backup`). | Partial: the copy states local storage, inclusion in iOS device backups, no app sync or backup, and loss without a device backup. |
| STO-03 | Device sandbox review. | FilmPersistence app-private media and staging; no pre-reveal Photos path. | Partial: sources and staging stay under the app container until reveal; only revealed media can be exported. |
| STO-04 | Actual PhotoKit write. | `FilmDetailView` Save Developed to Photos; `FilmExportWorker`. | Partial: explicit export for revealed photos and complete Movies; a denied add-only status shows guidance (045). No real Photos write. |
| STO-05 | Actual PhotoKit and UI acceptance missing. | `FilmExportWorker`, native app export flow, 036 probe. | Partial: developed export uses actual edited native print without choosing/removing originals; 036 preparation/recovery never auto-exports. No real Photos call in this probe. |
| STO-06 | Actual permission/write-failure paths untested. | `PhotoExportCoordinator`, `FilmExportWorker`, 036 probe. | Partial: denied/restricted/undetermined, injected failed/unknown/missing/cancelled replies preserve originals and usable masters. Known acknowledged batch retries skip writes; unknown completed copy may be duplicated by explicit retry, retained and disclosed as an evidence limit. |
| STO-07 | Hardware PhotoKit and physical durability missing. | `FilmExportWorker`, repository receipt/verified cleanup, 036 probe. | Partial: durable injected acknowledgment alone cannot clean a source with invalid or hash-mismatched master. Restoring the same synthetic master permits verified cleanup without another acknowledged write. Real Photos success/durability remains unaccepted. |
| STO-08 | Disclosure/declined branch native acceptance remains open. | `FilmProcessor.cleanupSources`, repository decoded/hash evidence guard. | Partial native verification exists, superseding historical checksum-only state. 036 specifically exercises acknowledged-export cleanup and corrupt-master rejection, not final disclosure approval or every declined-export UI path. |
| STO-09 | Full offline native viewing acceptance missing. | Native app viewers; `FilmProcessor`, repository, 036 probe. | Partial: actual masters/clips remain decodable and hash-identical after original cleanup/reopen; this is not a physical viewer/storage-loss acceptance run. |
| STO-10 | DEC-13 final copy. | `SettingsView` Saving to Photos copy; export path. | Partial: copy says a developed export is a flattened result, not a restorable Film or edit history; export never deletes or archives the Film (hosted and 036 tests). |
| STO-11 | Needs real backup/restore. | FilmPersistence file attributes. | Partial: temp directory excluded from backup and media directory not excluded; hardware backup/restore unavailable. |
| PRV-01 | Device viewing and cache acceptance. | FilmDomain `discardRevealedCapture`; `FilmProcessor.discard`; `JournalModel.remove`. | Partial: numbered placeholders and no refund; Discard of a revealed Instant print keeps another print's unfinished save and capacity accounting (046). |
| PRV-05 | Full native player/cache/cleanup-failure coverage missing. | Repository removal and `FilmProcessor`, 036 probe. | Partial: source/clip/old assembly/Work retirement and late export rejection verified against actual synthetic private files. Retained external test copies are deliberately not claimed removed. |
| PRV-06 | Settled domain subset. | FilmDomain consumed duration unchanged after Discard. | Partial tested. |
| PRV-07 | Hardware fidelity/audio/player acceptance missing. | Production `FilmProcessor`/Movie renderer/repository, 036 probe. | Partial: Super 8/16mm paused export races retire the old private assembly; actual native reassembly matches surviving clip duration, unchanged clip hash/treatment assignments/orientation and spent capacity. External stale copies remain; soundtrack races and hardware viewing untested. |
| PRV-08 | DEC-09 supplied; physical player/export acceptance open. | FilmDetailView/Movie rendering; PopulatedJournalHarness. | Partial 037 legacy UI: last-clip discard retains 01/02 numbered discarded placeholders without developed export. See 036 for private retirement/hash assertions. |
| PRV-10 | DEC-13 copy; device acceptance. | `PrivacyCopy.discard`, `deleteFilm` and `backup`. | Partial: Discard, Delete Film and Settings copy explain permanent app removal, remaining Photos exports and older backups restoring removed media; stale viewing and export rejection is covered in 036, 042 and 044. |
| DEL-01 | Final copy and full native/manual acceptance open. | FilmDetailView confirmation and Journal navigation. | Partial 037: empty Delete cancel preserves exact state; confirm removes Film/private files. Legacy rename/Archive/restore/Delete navigation passes. |
| DEL-02 | Device acceptance. | `FilmDetailView` Delete Film confirmation; `TrialCoordinator.deleteFilm`; repository tombstones. | Partial: confirmation discloses Photos copies and older-backup restoration; hosted and 037 tests remove media, edits and staging without reveal; 046 deletes a Film while its save is held without a late failure alert. |
| DEL-03 | FR-21/DEC-09 device Trial behavior remains separately open. | Empty Film actions and repository. | Partial 037 UI/state: empty early disabled and Delete confirm removes synthetic subscription Film; not Trial replacement/hardware proof. |
| DEL-04 | Device delete, reinstall and restore. | `TrialCoordinator.deleteFilm`; `KeychainDeviceTrialStore`. | Partial: deleting a consumed Trial Film keeps the Trial consumed (hosted Journal and 046 tests). Device reinstall is untested. |
| BIL-01 | DEC-02 prices and products; App Store Connect setup. | `StoreKitSubscriptions`; unset Info.plist product ID keys. | Partial: monthly and yearly same-group validation with StoreKit prices; production product IDs are absent by design. |
| BIL-02 | StoreKit sandbox or device. | `EntitlementCore`; `JournalModel.load`; `SubscriptionView`. | Partial: policy tests allow unlimited new Films with every Camera and no per-Film tier under an active subscription, and local StoreKit fixture tests verify the active state that `JournalModel.load` checks. No test loads a Film through a purchased subscription. |
| BIL-03 | Sandbox or device purchase authority. | `SubscriptionController`, `SubscriptionView`. | Partial: purchase and restore through StoreKit only, with no account; local fixture tests pass on iOS 26.2. |
| BIL-05 | StoreKit sandbox or device expiry. | `EntitlementCore`; `StoreKitSubscriptions`; existing Film operations. | Partial: local fixture expiry delivers the expired state, after which policy denies new Films and allows existing-Film continuation (`storekit-expiry-diagnosis.md`); hosted Journal tests develop, edit and remove existing Films with billing unconfigured. |
| BIL-06 | DEC-02 refund and revocation policy; sandbox. | `StoreKitSubscriptions` transaction updates. | Partial: local fixture restore, pending approval, expiry and refund revocation change only current access, while policy keeps existing-Film rights (`storekit-expiry-diagnosis.md`). Renewal and approved refund policy are not exercised. |
| BIL-07 | DEC-13 copy. | `SubscriptionView` Manage Apple Subscriptions link and copy. | Partial: management entry plus copy that deleting Films or the app does not cancel a subscription and existing Films stay usable after expiry. |
| TRI-01 | Hardware acceptance deferred, not waived. | `EntitlementCore`, `FilmRuntime/TrialCoordinator`, native app and receipt harness. | Partial production integration; 035 verifies no second load during unknown outcome or after consumed pending deletion. No physical per-iPhone Trial acceptance. |
| TRI-02 | TRI-11 first. | Probe Keychain attributes. | Prepared only; hardware persistence/restore absent. |
| TRI-03 | Native first-save/retention evidence missing. | `FilmRuntime/TrialCoordinator`, `EntitlementCore/DeviceTrialStore`, receipt harness. | Partial: invalid synthetic media never consumes/projects; full-receipt recovery preserves one capture/debit in 035. Native Security was unavailable, not replaced by a fake passing path. |
| TRI-04 | Needs physical Keychain/filesystem durability evidence. | Production coordinator/journal; `Probes/ReceiptScenarioHarness`. | Partial injected-store failure/phase/re-entry checks in 035. No atomic transaction across stores or power-loss proof; exact unknown status, receipt and media state retained. |
| TRI-09 | Native retention/delete/reinstall/restore evidence missing. | Production coordinator/repository/entitlement policy and receipt harness. | Partial: pending synthetic deletion/stale callback rejection retain consumption and do not recreate app media. Device retention/restored-Film coexistence remain unaccepted. |
| TRI-11 | Physical prerequisite retained; implementation-first captain amendment defers execution. | Pinned marker plan; 035 full-receipt harness; manual T01...T12. | Prepared builds/procedures only. Earlier iPhone 13 Pro/iOS 26.6.2 probe-only authority does not extend to the new harness; do not request reconnection or execute phone operations. Two-phone restore and actual full-receipt hardware acceptance remain absent. |
| QA-01 | Real devices. | FilmDomain catalog tests; FilmRuntime full-capacity tests; catalog UI test. | Partial software only: capacities, reveal and audio rules and immutable selection; no real-device control or capture validation. |
| QA-02 | Devices. | FilmDomain; FilmRuntime 043; PopulatedJournalHarness 037; hosted Journal tests. | Partial: full and early completion, exact waste, multiple Films, Instant final print and sealed privacy covered synthetically. |
| QA-03 | Full-device/full-capacity and power-loss scenarios required. | FilmRuntime observer tests; DevelopmentProcessExit probe and iOS harness. | Partial: initial failures retained, then 33 ordinary child exits and four native-simulator app exits pass with exact treatment/master/clip/capacity/reveal checks. Physical acceptance remains open. |
| QA-04 | DEC-11 quality and ranges; device and assistive acceptance open. | `DarkroomView`, `FilmProcessor` and the retained-view inspector. | Partial: 037 saved exposure edit and exact Reset across relaunch preserve print bytes, the other photo and treatments; 044 reaches every control; 047 draws, renders and persists a dodge stroke. Gesture feel on a device and assistive technologies are not accepted. |
| QA-09 | Requires actual PhotoKit/native failure/storage acceptance. | Production storage/export owner plus 036 probe. | Partial source-bound simulator scenarios now cover verified cleanup, acknowledgment retry, unknown/cancelled reply, removal races and re-entry. All permissions/writes here are injected, never real Photos or storage exhaustion. |
| QA-11 | Requires hardware Movie/media/player coverage. | Production render/reassembly owner plus 036 probe. | Partial actual native synthetic Super 8/16mm reassembly/retirement and last-clip empty placeholders verified. Physical fidelity, actual Photos copies, licensed soundtrack and active-player acceptance remain missing. |
| QA-12 | StoreKit sandbox, Trial hardware, reinstall and restore. | `EntitlementCore`, `TrialCoordinator`, local StoreKit tests, receipt harnesses. | Partial: policy, local StoreKit fixture and injected-receipt Trial tests pass; not accepted without StoreKit sandbox, Keychain delete/reinstall and two-device restore evidence. |
| QA-13 | Original accessibility failures; devices and DEC-12 budgets. | `ImmerseUITests` audits; populated harness; hosted tests. | Failed and partial: the original four-case matrix still fails with seven findings. Camera and Photos denial, uninspectable storage and relaunch recovery are partially covered on the simulator (045, 046, 048); dark-mode filled-action contrast and small-screen capture layout defects were fixed (047, 048), and the Movie Orientation choice now follows Dynamic Type (049). The remaining audit findings measure as scaling or above WCAG except the 16mm description, which falls under the scroll-edge band only after scrolling (`qa13-measurement-049.md`). Firstmate kept them as retained QA-13 failures, the band case as a documented exception; QA-13 stays failed. No device, low-storage or performance evidence. |
| QA-14 | DEC-01/05/13/14 and release authority. | `Evidence/NativeApp/launch-readiness.md`, `manual-validation.md`. | Partial: QA-14 evidence handoff and manual matrix are prepared; not release-ready. |
| QA-15 | Requires backup/restore on real iPhones. | None. | Untested; no authorized hardware restore. |
