# Personal v1 Acceptance Evidence

This companion expands the PRD's personal FR acceptance paragraphs and section 11 invariants into individually assessable records. It does not replace the [canonical tracker](2026-09-29-film-camera-experience-v1-task-tracker.md), modify original FR/section/ADR numbering, or add product decisions. The [requirement evidence map](2026-09-29-film-camera-experience-v1-evidence-map.md) covers every intake v1 tracker ID and implementation artifact. Group and Account acceptance in section 8 remains deferred.

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

Evidence snapshot: source `7bfc78c`, branch `fm/immerse-v1-implementation`, observed 2026-10-01 UTC, macOS 26.6.2 (`25G83`), Swift 6.3.2, Xcode 26.5 (`17F42`). Package tests below ran on macOS. iOS builds were unsigned compile checks, not executed device tests. The approved Keychain candidate is separately pinned to `6e5c1742d344e0505b74176f60ac11c19a83e686`; its signed build passed but the confirmed iPhone was unreachable. No full FR has native acceptance yet.

Historical snapshot rows below retain their original observations. Current
software addenda are linked from the evidence map.
The clause, invariant and early-check tables also carry a current-status column
reconciled at `4687295` (checkpoint 046), keyed by the Current Evidence Keys section. In particular,
`Evidence/TrialKeychainProbe/2026-10-01-production-receipt-integration.md` supersedes
the D3 implementation-gap status for FR-04 A06 and FR-21 A01/A03/A05/A06/A07 and
the Trial/capacity invariants: complete pending media, one receipt/readback,
once-only projection, legacy migration, native app recovery and serialized deletion
have software evidence. The original counterexample remains at `d233bb7`; device
retention, two-device restore and power-loss behavior remain unaccepted. The
captain's implementation-first instruction superseded the historical before-code
TRI-11 prohibition, not its eventual hardware acceptance requirement.

Checkpoint 035 adds a device-capable non-shipping receipt controller:
`Probes/ReceiptScenarioHarness/README.md` supplies exact commands and
`Evidence/ReceiptScenarioHarness/035/README.md` binds outcomes to source, artifact,
runtime and separately named synthetic histories. This is additional partial
evidence for FR-04/05/18/21 and capacity, privacy and Trial invariants, not closure
of their physical clauses. Native Security returned -34018 and skipped; ordinary
file receipt/process-exit results are not hardware retention or power-loss proof.
The adjacent remaining-engineering inventory names unsupported phase/race/native
coverage controls. All original accessibility failures and product/hardware gates
stay open; no acceptance row or original ADR is replaced.

Checkpoint 036 adds partial FR-08/16/18 and no-reroll/no-refund/privacy-invariant
evidence through `Probes/ExportPrivacyHarness`, with execution details in
`Evidence/ExportPrivacyHarness/036/README.md`. Production native media, repository
and export/removal owners are real; permission, external writer receipts/errors
and output directories are injected. Known acknowledged writes are skipped on
retry; an unknown completed external copy may be duplicated by explicit retry,
not erased or misreported as exactly-once. Sources survive failed/uncertain replies
and unusable masters, while removed private Movies are retired/reassembled.
No PhotoKit, physical recovery, soundtrack/player, original-audit or full-clause
acceptance follows. Subsequent Development observers are not part of this checkpoint.

The subsequent 036 observer candidate adds partial FR-06/16/18 and immutable
treatment/privacy evidence in `Evidence/DevelopmentObserver/036/README.md`.
Real production phases are exposed by an optional, default-absent callback only;
native synthetic tests inspect durable state before/after throw, cancellation,
release, re-entry and removal. Exact execution/source identities and limits are
recorded there. This does not promote repository reopen to process-death or
physical restoration evidence, and does not alter any clause or original failure.

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

**Version 2.0 note (2026-10-06).**
PRD version 2.0 changed the wording of the FR-01 capacity and stock-picker clauses, of the FR-05 render-specification clause (frame rates are now set) and of the section 11 Camera invariant, and added two clauses, FR-01 A11 and FR-07 A05, which makes 74 clause records (the 72 earlier records plus these two).
No code changed with the PRD, so the outcomes recorded for the older clauses describe the code at the recorded candidate; where they mention 165 seconds or no stock picker they are history, and the changed rows say so.

Row suffixes A01, A02, etc. are evidence labels, not new PRD or tracker IDs. A row marked partial identifies exactly what its test establishes; untested means the stated acceptance remains unproved. A dependency does not excuse a failed or untested gate.

Current physical-test preparation: [manual validation handoff](../Evidence/NativeApp/manual-validation.md)
maps all 72 clauses and nine invariants to concrete future native scenarios and
evidence records, including the full receipt protocol rather than a marker-only
probe. It pins `241dafd`, HC_iPhone13/iPhone 13 Pro/iOS 26.6.2, separate app/action
authority and missing iPhone 11/two-phone coverage. All physical outcomes remain
untested under the captain's exact manual-test deferral; preparation accepts none.

Current QA-13 / H-UX addendum: `Evidence/NativeApp/accessibility-viewport-diagnosis.md`
retains the failed edge-suppression/viewport counterfactuals, complete exported
recordings and timestamped audit/geometry evidence. The observed callback viewport
differs from the pre-audit viewport after the size sweep. This is not proof of a
false positive or acceptance; production all-category accessibility remains open.
The later `Evidence/NativeApp/accessibility-physical-frame-diagnosis.md` establishes
real frame separation and all-row reachability in a padded instrumented probe,
but the corresponding actual-app attempt fails light 0/2 and dark 1/2. Its patch is
retained as failed evidence only. Capture latency and production navigation/state
differences remain unisolated; no QA-13 / H-UX acceptance or exception is implied.
`Evidence/NativeApp/accessibility-observer-diagnosis.md` subsequently records an
enabled-pass/disabled-fail window-capture comparison in the same padded probe.
Twelve-row visibility and physical separation pass, but title/command contrast
returns without the synchronous captures. Audit pose/load remain confounds; no
production correction or later navigation/Trial comparison was made.
The subsequent current-app paired traversal is retained at
`Evidence/NativeApp/accessibility-traversal-diagnosis.md`: matched title frames
and a Silent capture contrast finding, but incomplete traversal (A five inset
assertion failures; B times out before rows). This does not accept QA-13/H-UX or
establish a persistent visible defect/false positive. Original tests unchanged.
`Evidence/NativeApp/accessibility-traversal-progress-diagnosis.md` adds the
mechanics-only continuation: matching settled y400 poses, ten passing A rows,
zero B audit issues and seven passing B rows. The unchanged 600-second limit
prevents the last three B rows/completion. No paired conclusion, production
correction or QA-13/H-UX acceptance; historical required failures remain failed.
`Evidence/NativeApp/accessibility-traversal-early-exit-diagnosis.md` subsequently
completes both ten-row arms with exactly matching settled y400 poses and zero
B audit findings in 426.038 seconds. Diagnostic early exit changes query timing,
not production. This bounded-path pass does not clear original sequential or
assistive gates, explain historical audit failures, or accept QA-13/H-UX.
`Evidence/NativeApp/accessibility-original-matrix-diagnosis.md` then records one
unchanged default/largest light/dark matrix on `a79d481`: four executed failures,
seven findings, no skips/timeouts, all downstream navigation reached. Full native
recordings and source-bound trees/issues establish different original invocation
history/poses, not an analyzer cause or product correction. Remaining native
fault/race harness code work is explicit. QA-13/H-UX remain failed/unaccepted;
no original tests, production sources or required criteria were weakened.

Local traceability audit on 2026-10-01: the tracker-to-map comparison found all 121 currently unchecked v1 IDs plus the intake's now-decided DEC-09 (122 intake records); this companion has 72 uniquely labeled personal FR acceptance records and nine invariant rows. This count checks traceability only, not correctness or native acceptance. The 108 deferred tasks remain excluded.

## Evidence and Gate Key

| Key | Exact local command or required gate | Observed outcome and implementation/evidence |
| --- | --- | --- |
| D | `swift test --package-path Packages/FilmDomain` | Pass, 12 tests. `Film.swift`, `CameraPackage.swift`; `FilmDomainTests`, `MovieDurationTests`. Pure state only. |
| P | `swift test --package-path Packages/FilmPersistence` | Pass, 10 tests. `FilmRepository.swift`; `FilmPersistenceTests`. Synthetic source/master bytes. No decoded-master cleanup or crash-safe privacy proof. |
| R | `swift test --package-path Packages/RenderCore` | Pass, 5 tests after `swift package --package-path Packages/RenderCore clean`. `DevelopmentRun`, `DarkroomRecipe`, `MovieAssemblyPlan`. State/recipe/order only; no production pixels. |
| N | `swift test --package-path Packages/NativeAdapters` | Pass, 16 tests. `CaptureOperationTests`, `CapturedMediaFileTests`, permission/export coordinator tests. Real synthetic media decode, no camera hardware. |
| C | `swift test --package-path Packages/CapturePipeline` | Pass, 6 tests. `CapturePipelineReceiver`, `CapturePersistencePipeline`; fixture-to-SQLite commits and same-receiver duplicate suppression. |
| E | `swift test --package-path Packages/EntitlementCore` | Pass, 6 tests. Pure `EntitlementPolicyTests`; no Keychain or StoreKit. |
| I | Device and simulator build commands in `Evidence/NativeCapture/2026-10-01-backend.md` | Both pass with signing disabled; actual iOS AVCaptureSession/delegate backend compiled. Native UI integration and runtime effects untested. |
| K | `Probes/TrialKeychainProbe/PERSONAL_DEVICE_TEST_PLAN.md` and `Evidence/TrialKeychainProbe/2026-10-01-device-attempt.md` | Pinned-source comparison and signed build pass. Approved single-phone marker/relaunch/delete/reinstall gate untested: confirmed phone unavailable. Additional restore/erase/update actions are not authorized. |
| H-Capture | On the real app, exercise each Camera rear/front with asymmetric targets; deny camera/mic; interrupt by call/lock/background; fill storage; terminate/relaunch; measure saved duration and source hashes | Untested. Needs native app integration and exact hardware action authority; current phone approval is only K. |
| H-Render | On the real app, compare all approved Camera treatments, resumed output, Darkroom Reset pixels, Movie order/borders/orientation/audio and exported media against originals/masters | Untested. Needs DEC-04/05/11, renderer/app, authorized hardware and ARC-10. |
| H-Photos | Explicit independent developed/original choices; deny add-only permission; fail writes; retry; inspect actual Photos output and retained/deleted private assets | Untested. Needs app flow answers, actual PhotoKit execution and decoded-master cleanup. |
| H-Billing | StoreKit purchase/restore/renewal/expiry, offline after one online sync, approved refund/revocation handling; verify existing-Film rights | Untested. Needs DEC-02 before M2, products/configuration and authorized sandbox actions. |
| H-Restore | Two authorized iPhones: backup large sealed/developed/edited Films, restore onto destination, compare states/media/hashes and independent Trial; restore older backup after Discard and Delete Film | Untested. Needs second device, exact backup/restore authority, native app and ARC-12/QA-15. |
| H-UX | Real Film Journal/setup/capture/reveal/Darkroom/archive/settings flows, all error/empty states, accessibility and supported viewport/device matrix | Untested. Needs DEC-03, flow answers, DEC-12 and native UI. |

The native capture report records individual assertions, observation time, configuration, limits and the prior incremental-link failure; K records exact signed artifact hashes. These are repository-owned handoff documents for no-mistakes, not a machine-enforced acceptance import.

## Current Evidence Keys (046)

The historical key table above records observations at `7bfc78c`.
The current-status columns below use these keys, reconciled at `4687295` (`Evidence/NativeApp/capture-controller-quiescence-046.md`).

| Key | Command or evidence | Current outcome and limit |
| --- | --- | --- |
| D | `swift test --package-path Packages/FilmDomain` | Pass, 13 tests. Pure state. |
| P | `swift test --package-path Packages/FilmPersistence` | Pass, 25 tests. SQLite and private files, decoded and hash-verified cleanup, durable tombstones and deletion jobs, fail-closed uninspectable paths. Synthetic media on macOS. |
| R | `swift test --package-path Packages/RenderCore` | Pass, 11 tests. Recipes, assignments and native photo and Movie rendering of synthetic media with provisional presets. |
| N | `swift test --package-path Packages/NativeAdapters` | Pass, 24 tests. Capture coordination, staged media validation and recovery, add-only Photos coordinator. No camera hardware. |
| C | `swift test --package-path Packages/CapturePipeline` | Pass, 6 tests. Earlier pipeline receiver; production saves go through `TrialCoordinator`. |
| E | `swift test --package-path Packages/EntitlementCore` | Pass, 12 tests. Entitlement policy and the Keychain receipt adapter with injected calls. |
| F | `swift test --package-path Packages/FilmRuntime` | Pass, 43 tests. Production Development, Darkroom, export, Trial receipt owner, full-capacity runtime and soundtrack. |
| M | `swift test --package-path Packages/MediaCatalog` | Pass, 4 tests. Catalog rights metadata validation. |
| I | Unsigned simulator and generic-device app builds in `Scripts/validate-local.sh` | Pass. Compile only. |
| J | Hosted `ImmerseTests` Journal and CaptureController tests on iOS 26.5 and 26.2 | Pass, 12 tests on each runtime. Actual app model, controller, capture backend, Trial owner, repository and processor with synthetic media and injected Keychain calls; the simulator has no camera. |
| S | Hosted `StoreKitSubscriptionTests` on iOS 26.2 | Pass, 4 tests with the test-only local StoreKit fixture. No sandbox or real purchase. |
| U | `ImmerseUITests` on iOS 26.5 | The denied-Camera Load Film test and the text-size measurement of every audited screen at all twelve sizes (`Evidence/NativeApp/scroll-indicator-drag-053.md`) pass. The two original audit tests pass with deterministic scroll positions and the one exact, measured exception in `Evidence/NativeApp/qa13-audit-exceptions-052.md`, and tests prove any other finding still fails. Simulator audits only. |
| W | `Probes/PopulatedJournalHarness` UI tests | Pass, 10 tests; retained relaunch histories in `Evidence/PopulatedJournal/037/`. Actual views with synthetic Films; no capture or Trial. |
| X | `Probes/ExportPrivacyHarness` hosted tests | `Evidence/ExportPrivacyHarness/036/` and `Evidence/NativeApp/capture-backend-quiescence-040.md`. Injected Photos writer and authorizer with real rendering and storage. |
| O | Development observer and process-exit evidence | `Evidence/DevelopmentObserver/036/` and `Evidence/DevelopmentProcessExit/036/`. Ordinary process exits, not power loss. |
| T | Trial receipt study and harnesses | `swift test --package-path Probes/TrialCommitStudy` (17 tests), `Evidence/ReceiptScenarioHarness/035/`, `Evidence/ReceiptFaultMatrix/039/` and `Evidence/TrialKeychainProbe/2026-10-01-production-receipt-integration.md`. Injected receipt stores only. |

Numbered checkpoints such as 043 or 045 refer to the matching report under `Evidence/NativeApp/`.

Review reconciliation after checkpoint 050: production never executed `Packages/CapturePipeline` (key C) or the pure `EntitlementPolicy` rules in key E, so both were removed.
Key C's capture-commit evidence now comes from the production `TrialCoordinator` committer in F (`CaptureRecoveryIntegrationTests`, `TrialIntegrationTests`), and E keeps only the Keychain receipt adapter tests.
`TrialCoordinator.load` is the single new-Film entitlement decision (F); S now drives `JournalModel.load` and the production capture commit. The current-status column no longer cites E for Trial or existing-Film rules; F, J, S and T carry them.
Under the provisional default for PRD open question 7, pending the captain, an expired subscriber who never used the Trial gets the Trial Film.
Movie capacity is now whole 30 fps frames (D, N, F), and Movie capture uses a native 4:3 format whose size is provisional pending DEC-04.
The next gate run records the resulting test counts; this note does not.
H gates keep their meaning above; all remain untested on hardware, with steps in `Evidence/NativeApp/manual-validation.md`.

## FR Acceptance Clauses

| Clause | Acceptance condition / meaningful scenario | Historical outcome at `7bfc78c` | Current status at `4687295` (046) |
| --- | --- | --- | --- |
| FR-01 A01 | All five catalog entries have distinct framing | Untested: H-Capture/H-Render; Camera UI/framing and DEC-04 missing. | Partial: square framing for 6x6 and Instant and 3:4 for the others in `CaptureView`; Disposable, Super 8 and 16mm differ by treatment and controls, not framing. PRD 2.0 sets the Disposable to a borderless 3:2 picture (CAP-11), while the app still frames and develops it as 4:3, so that part is untested and not yet in the app. Device viewfinder untested. |
| FR-01 A02 | Controls differ authentically and are supported by the active lens | Partial I discovers rear/front and checks flash support. H-Capture authentic controls/unsupported-control UI untested; CAM-01 to CAM-07. | Partial: Disposable locks focus and offers flash only when the lens supports it; 6x6 shows focus and exposure only when supported, with an explanation otherwise; Movies are silent with no flash. Lens discovery runs only on a device (H-Capture). |
| FR-01 A03 | Exact capacities: 27, 10, 12 exposures; 200, 167 seconds (PRD 2.0; version 1.5 said 165, and the code and the retained evidence below still use 165 until CAM-13) | Partial D catalog/full/early/fractional tests pass. H-Capture full-budget measurement and real capture still required. | Partial: D catalog plus F full-capacity runtime for all five Cameras (`full-capacity-runtime-043.md`). Hardware capture timing untested (H-Capture, ARC-08). |
| FR-01 A04 | Audio behavior differs as specified; both v1 Movies are silent | Partial N/I video-only backend and silent-file validation. H-Capture no microphone prompt or recorded audio untested. | Partial: video-only capture with no microphone usage key or audio session, and silent-file validation (N, I); a soundtrack is only a post-Development choice. Microphone-denied hardware check untested. |
| FR-01 A05 | Developed treatment is format-distinct | Untested: DEC-04, H-Render, CAM-12; fixtures are not production treatments. | Partial: provisional per-Camera native presets produce different decoded output (`Evidence/AssetReview`); not approved (DEC-04) or validated (H-Render, CAM-12). |
| FR-01 A06 | Reveal follows each Camera's rule | Partial D roll/Movie sealing and Instant final-frame state tests. Actual per-print Development and native reveal gates untested. | Partial: roll and Movie Films stay sealed until explicit Development; Instant reveals each print individually including the tenth (F 043, W 037). |
| FR-01 A07 | No separate stock picker, except the Film Stock choice at Load Film on the 6×6 Medium Format and the 16mm Cinema (PRD 2.0, ADR 0014) | Untested: H-UX and app artifact inspection; native product UI absent. | Partial: setup offers Camera, title and Movie Orientation only, with no stock or capacity chooser (U, source review). PRD 2.0 makes the Film Stock choice a requirement: it is untested and not yet in the app (SET-09, CAM-16, DEV-11). |
| FR-01 A08 | Trial can choose any of the five Cameras | Untested: native setup plus K/ARC-11 prerequisite; catalog data alone does not prove entitlement UI. | Partial: Trial start accepts any Camera and runtime and hosted tests start Trial Films with each of the five (F, J). Trial loading through the UI is untested because the unsigned simulator Keychain returns -34018; TRI-11 deferred. |
| FR-01 A09 | Curated samples make no authenticated-emulation claim before quality validation | Untested: DEC-05 production rights/assets and DEC-04 quality review; current samples explicitly synthetic. | Partial: the production catalog is empty, so no sample is shown; review drafts in `Evidence/AssetReview` are labelled synthetic and unapproved. Blocked on DEC-05 rights and DEC-04 review. |
| FR-01 A10 | Render parameters and format-specific ranges remain open until decided | Open decision: DEC-04/11 recommendation document only; no approved values inferred from fixtures. | Open decision DEC-04/11: current presets and ranges are reversible engineering defaults. |
| FR-01 A11 | Each Camera's developed look is judged against its Format Reference as it performed when new, and no aging is added (PRD 2.0, ADRs 0013 and 0015) | Untested: no developed output has been compared with a Format Reference; DEC-04 values and QA-16 review boards missing. | Untested: the provisional presets are not Format Reference looks, and the Instant preset is washed out (CAM-17, QA-16). |
| FR-02 A01 | Library/contact sheets/search/navigation/archive never expose sealed content | Untested: H-UX plus storage access gates; D sealed states alone are insufficient. | Partial: Journal, Film detail and Archive show only revealed thumbnails and lock placeholders for sealed captures (W 037, J); there is no search surface. Device cache and snapshot review untested (H-UX). |
| FR-02 A02 | Rename leaves Camera, chronology, capacity and reveal unchanged | Partial D `testLoadedCameraDoesNotChangeWhenTitleOrArchiveChanges`; persisted native rename/navigation untested. | Partial: rename and Archive leave Camera, chronology, capacity and reveal unchanged in D, J and W legacy UI, across relaunch. |
| FR-03 A01 | Canceling preview or setup creates no Film and consumes no entitlement | Untested: H-UX, SET-04; setup coordinator/native UI absent. | Partial: browsing and cancelling setup create no Film and no Trial write (U); declining the actual Camera request at Load Film loads nothing (U, J; 046). |
| FR-03 A02 | Load is neither capture nor Development | Partial D initial Film has zero captures/notStarted Development. Explicit native Load confirmation and cancellation gate untested. | Partial: load creates an open Film with no captures and no Development (D, J); capture and Development are separate explicit actions (W 037). |
| FR-03 A03 | Load cannot bypass permissions or entitlement | Partial N configurable authorization coordinator; app-level Load/entitlement integration untested, flow timing/DEC-03 pending. | Partial: `JournalModel.load` checks Camera permission, then an active subscription or an unused device Trial, before any Film or Trial write; denied Camera and consumed Trial are refused (J, U, F). StoreKit sandbox and device Keychain untested. |
| FR-04 A01 | No review or individual delete for sealed personal captures | Partial D sealed Discard rejection. H-UX and repository/export access checks missing. | Partial: no review, thumbnail or individual delete exists for sealed captures; the processor rejects sealed photo reads and Discard requires reveal (D, J). |
| FR-04 A02 | No sealed-image thumbnails | Untested: native thumbnail/cache/navigation surfaces absent. | Partial: views show lock placeholders and build thumbnails only from revealed masters (W 037). App snapshot and cache review on a device untested. |
| FR-04 A03 | No automatic Photos writes | Partial N export is explicit-call-only and capture backend contains no Photos writer. H-Photos/H-UX real workflows untested. | Partial: Photos writes happen only from explicit export actions on revealed media; capture and Development never call the writer (N, X, J). Real PhotoKit untested. |
| FR-04 A04 | Lens change does not reset capacity | Partial I switch changes only video input, C holds Film debit separately. H-Capture real switch/capacity persistence untested. | Partial: a lens switch changes only the video input, is blocked during capture, and capacity stays with the Film (N, I). Hardware switch untested. |
| FR-04 A05 | Failure before durable save consumes no exposure | Partial D/P/C save-failure, unreadable payload and before/after-move injection checks pass. H-Capture storage/termination boundaries untested. | Partial: failed or unfinished saves never debit (D, P, F); retained saves stay pending and are retried, including after Done, across Film switches and beside a Discard (J; 046); uninspectable staging fails closed (045). Hardware storage and termination untested. |
| FR-04 A06 | Failure before durable save consumes no Trial | Partial E failure policy only. K/ARC-11 and cross-store first-save proof missing; see conflict record below. | Partial: a failed or unresolved first save leaves the Trial unconsumed until the receipt write and readback succeed (F, T). Physical Keychain and cross-store ordering remain unaccepted; see the conflict record. |
| FR-05 A01 | Pause/idle time has zero budget effect | Partial D/C debit only explicit saved durations; N stops recording without making another clip. H-Capture real elapsed-vs-recorded timing untested. | Partial: only saved clip durations debit, in whole 30 fps frames (D, F 043). Real elapsed versus recorded timing untested. |
| FR-05 A02 | Interruption does not reset budget | Partial N/C interruption events do not debit/reset, I observer paths compile. Actual call/lock/background gate untested. | Partial: interruption ends the active clip without resetting the budget and never resumes recording (N). Calls, lock and background on hardware untested. |
| FR-05 A03 | Interruption never loses previously saved clips | Partial P relaunch-style reload checks. H-Capture process-kill and storage-pressure preservation untested. | Partial: saved clips survive relaunch and ordinary process exits (P, O, T). Hardware process kill and storage pressure untested. |
| FR-05 A04 | Orientation is consistent in playback/export | Partial D/N/C keep clip and final orientations separate; I native connection rotation compiled. H-Render border fitting/playback/export unbuilt. | Partial: clip and final orientations are stored separately and the renderer fits opposite clips with borders (R, F). Hardware playback and export untested. |
| FR-05 A05 | Both Movie Cameras work with microphone denied | Partial I no audio input or microphone request. H-Capture denied-mic/no-prompt hardware scenario untested. | Partial: video-only input with no microphone usage key or request (I, N). Microphone-denied hardware check untested. |
| FR-05 A06 | Codecs/resolutions/audio guarantees remain unspecified until approved (PRD 2.0 sets the frame rates, Super 8 18 fps and 16mm 24 fps; version 1.5 left them unspecified too) | Open DEC-04; source session presets and synthetic fixtures are not final render specifications. | Open DEC-04: session presets and renderer settings are provisional. `NativeMovieRenderer` already encodes Super 8 at 18 fps and 16mm at 24 fps; no test checks its output frame rate. |
| FR-06 A01 | Repeated Development retries never reroll | Partial R stable assignment/resume tests pass. Durable renderer assignment, pixel hashes and termination/resume untested. | Partial: Development keeps stored treatment assignments across retries, thrown and cancelled boundaries and ordinary process exits, with unchanged master and clip hashes (R, F, O). Power loss untested. |
| FR-06 A02 | A five-unused-exposure warning wastes exactly five when confirmed | Partial D full/early remaining-capacity rules. H-UX actual warning/cancel/confirm with 22 of 27 captures untested. | Partial: confirming early completion spends exactly the remaining exposures and cancel changes nothing (D; W 037 spends the 25 left after two captures); a capture landing during confirmation requires a new confirmation (P). The PRD's 22-of-27 example is not run in the UI. |
| FR-06 A03 | Completion and Development are separate | Partial D full roll remains sealed until explicit state transition. Native renderer/reveal must prove no early reveal. | Partial: completed Films stay sealed until explicit Development, and the native runner reveals only after verified persisted output (D, F, O, W). |
| FR-06 A04 | Empty Film cannot begin early Development | Partial D empty early-completion/Development rejection. H-UX disabled action untested; DEC-09 decided. | Partial: early Development is disabled for empty Films (D, J, W 037). DEC-09 decided. |
| FR-06 A05 | Empty Film offers Delete Film, never a fabricated developed result | Partial P deletes empty/sealed Film without render. H-UX empty-film action/confirmation untested. | Partial: empty Films offer Delete Film with confirmation and never a developed result (J, W 037). |
| FR-07 A01 | Reset reproduces the exact original developed appearance | Partial R recipe Reset equality only. H-Render decoded pixels/export equality and retained master verification untested. | Partial: Reset reproduces byte-identical print, source and master after a saved edit, across relaunch (J, W 037). Decoded export equality and hardware untested. |
| FR-07 A02 | No saturation control | Partial R recipe has no saturation field; H-UX actual controls and exports untested. | Partial: recipes and `DarkroomView` have no saturation control (R, W 044). |
| FR-07 A03 | No Movie Darkroom entry | Untested: H-UX eligible-photo navigation and Movie exclusion absent. | Partial: Darkroom opens only from revealed photos and is absent for Movies (W 037 legacy UI). |
| FR-07 A04 | Ranges and medium applicability require render validation | Open DEC-04/11, H-Render; recommendation values are not approval. | Open DEC-04/11: current ranges are provisional. |
| FR-07 A05 | No crop control appears for an Instant print (PRD 2.0) | Untested: not a PRD 1.5 clause. | Untested: `DarkroomView` shows Crop for every Photo Camera and `NativePhotoRenderer.validate` accepts an Instant crop (DRK-09). |
| FR-08 A01 | Denied Photos permission is not reported as export success | Partial N denied-permission coordinator assertion; H-Photos real denial UI/write prevention untested. | Partial: a denied add-only status is never success and shows Photos guidance in the actual views (W 045); injected denial never dispatches the writer (N, X). Real PhotoKit untested. |
| FR-08 A02 | Failed Photos write is not reported as success | Partial N injected write failure; H-Photos storage/write errors and retry untested. | Partial: injected failed, unknown and cancelled writes are never success and keep originals and masters (X 036). Real write failure untested. |
| FR-08 A03 | Source cleanup never destroys the only usable developed result | Unmet implementation gap: P currently verifies only hashes; malformed hash-matching master and missing decodable Developed Clip must prevent cleanup. H-Photos/H-Render needed. | Partial: cleanup requires a decodable, hash-verified master or clip, plus an acknowledged export when originals were chosen; corrupt or missing masters stop cleanup (P, F, X 036). This closes the historical hash-only gap in software; hardware untested. |
| FR-08 A04 | Revealed personal media remains viewable offline | Untested: stored data exists but real native viewer/renderer absent; H-UX/H-Render offline gate. | Partial: revealed masters and clips stay decodable and viewable after source cleanup and relaunch with no network (F, X, W). Device offline review untested. |
| FR-08 A05 | Save Developed and Save Originals are independent optional choices | Untested: flow bundle/DEC-11 and H-Photos. No automatic-choice assumption permitted. | Partial: developed export and originals export are separate explicit actions, and the originals choice is not preselected (J, W 037). Instant choice timing remains DEC-11. |
| FR-08 A06 | Films return on a replacement iPhone restored from backup | Partial P nonexcluded media attribute. H-Restore actual Film DB/media inclusion untested. | Partial: Films and media live in backup-included app storage, with temporary and Work files excluded (P). H-Restore untested. |
| FR-08 A07 | Sealed state returns and remains sealed | Untested: H-Restore plus native access gates; domain serialization alone is insufficient. | Untested: H-Restore. Sealed state persists in SQLite and is enforced by views and processor, but no restore has been observed. |
| FR-08 A08 | Reversible edits return | Untested: edit persistence/renderer and H-Restore absent. | Untested: H-Restore. Edit recipes persist in SQLite and survive relaunch (W 037). |
| FR-08 A09 | Privacy copy discloses older backups can restore discarded media | Untested: DEC-13 final copy/native surfaces and H-Restore observation; DEC-17 rule settled. | Partial: Discard confirmation and Settings copy say an older iOS backup can bring discarded media back (`PrivacyCopy`). Final copy DEC-13 and H-Restore pending. |
| FR-08 A10 | Privacy copy also discloses older backups can restore a deleted whole Film | Untested: DEC-13 final copy/native surfaces and H-Restore; do not collapse into only Discard disclosure. | Partial: Delete Film confirmation and Settings copy say an older backup can bring a whole deleted Film back. Final copy DEC-13 and H-Restore pending. |
| FR-16 A01 | Accepted removal cannot coexist with viewing removed app-controlled media | Partial P synchronous file deletion only. Crash-safe tombstones, stale writer/cache rejection and actual viewer revocation missing. | Partial: removal hides app media before acknowledging, tombstones survive failures and launch recovery finishes them, and uninspectable residual copies keep the tombstone pending (P, X, W 044; 045). Hardware player and cache layers untested. |
| FR-16 A02 | Accepted removal cannot coexist with export of removed media | Untested: export authorization/race handling, H-Photos and pending-export cancellation absent. | Partial: an export paused against Discard or Delete cannot export removed media, and a late export is rejected (X 036). |
| FR-16 A03 | Retry after removal never resurrects content | Unmet implementation gap: repository master/clip writers need durable tombstone checks; process-kill/retry scenarios required. | Partial: durable tombstones and deletion jobs stop retries and stale writers from recreating removed media, including after ordinary process exits (P, X, O, F). Power loss untested. |
| FR-16 A04 | Old assembled Movie versions are retired | Partial P stale assembly removed after Discard. Real viewer/export leases, cache cleanup and H-Render stale-version tests untested. | Partial: old assembled Movies are retired before reassembly, and the actual app's old player and item are released after Discard (F 042, W 044). Hardware caches untested. |
| FR-16 A05 | Cleanup failure cannot be mistaken for successful privacy completion | Unmet implementation gap: durable deletion jobs and interrupted filesystem/SQLite recovery require failure tests. | Partial: cleanup failure keeps the tombstone pending and the removal fails instead of acknowledging (P; 045). |
| FR-16 A06 | Placeholder has no thumbnail or retained private content | Partial D metadata-only placeholder model. P/native staging/cache cleanup and H-UX inspection incomplete. | Partial: placeholders are numbered metadata only, with no thumbnail (D, W). |
| FR-16 A07 | Removal refunds no duration or exposure | Partial D no-refund Movie tests. Native persistence/viewer/error paths and photo cases need full acceptance. | Partial: Discard and Delete refund no exposures or seconds, for photos and Movies (D, J, W; 046). |
| FR-16 A08 | Last Movie clip removal leaves numbered placeholders with no playback/export | Partial D/P all-clips-discarded and empty assembly rejection tests. H-UX/H-Render native controls/cache access untested; DEC-09 settled. | Partial: after the last clip is discarded the Film keeps numbered placeholders with no player or export (D, P, W 037 and 042). |
| FR-18 A01 | Delete Film never reveals sealed content | Partial P sealed-Film deletion without Development. Native warning and access race tests missing. | Partial: Delete Film removes sealed Films without Development or reveal (P, J, W 037). |
| FR-18 A02 | Delete Film does not reset consumed entitlement | Partial E no-refund/zero-save distinction tests. K/ARC-11 and full delete workflow untested. | Partial: deleting a consumed Trial Film keeps the Trial consumed (J; 046). Device reinstall untested. |
| FR-18 A03 | Deleted Film cannot be viewed or exported from current app storage | Partial P row/assets removed synchronously. Durable deletion jobs, native staging, edits and cached/export handles incomplete. | Partial: deletion tombstones Film rows, media, edits, staging and Work, and a held save cannot recreate the Film (P, F, J; 046). |
| FR-18 A04 | Confirmation and privacy copy say external exports remain | Untested: native confirmation/copy and H-Photos; no app Photos-deletion path should be introduced. | Partial: the confirmation says Photos exports remain, and there is no Photos deletion path. Final copy DEC-13. |
| FR-18 A05 | Confirmation and privacy copy say a pre-deletion backup can restore the whole Film | Untested: native copy and H-Restore; DEC-17 settled. | Partial: the confirmation says restoring an older iOS backup can bring the whole Film back. H-Restore untested; final copy DEC-13. |
| FR-20 A01 | Expired subscriber can finish a partly shot roll | Partial E existing subscription-origin Film rights retained. H-Billing/real capture after expiry untested; DEC-02 before billing. | Partial: after local fixture expiry an existing subscription Film still saves a capture through the production commit, and existing-Film operations never check a current subscription (F, S). StoreKit sandbox and real capture after expiry untested. |
| FR-20 A02 | Renewal is not required for existing viewing/Development/edit/export | Partial E rights policy. H-Billing/H-UX native routes untested. | Partial: existing Films develop, edit, export and delete with billing unconfigured (J), and after local fixture expiry or refund an existing paid Film still saves through the production capture commit (S). |
| FR-20 A03 | Restore/check use StoreKit and Apple ID, never an app Account | Untested: H-Billing, ARC-09 and configured products; no app Account code introduced. | Partial: purchase and restore use StoreKit only, with no app Account code (S, source review). ARC-09 and sandbox untested. |
| FR-20 A04 | Refund/revocation handling remains open | Open DEC-02; no worker-chosen behavior may be accepted. | Open DEC-02: Apple revocation removes only current access in the local fixture (S); no refund product policy is chosen. |
| FR-21 A01 | App delete/reinstall does not reopen consumed Trial eligibility | Untested K: approved probe signed, phone unreachable; production Trial remains prohibited until TRI-11. | Untested on hardware: the Trial record is one ThisDeviceOnly Keychain item outside app storage, but delete and reinstall have not been run (TRI-11 deferred by the captain). |
| FR-21 A02 | Restore to a different phone does not carry the Trial record | Untested: K two-device extension/H-Restore; second device and restore authority absent. | Untested: second-device restore (H-Restore, ARC-12). |
| FR-21 A03 | Captured and empty restored Trial Films retain rights and coexist without consuming/blocking destination entitlement | Partial E both restored cases modeled. Actual Keychain/device-origin identification and H-Restore untested. | Partial: restored empty and saved foreign Trial Films keep their grants and coexist with the destination Trial in runtime tests (F, T). Device restore untested. |
| FR-21 A04 | Destination entitlement can start once, then cannot start another after first saved capture | Partial E first-save/no-refund policy. K/ARC-11 native persistence and restore coexistence untested. | Partial: the destination Trial starts once and a second load is refused after its first saved capture (F, J). Device untested. |
| FR-21 A05 | Deleting a current-device zero-save Trial leaves replacement eligibility | Partial E zero-save replacement/no cancellation. K/ARC-11 actual delete/relaunch/reinstall scenarios untested. | Partial: deleting a zero-save current-device Trial Film permits a replacement (F). Device delete and reinstall untested. |
| FR-21 A06 | Offline first save cannot permit another Film even when terminated around save | Unresolved architectural conflict: D3 loses its SQLite recovery marker on uninstall; see counterexample below. Neither K nor policy tests closes this. | Partial software: complete verified pending media, then one Keychain receipt with readback, then SQL projection; ordinary process exits around each step never permit a second Trial (F, T and the production receipt report). Physical Keychain retention, power loss and uninstall windows remain unaccepted; see the conflict record. |
| FR-21 A07 | Failure before save does not consume Trial | Partial E policy only. Keychain-first/pending approaches must also prove this, including failure then uninstall; not accepted. | Partial software: failures before the receipt write leave the Trial unconsumed, and unresolved writes stay pending rather than refunded (F, T). Failure followed by uninstall is untested on hardware. |
| FR-21 A08 | No Account/sign-in/server is required | Partial local packages have none. Complete native artifact/network/entitlement flow inspection untested. | Partial: the app has no Account, sign-in or network service; Trial and capture are local (source review, J). |
| FR-21 A09 | No server, Account or cross-device identifier substitutes for Keychain without a new decision | Preserved implementation boundary: no such substitute added. Production Keychain design and full artifact review still needed. | Preserved: no server, Account or cross-device identifier substitutes for the Keychain Trial. |

FR-19 is a v2 stub, with no v1 Account acceptance. Its preserved version 1.1 requirements remain in PRD 8.13. Other deferred FRs and mixed Group clauses remain in section 8, outside this table.

## Section 11 Invariants

| Invariant | Meaningful verification | Historical outcome at `7bfc78c` | Current status at `4687295` (046) |
| --- | --- | --- | --- |
| Camera immutable; Film Stock fixed at loading where offered; final Movie orientation locked | Load, rename/archive, switch lens, capture opposite-orientation clips; compare original package/version/final orientation (PRD 2.0 adds Film Stock to this invariant; compare the chosen Film Stock too) | Partial D/N/C. Native Load/UI/hardware and versioned package migration still untested. | Partial: load locks Camera and Movie Orientation; rename, Archive and lens switch leave them unchanged; the renderer fits opposite clips (D, J, F, W). Hardware recording untested. Film Stock does not exist in the app yet (CAM-16, SET-09), so that clause is untested. |
| Capacity bounded; retry never double-debits | Fail each native/file/SQLite boundary; retry same capture, including after relaunch; measure full budgets | Partial D/P/N/C. Same-receiver dedupe passes; durable capture receipts/process-kill and last-frame hardware behavior missing. | Partial: failed saves never debit, extra captures past full capacity are rejected, and the receipt journal projects each capture once across faults and ordinary exits (D, P, F 043, T, O). Device crash, power loss and last-frame timing untested. |
| Completion is not Development | Reach capacity/confirm early end; reopen before Develop; inspect every preview/export surface | Partial D. H-UX/native Development gate absent. | Partial: completed Films stay sealed until explicit Development in runtime and actual views (F, W). Device reveal ritual untested. |
| Sealed content has no thumbnail/export/preview path | Try every UI/deep link/archive/cache/export path before and during Development | Untested: native access gates absent. D sealed state is not sufficient. | Partial: lock placeholders, rejected sealed reads, exports only for revealed media and no preview from captures (D, J, W). Device cache and snapshot review untested. |
| No capacity refund for spent/discarded/deleted capture | Capture, reveal, discard/retry/delete; compare capacity and entitlement histories | Partial D/E. P removal failures and native workflow acceptance remain open. | Partial: photo and Movie Discard and Delete keep spent capacity and Trial consumption (D, J, W; 046). |
| Treatment assigned once and unchanged by reassembly | Interrupt every assignment/render/commit; compare persisted seeds and surviving clip/pixel hashes | Partial R state/order only. Actual deterministic renderer/persistence/H-Render absent. | Partial: stored assignments survive retries, boundary throws, ordinary exits and Movie reassembly (R, F, O; 042). Hardware render untested. |
| Privacy removal defeats retries/caches/old Movies | Race removal against render/export, fail filesystem cleanup, kill/relaunch, revisit old handles | Unmet implementation gap: durable tombstones, staged-file ownership and stale-writer rejection remain required. | Partial: durable tombstones and deletion jobs, stale-writer rejection, export races, stale Movie retirement, player release and ignored late capture events (P, X, F, W 044, J 046). Hardware caches and interruptions untested. |
| Archive/Delete Film/cancel billing are separate | Exercise each separately and confirm the other states/rights unchanged | Partial D/E. Native UI and H-Billing integration absent. | Partial: Archive, Delete Film and Manage Apple Subscriptions are separate, with copy that deleting does not cancel a subscription (J, W, S). StoreKit sandbox untested. |
| Trial consumed only on first successful save, never restored | Offline failure/success and termination windows; zero-save deletion, captured deletion, reinstall and second-device restore | Partial E policy; K/ARC-11/H-Restore missing and first-save protocol conflict unresolved. | Partial: the production receipt owner consumes only after verified pending media and receipt readback and never refunds (F, T, J). TRI-11, ARC-11 and two-device restore untested. |

## First-Save Conflict Record

Architecture baseline 7.D3 and 8.1 already record an open first-save window; the following is a reasoning counterexample, not a hardware test or a revised rule. Relevant clauses: FR-21 A01/A06/A07, TRI-04, ARC-11 and QA-12.

| Candidate ordering | Fault sequence | Required rule that remains unproved |
| --- | --- | --- |
| D3: SQLite write-ahead marker, durable capture/Film commit, then consumed Keychain write | Kill after capture commit but before Keychain write; uninstall before next launch removes the SQLite marker and capture; reinstall reads unused Keychain | Consumed eligibility must not reopen. Launch reconciliation cannot recover data removed by uninstall. |
| Keychain consumed first, then durable capture/Film commit | Keychain succeeds; capture storage fails or process dies before capture commit; uninstall removes any local recovery evidence | Failed save must consume nothing. Blindly preserving consumed state burns the Trial without its successful save. |
| Keychain pending first, then capture commit, then Keychain consumed | Trace A fails before capture commit then uninstalls; trace B succeeds at capture commit but dies before consumed write then uninstalls. Both reinstall with identical pending Keychain state and no local data | Treating pending as unused permits another Trial in B; treating it as consumed burns a failed Trial in A. Extra pending metadata cannot distinguish these two traces if all capture/commit evidence is removed. |

This demonstrates the conflict within the proposed separate filesystem/SQLite/Keychain stores and ordering; it is not proof that every possible native design is impossible. The current probe tests marker persistence only and does not establish a cross-store atomic transaction. No changed success definition, pending-as-consumed policy, server, Account or identifier is implemented to hide the conflict. Exact Keychain/native fault observations and an approved resolution remain necessary. The existing architecture options stay open; any relaxation of either acceptance condition belongs to the captain, not this worker.

Current production ordering (`Evidence/TrialKeychainProbe/2026-10-01-production-receipt-integration.md`): complete verified pending media is synchronized in backup-included staging, then one Keychain item records consumption and the capture receipt with exact readback, then SQL projects the capture once.
The D3 counterexample no longer applies in software: losing app storage after the receipt keeps the Trial consumed, and losing it before the receipt permits a replacement because no save committed.
An uninstall between the receipt and projection also removes that pending capture's media with the rest of app storage.
Physical Keychain retention, power-loss ordering and uninstall windows remain unaccepted until TRI-11 and ARC-11 run on hardware, and both captain Trial requirements are unchanged.

## Early Checks and Launch Gates

| Named gate | Required artifact/observation | Historical state at `7bfc78c` | Current status at `4687295` (046) |
| --- | --- | --- | --- |
| S1 / ARC-08 | iPhone 11/iOS 26 foreground full 27-photo and 200-second Movie timings, interrupted/resumed run, memory and output comparison | Untested: native renderer, approved DEC-04/12 budgets and authorized iPhone 11 absent. No macOS or simulator substitute. | Untested: no authorized iPhone 11 and no approved DEC-04/12 budgets. The native renderer exists; no macOS or simulator substitute. |
| S4 / TRI-11 | Pinned probe marker before/after relaunch and probe-only reinstall; absent on second-phone restore; OS update/erase effects recorded | K signed-build preparation only; current phone unreachable. Second device and separate update/erase/restore scope absent. | Prepared: pinned probe and signed build; physical execution deferred by the captain to manual v1 testing. Second device and update, erase and restore scope absent. |
| S8 / ARC-09 | Verified StoreKit entitlement offline after online sync; Apple-ID-only restore transcript | Untested: DEC-02/product configuration and approved sandbox execution missing. | Untested: local StoreKit fixture only (S); DEC-02 products and sandbox authority missing. |
| S11 / ARC-10 | Native full Movie assembly/discard/rebuild/export with HEVC/HDR/orientation/borders/soundtrack and unchanged survivor hashes | Untested: H-Render, DEC-04/05, native renderer and authorized hardware required. | Untested on hardware: native assembly, Discard rebuild and synthetic export run in software (F, X, W); HEVC/HDR capture, approved specs and a licensed soundtrack are absent. |
| S12 / ARC-11 | First-save fault-window traces, zero-save replacement and restored Trial coexistence on two phones | Untested: TRI-11 prerequisite, first-save resolution, native Trial implementation and authorized two-device fault harness required. | Untested on hardware: the production first-save protocol and fault windows run in software with injected receipts and ordinary exits (T, F); two-phone execution deferred. |
| S13 / ARC-12; QA-15 | Large-Film backup size, two-device restored media/state/edit hashes, old-backup resurrection of discarded media and deleted Film | Untested: native app and authorized second restore device required. | Untested: an authorized second restore device and backup authority are required. |
| PRD 13.1-13.6 | Domain/state; backup; media/privacy; native device; entitlement; UX/accessibility evidence for every listed scenario | Partial D/P/R/N/C/E only. H gates remain untested; no whole-category pass inferred from a package result. | Partial software evidence across the current keys; H gates untested; the original QA-13 audits pass on the simulator as recorded in 052. No category passes from a software result. |
| QA-14 / PRD 13 release gate | Production asset license ledger; final disclosures/support/privacy review; dependency/privacy inventory; all native acceptance; resolved required DECs; retained release task and concrete action authority | Not ready. DEC-04/05/11/12/13/14, native app/hardware and billing/Trial evidence absent. No publication authorized. | Not ready: `Evidence/NativeApp/launch-readiness.md` prepares the handoff; DEC-01/02/04/05/11/12/13/14 decisions, hardware, billing and Trial evidence and release authority are absent. No publication authorized. |

All gate failures and missing capabilities remain visible until new candidate-bound evidence is recorded. A local tombstone/deletion journal must not become a removal log that defeats the accepted older-backup restoration behavior (DEC-17). A future release requires Firstmate's ordinary release task and separate exact authority; this document grants none.
